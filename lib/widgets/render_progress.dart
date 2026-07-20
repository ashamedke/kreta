import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../utils/constants.dart';
import '../utils/virtual_clock.dart';
import '../models/render_job.dart';
import '../models/project.dart';
import '../services/render_service.dart';
import '../services/ffmpeg_service.dart';
import '../services/timing_resolver.dart';
import 'render_engine.dart';

// ---------------------------------------------------------------------------
// Background frame-writer isolate.
//
// Rationale: `boundary.toImage()` has to run on the main isolate (it reads
// the live render tree), so we can't move frame *capture* off the UI thread
// without a full custom-Canvas rewrite of RenderEngineWidget. What we CAN
// move off the UI thread is everything downstream of the captured image:
// packaging the RGBA bytes and writing them to FFmpeg's socket. That's the
// part that used to make `stdin.add(bytes)` block the render loop while a
// potentially-slow disk/socket write completed.
//
// The main isolate now:
//   1. captures frame N (`toImage` + `toByteData`) — still on the UI thread
//   2. hands the bytes to the writer isolate via TransferableTypedData
//      (a zero-copy handoff — no bytes are duplicated across isolates)
//   3. immediately proceeds to build/capture frame N+1, WITHOUT waiting for
//      frame N's socket write to finish — as long as the writer isolate
//      isn't more than `_maxInFlightFrames` frames behind.
//
// This pipelines capture and I/O instead of strictly serializing them.
// ---------------------------------------------------------------------------

/// Cap on how many captured-but-not-yet-written frames we allow to be
/// in flight to the writer isolate at once. Without this bound, if the
/// socket write is slower than capture, frames would queue up in the
/// isolate's mailbox unbounded and blow up memory (each 1080p RGBA frame
/// is ~8MB, 4K is ~32MB). This is the "buffer pooling" concern from the
/// design doc, addressed via backpressure rather than a literal reusable
/// buffer pool (Dart's image/byte APIs don't expose a way to render into
/// a caller-supplied buffer).
const int _maxInFlightFrames = 3;

class _WriterInit {
  final SendPort mainSendPort;
  final int ffmpegPort;
  _WriterInit(this.mainSendPort, this.ffmpegPort);
}

class _FrameMessage {
  final int seq;
  final TransferableTypedData data;
  _FrameMessage(this.seq, this.data);
}

class _CloseMessage {
  const _CloseMessage();
}

/// Entry point for the background writer isolate. Connects to FFmpeg's
/// listening tcp socket itself (a live Socket can't be handed across an
/// isolate boundary, so the connection has to be made from inside the
/// isolate that will use it) and then drains frame messages onto it.
void _frameWriterIsolateEntry(_WriterInit init) async {
  final workerReceivePort = ReceivePort();
  init.mainSendPort.send(workerReceivePort.sendPort);

  Socket? socket;
  try {
    // FFmpeg needs a brief moment after process start to bind+listen on
    // the tcp input before it will accept a connection; retry rather than
    // failing on the first refused connection.
    const maxAttempts = 25;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          init.ffmpegPort,
          timeout: const Duration(milliseconds: 500),
        );
        break;
      } catch (_) {
        if (attempt == maxAttempts - 1) rethrow;
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  } catch (e) {
    init.mainSendPort.send({'type': 'error', 'message': 'Writer isolate could not connect to FFmpeg: $e'});
    workerReceivePort.close();
    return;
  }

  init.mainSendPort.send({'type': 'ready'});

  await for (final message in workerReceivePort) {
    if (message is _FrameMessage) {
      try {
        final bytes = message.data.materialize().asUint8List();
        socket.add(bytes);
        init.mainSendPort.send({'type': 'ack', 'seq': message.seq});
      } catch (e) {
        init.mainSendPort.send({'type': 'error', 'message': 'Frame write failed: $e'});
        break;
      }
    } else if (message is _CloseMessage) {
      try {
        await socket.flush();
      } catch (_) {
        // Socket may already be broken (ffmpeg exited early) — nothing
        // more we can do here, the exit code check on the main isolate
        // will surface the real failure.
      }
      await socket.close();
      init.mainSendPort.send({'type': 'closed'});
      break;
    }
  }
  workerReceivePort.close();
}

/// Thin controller wrapping the spawned writer isolate + its message
/// protocol, so the widget state doesn't have to juggle ports directly.
class _FrameWriter {
  final Isolate isolate;
  final ReceivePort mainReceivePort;
  late SendPort _workerSendPort;
  final Completer<void> _readyCompleter = Completer<void>();
  final _AckTracker ackTracker = _AckTracker();
  String? errorMessage;
  bool _closed = false;

  _FrameWriter._(this.isolate, this.mainReceivePort);

  static Future<_FrameWriter> spawn(int ffmpegPort) async {
    final mainReceivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _frameWriterIsolateEntry,
      _WriterInit(mainReceivePort.sendPort, ffmpegPort),
    );
    final writer = _FrameWriter._(isolate, mainReceivePort);
    writer._listen();
    return writer;
  }

  void _listen() {
    mainReceivePort.listen((message) {
      if (message is SendPort) {
        _workerSendPort = message;
      } else if (message is Map) {
        switch (message['type']) {
          case 'ready':
            if (!_readyCompleter.isCompleted) _readyCompleter.complete();
            break;
          case 'ack':
            ackTracker.onAck(message['seq'] as int);
            break;
          case 'error':
            errorMessage = message['message'] as String;
            ackTracker.onError();
            break;
          case 'closed':
            _closed = true;
            ackTracker.onClosed();
            break;
        }
      }
    });
  }

  Future<void> get ready => _readyCompleter.future;

  /// Sends a captured frame's raw RGBA bytes to the writer isolate.
  /// Blocks (briefly) only if we're more than [_maxInFlightFrames] ahead
  /// of the writer's acknowledged progress — this is the backpressure
  /// valve that keeps memory bounded.
  Future<void> sendFrame(int seq, TransferableTypedData data) async {
    await ackTracker.waitForCapacity(seq, _maxInFlightFrames);
    if (errorMessage != null) {
      throw Exception(errorMessage);
    }
    _workerSendPort.send(_FrameMessage(seq, data));
  }

  Future<void> closeAndWait() async {
    if (errorMessage != null) return; // already broken, nothing to flush
    _workerSendPort.send(const _CloseMessage());
    await ackTracker.waitForClosed();
  }

  void dispose() {
    mainReceivePort.close();
    isolate.kill(priority: Isolate.immediate);
  }
}

/// Tracks which frame sequence numbers have been acknowledged as written,
/// and lets the producer wait until it's allowed to send more.
class _AckTracker {
  int _lastAcked = -1;
  bool _closed = false;
  bool _errored = false;
  final List<Completer<void>> _waiters = [];

  void onAck(int seq) {
    if (seq > _lastAcked) _lastAcked = seq;
    _drain();
  }

  void onError() {
    _errored = true;
    _drain();
  }

  void onClosed() {
    _closed = true;
    _drain();
  }

  /// Wakes every current waiter so it re-checks its own condition. Each
  /// waiter that's still blocked re-adds itself with a fresh Completer on
  /// its next loop iteration (see waitForCapacity), so it's safe to just
  /// complete-and-clear here rather than track who's "really" satisfied.
  void _drain() {
    for (final c in _waiters) {
      if (!c.isCompleted) c.complete();
    }
    _waiters.clear();
  }

  Future<void> waitForCapacity(int seq, int maxInFlight) async {
    if (_errored) return;
    while (seq - _lastAcked > maxInFlight && !_errored) {
      final c = Completer<void>();
      _waiters.add(c);
      await c.future;
    }
  }

  Future<void> waitForClosed() async {
    if (_closed || _errored) return;
    final c = Completer<void>();
    _waiters.add(c);
    await c.future;
  }
}

class RenderProgressDialog extends StatefulWidget {
  final Project project;
  final RenderJob renderJob;
  final VoidCallback onCancel;
  final bool isThumbnail;

  const RenderProgressDialog({
    super.key,
    required this.project,
    required this.renderJob,
    required this.onCancel,
    this.isThumbnail = false,
  });

  @override
  State<RenderProgressDialog> createState() => _RenderProgressDialogState();
}

class _RenderProgressDialogState extends State<RenderProgressDialog> {
  final GlobalKey _renderKey = GlobalKey();
  late final VirtualClock _clock;
  List<ResolvedTiming> _resolvedTimings = [];
  bool _isCancelled = false;
  
  @override
  void initState() {
    super.initState();
    _clock = VirtualClock(fps: widget.renderJob.preset.fps);
    _resolvedTimings = TimingResolver().resolveAllTimings(widget.project.game.plies, widget.project.timeline.timingRules);
    
    // Start render loop after UI builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRenderLoop();
    });
  }
  
  /// Resolves the on-disk location of `flutter_assets` relative to the
  /// compiled executable. This layout differs by desktop platform:
  ///  - Windows:  <exe_dir>\data\flutter_assets
  ///  - Linux:    <exe_dir>/data/flutter_assets
  ///  - macOS:    <App>.app/Contents/Frameworks/App.framework/Resources/flutter_assets
  String _resolveFlutterAssetsDir() {
    final String exeDir = File(Platform.resolvedExecutable).parent.path;
    if (Platform.isMacOS) {
      return p.normalize(p.join(
        exeDir,
        '..',
        'Frameworks',
        'App.framework',
        'Resources',
        'flutter_assets',
      ));
    }
    // Windows and Linux share the same relative layout.
    return p.join(exeDir, 'data', 'flutter_assets');
  }

  Future<void> _startRenderLoop() async {
    final renderService = context.read<RenderService>();
    final ffmpegService = context.read<FfmpegService>();
    StringBuffer ffmpegStderr = StringBuffer();
    
    FfmpegEncodeSession? ffmpegSession;
    _FrameWriter? frameWriter;

    try {
      // 1. Calculate total frames
      int totalDurationMs = 0;
      for (var t in _resolvedTimings) {
        totalDurationMs += t.holdDurationMs + t.transitionDurationMs;
      }
      totalDurationMs += 2000; // Add 2s padding at the end
      
      final totalFrames = widget.isThumbnail ? 1 : (totalDurationMs / 1000 * _clock.fps).ceil();
      
      // Update job with total frames
      renderService.startRender(widget.project, widget.renderJob.preset, widget.renderJob.outputPath ?? '', totalFrames: totalFrames);
      
      // Calculate Audio Cues
      List<AudioCue> audioCues = [];
      if (!widget.isThumbnail) {
        double accumulatedTimeMs = 0;

        // Flutter places the flutter_assets directory in a different spot per
        // platform relative to the compiled executable. Resolve it correctly
        // instead of assuming Windows, and join paths with the platform's
        // own separator so this works on Windows, macOS, and Linux desktop.
        final String assetsDir = _resolveFlutterAssetsDir();
        
        for (int i = 0; i < widget.project.game.plies.length; i++) {
          final ply = widget.project.game.plies[i];
          final timing = _resolvedTimings[i];
          final plyTotalTime = timing.holdDurationMs + timing.transitionDurationMs;
          
          // Play sound at the moment the piece lands (end of transition)
          final int hitTimeMs = (accumulatedTimeMs + timing.transitionDurationMs).toInt();
          final bool isCapture = ply.capturedPiece != null;
          final bool isPromotion = ply.isPromotion;
          final bool isCheck = ply.isCheck || ply.isCheckmate;
          
          String soundFile = 'put.mp3';
          if (isCheck) soundFile = 'check.mp3';
          else if (isPromotion) soundFile = 'promotion.mp3';
          else if (isCapture) soundFile = 'capture.mp3';
          
          audioCues.add(AudioCue(p.join(assetsDir, 'assets', 'audio', soundFile), hitTimeMs));
          
          final textLen = (ply.annotation ?? '').length;
          if (textLen > 0) {
             audioCues.add(AudioCue(p.join(assetsDir, 'assets', 'audio', 'typing.wav'), hitTimeMs));
          }
          
          accumulatedTimeMs += plyTotalTime;
        }
      }
      
      // 2. Start FFmpeg process + its socket-backed frame writer (skip for thumbnail)
      if (!widget.isThumbnail) {
        ffmpegSession = await ffmpegService.startEncodeStream(
          width: widget.renderJob.preset.width,
          height: widget.renderJob.preset.height,
          fps: _clock.fps,
          outputPath: widget.renderJob.outputPath ?? '',
          videoBitrate: widget.renderJob.preset.videoBitrate,
          backgroundVideoPath: widget.project.backgroundVideoPath,
          audioCues: audioCues,
        );
        
        // Listen to stderr for debug/progress (optional)
        ffmpegSession.process.stderr.transform(utf8.decoder).listen((data) {
          ffmpegStderr.write(data);
        });

        frameWriter = await _FrameWriter.spawn(ffmpegSession.listenPort);
        await frameWriter.ready.timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw Exception(
            'Timed out waiting for the frame-writer isolate to connect to FFmpeg.',
          ),
        );
      }
      
      // 3. Render loop — capture stays on the UI thread; writing pipelines
      //    off it via frameWriter, bounded by _maxInFlightFrames.
      for (int f = 0; f < totalFrames; f++) {
        if (_isCancelled) {
          renderService.cancelRender();
          ffmpegSession?.process.kill();
          frameWriter?.dispose();
          return;
        }
        
        // Update virtual clock
        if (widget.isThumbnail) {
           _clock.seekToFrame((totalDurationMs / 1000 * _clock.fps).ceil() ~/ 2); // Middle of the game
        } else {
           _clock.seekToFrame(f);
        }
        final completer = Completer<void>();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          completer.complete();
        });
        setState(() {}); // Rebuild RenderEngineWidget with new clock time
        await completer.future;
        
        // Capture image
        final boundary = _renderKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 1.0);
          
          if (widget.isThumbnail) {
             final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
             final bytes = byteData!.buffer.asUint8List();
             final frameFile = File(widget.renderJob.outputPath ?? '');
             await frameFile.writeAsBytes(bytes);
          } else {
             final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
             final bytes = byteData!.buffer.asUint8List();
             // Zero-copy handoff to the writer isolate. This is the part
             // that used to be `ffmpegProcess.stdin.add(bytes)` running
             // inline on the UI thread; it now happens off-isolate, and
             // we don't block waiting for the write to complete — only
             // for the backpressure window in sendFrame().
             final transferable = TransferableTypedData.fromList([bytes]);
             try {
               await frameWriter!.sendFrame(f, transferable);
             } catch (e) {
               String errorMsg = ffmpegStderr.toString();
               if (errorMsg.length > 500) {
                 errorMsg = errorMsg.substring(errorMsg.length - 500);
               }
               throw Exception('FFmpeg frame writer failed: $e. FFmpeg stderr: $errorMsg');
             }
          }
        }
        
        // Update progress
        renderService.updateProgress(f);
      }
      
      // 4. Finish Encode
      if (!_isCancelled) {
        if (!widget.isThumbnail && ffmpegSession != null && frameWriter != null) {
          await frameWriter.closeAndWait();
          if (frameWriter.errorMessage != null) {
            throw Exception(frameWriter.errorMessage);
          }
          final exitCode = await ffmpegSession.process.exitCode;
          if (exitCode != 0) {
            throw Exception('FFmpeg failed with exit code $exitCode');
          }
        }
        renderService.completeRender(widget.renderJob.outputPath ?? '');
      }
      
    } catch (e) {
      String errMsg = e.toString();
      if (ffmpegStderr.isNotEmpty) {
        String stderrStr = ffmpegStderr.toString();
        if (stderrStr.length > 500) {
           stderrStr = stderrStr.substring(stderrStr.length - 500);
        }
        errMsg += '\nFFmpeg Log:\n$stderrStr';
      }
      renderService.failRender(errMsg);
    } finally {
      frameWriter?.dispose();
      if (mounted) {
        setState(() {}); // trigger rebuild on finish
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // We watch the render service to get the latest job state
    final currentJob = context.watch<RenderService>().currentJob ?? widget.renderJob;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          // Hidden Render Engine
          Positioned(
            left: -10000,
            top: -10000,
            child: RepaintBoundary(
              key: _renderKey,
              child: RenderEngineWidget(
                project: widget.project,
                preset: widget.renderJob.preset,
                clock: _clock,
                resolvedTimings: _resolvedTimings,
              ),
            ),
          ),
          
          // UI
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Rendering Video', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                if (currentJob.status == RenderStatus.rendering) ...[
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: currentJob.progress,
                          strokeWidth: 8,
                          backgroundColor: AppColors.surfaceLight,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
                        ),
                      ),
                      Text(
                        '${(currentJob.progress * 100).toInt()}%',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Frame ${currentJob.currentFrame} of ${currentJob.totalFrames}', style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: currentJob.progress,
                    backgroundColor: AppColors.surfaceLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
                  ),
                  const SizedBox(height: 16),
                  Text('ETA: ${currentJob.eta}', style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () {
                      _isCancelled = true;
                      widget.onCancel();
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.accentRed, side: const BorderSide(color: AppColors.accentRed)),
                    child: const Text('Cancel'),
                  ),
                ] else if (currentJob.status == RenderStatus.complete) ...[
                  const Icon(Icons.check_circle, color: AppColors.accentGreen, size: 80),
                  const SizedBox(height: 16),
                  const Text('Render Complete!', style: TextStyle(color: AppColors.accentGreen, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(currentJob.outputPath ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue, foregroundColor: Colors.white),
                    child: const Text('Close'),
                  ),
                ] else if (currentJob.status == RenderStatus.failed) ...[
                  const Icon(Icons.error, color: AppColors.accentRed, size: 80),
                  const SizedBox(height: 16),
                  const Text('Render Failed', style: TextStyle(color: AppColors.accentRed, fontSize: 18)),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200, maxWidth: 500),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accentRed),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        currentJob.errorMessage ?? 'Unknown error occurred.',
                        style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Courier', fontSize: 12),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.surfaceLight, foregroundColor: AppColors.textPrimary),
                    child: const Text('Close'),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}
