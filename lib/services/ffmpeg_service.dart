import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

class AudioCue {
  final String path;
  final int timestampMs;
  AudioCue(this.path, this.timestampMs);
}

/// Handle returned by [FfmpegService.startEncodeStream].
///
/// Wraps the FFmpeg [process] together with a [videoSink] that raw RGBA
/// frames should be written to. Historically this was `process.stdin`;
/// it is now backed by a local TCP loopback socket so that:
///   - writes never share a buffer with process stdin/stderr plumbing
///   - a stalled or crashed FFmpeg surfaces as a socket error we can
///     catch independently of process lifecycle
///   - the write path can be driven from a background Isolate (see
///     render_progress.dart), since a Socket can be created and used
///     entirely within that isolate.
///
/// Callers should treat [videoSink] like an [IOSink]: call `add(bytes)`
/// per frame, then `await close()` when done, then await [process.exitCode].
class FfmpegEncodeSession {
  final Process process;
  final Socket videoSink;
  final int listenPort;

  FfmpegEncodeSession({
    required this.process,
    required this.videoSink,
    required this.listenPort,
  });

  /// Closes the video socket. Does NOT wait for the ffmpeg process to
  /// exit — callers should still `await process.exitCode` afterwards.
  Future<void> closeVideoSink() async {
    try {
      await videoSink.flush();
    } catch (_) {
      // Socket may already be closed if ffmpeg exited early; ignore.
    }
    await videoSink.close();
  }
}

/// Wrapper service for executing FFmpeg commands.
class FfmpegService extends ChangeNotifier {
  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;
  
  String _ffmpegPath = 'ffmpeg';
  String get ffmpegPath => _ffmpegPath;
  
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('ffmpeg_path');
    if (savedPath != null) {
      _ffmpegPath = savedPath;
    }
    await checkAvailability();
  }
  
  Future<void> checkAvailability() async {
    _isAvailable = await _checkAvailability();
    notifyListeners();
  }
  
  /// Checks if FFmpeg is available in the system PATH.
  Future<bool> _checkAvailability() async {
    try {
      final result = await Process.run(_ffmpegPath, ['-version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Retrieves the FFmpeg version string.
  Future<String> getVersion() async {
    try {
      final result = await Process.run(_ffmpegPath, ['-version']);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        // Typically the first line contains the version
        return output.split('\n').first;
      } else {
        throw Exception('Failed to get ffmpeg version: ${result.stderr}');
      }
    } catch (e) {
      throw Exception('Could not execute ffmpeg: $e');
    }
  }

  /// Encodes a sequence of image frames into a video.
  ///
  /// (Unchanged — this path reads a frame directory from disk and isn't
  /// part of the live-render hot path, so it's left on the simple
  /// Process.run implementation.)
  Future<void> encodeVideo({
    required String framesDir,
    required String outputPath,
    required int fps,
    int videoBitrate = 8000,
    String? audioPath,
    String? backgroundVideoPath,
    List<AudioCue> audioCues = const [],
    void Function(int frame, int total)? onProgress,
  }) async {
    final args = [
      '-y',
      '-framerate',
      fps.toString(),
      '-i',
      '$framesDir/frame_%06d.png',
    ];

    int inputIndex = 1;
    int bgVideoIndex = -1;
    int bgAudioIndex = -1;
    
    if (backgroundVideoPath != null) {
      args.addAll(['-i', backgroundVideoPath]);
      bgVideoIndex = inputIndex++;
    }

    if (audioPath != null) {
      args.addAll(['-i', audioPath]);
      bgAudioIndex = inputIndex++;
    }

    // Add audio cues
    final int cueStartIndex = inputIndex;
    for (var cue in audioCues) {
      args.addAll(['-i', cue.path]);
      inputIndex++;
    }

    List<String> filterComplex = [];
    String finalVideoOut = '0:v';
    
    if (bgVideoIndex != -1) {
      // Use filter_complex to overlay the transparent PNG sequence [0:v] on top of the background [1:v]
      filterComplex.add('[$bgVideoIndex:v][0:v]overlay=0:0[vout]');
      finalVideoOut = 'vout';
    }

    // Build Audio filter complex
    String finalAudioOut = '';
    int totalAudioInputs = 0;
    List<String> audioOutputs = [];

    if (bgAudioIndex != -1) {
      audioOutputs.add('[$bgAudioIndex:a]');
      totalAudioInputs++;
    }

    for (int i = 0; i < audioCues.length; i++) {
      final cueIndex = cueStartIndex + i;
      final delay = audioCues[i].timestampMs;
      final outName = 'a$i';
      filterComplex.add('[$cueIndex:a]adelay=$delay|$delay[$outName]');
      audioOutputs.add('[$outName]');
      totalAudioInputs++;
    }

    if (totalAudioInputs > 1) {
      final amixInput = audioOutputs.join('');
      filterComplex.add('${amixInput}amix=inputs=$totalAudioInputs:normalize=0,apad[aout]');
      finalAudioOut = 'aout';
    } else if (totalAudioInputs == 1) {
      final input = audioOutputs.first;
      filterComplex.add('$input apad[aout]');
      finalAudioOut = 'aout';
    }

    if (filterComplex.isNotEmpty) {
      args.addAll(['-filter_complex', filterComplex.join(';')]);
    }
    
    if (finalVideoOut != '0:v') {
      args.addAll(['-map', '[$finalVideoOut]']);
    } else {
      args.addAll(['-map', '0:v']);
    }

    if (finalAudioOut.isNotEmpty) {
      if (finalAudioOut == bgAudioIndex.toString() + ':a') {
         args.addAll(['-map', finalAudioOut]);
      } else {
         args.addAll(['-map', '[$finalAudioOut]']);
      }
    }

    args.addAll([
      '-c:v',
      'libx264',
      '-preset',
      'medium',
      '-b:v',
      '${videoBitrate}k',
      '-pix_fmt',
      'yuv420p',
    ]);

    if (finalAudioOut.isNotEmpty) {
      args.addAll([
        '-c:a',
        'aac',
        '-b:a',
        '192k',
      ]);
    }

    args.add(outputPath);

    final process = await Process.start(_ffmpegPath, args);

    final StringBuffer stderrBuffer = StringBuffer();
    // FFmpeg writes progress to stderr
    process.stderr.transform(utf8.decoder).listen((data) {
      stderrBuffer.write(data);
      // Parse frame=  123 from output if onProgress is provided
      if (onProgress != null) {
        final frameMatch = RegExp(r'frame=\s*(\d+)').firstMatch(data);
        if (frameMatch != null) {
          final frame = int.tryParse(frameMatch.group(1)!) ?? 0;
          // Note: total is hard to extract from standard ffmpeg stderr without knowing input count.
          // Passing 0 for total as placeholder.
          onProgress(frame, 0); 
        }
      }
    });

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final err = stderrBuffer.toString();
      final truncated = err.length > 1000 ? err.substring(err.length - 1000) : err;
      throw Exception('FFmpeg failed (exit code $exitCode):\n...$truncated');
    }
  }

  /// Starts an FFmpeg process that reads raw RGBA video frames over a local
  /// TCP loopback socket (instead of stdin).
  ///
  /// FFmpeg is started with `-i tcp://127.0.0.1:<port>?listen`, which makes
  /// FFmpeg the server; we then connect to it as a client and return that
  /// connected [Socket] as [FfmpegEncodeSession.videoSink].
  ///
  /// Why this instead of stdin:
  ///  - stdin.add() on a Process is bound to the parent-process pipe
  ///    plumbing; a full OS pipe buffer or an early-exited ffmpeg turns
  ///    into a raw SocketException on the *process* stdin, which is easy
  ///    to conflate with unrelated failures. A dedicated socket keeps the
  ///    frame stream isolated from process control.
  ///  - a Socket can be created and driven from inside a background
  ///    Isolate (an IOSink tied to a spawned Process's stdin cannot be
  ///    handed across isolates), which is what unblocks the UI-thread
  ///    write in render_progress.dart.
  ///
  /// Note: `-shortest` combined with `apad`/`amix` can still cause ffmpeg
  /// to exit before all video frames are written if the audio track ends
  /// up shorter than expected — that's an encoding-graph duration issue,
  /// not an IPC issue, and isn't fixed by this change. Callers should
  /// still catch write errors on [FfmpegEncodeSession.videoSink] as a
  /// signal that ffmpeg exited early, and surface ffmpeg's stderr.
  Future<FfmpegEncodeSession> startEncodeStream({
    required int width,
    required int height,
    required int fps,
    required String outputPath,
    int videoBitrate = 8000,
    String? audioPath,
    String? backgroundVideoPath,
    List<AudioCue> audioCues = const [],
  }) async {
    // 1. Bind a loopback server socket on an ephemeral port so ffmpeg has
    //    something to connect its listen-mode tcp input to.
    final serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = serverSocket.port;

    final args = [
      '-y',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgba',
      '-s',
      '${width}x$height',
      '-r',
      fps.toString(),
      '-i',
      'tcp://127.0.0.1:$port?listen=1',
    ];

    int inputIndex = 1;
    int bgVideoIndex = -1;
    int bgAudioIndex = -1;
    
    if (backgroundVideoPath != null) {
      args.addAll(['-i', backgroundVideoPath]);
      bgVideoIndex = inputIndex++;
    }

    if (audioPath != null) {
      args.addAll(['-i', audioPath]);
      bgAudioIndex = inputIndex++;
    }

    // Add audio cues
    final int cueStartIndex = inputIndex;
    for (var cue in audioCues) {
      args.addAll(['-i', cue.path]);
      inputIndex++;
    }

    List<String> filterComplex = [];
    String finalVideoOut = '0:v';
    
    if (bgVideoIndex != -1) {
      filterComplex.add('[$bgVideoIndex:v][0:v]overlay=0:0[vout]');
      finalVideoOut = 'vout';
    }

    // Build Audio filter complex
    String finalAudioOut = '';
    int totalAudioInputs = 0;
    List<String> audioOutputs = [];

    if (bgAudioIndex != -1) {
      audioOutputs.add('[$bgAudioIndex:a]');
      totalAudioInputs++;
    }

    for (int i = 0; i < audioCues.length; i++) {
      final cueIndex = cueStartIndex + i;
      final delay = audioCues[i].timestampMs;
      final outName = 'a$i';
      filterComplex.add('[$cueIndex:a]adelay=$delay|$delay[$outName]');
      audioOutputs.add('[$outName]');
      totalAudioInputs++;
    }

    if (totalAudioInputs > 1) {
      final amixInput = audioOutputs.join('');
      filterComplex.add('${amixInput}amix=inputs=$totalAudioInputs:normalize=0,apad[aout]');
      finalAudioOut = 'aout';
    } else if (totalAudioInputs == 1) {
      final input = audioOutputs.first;
      filterComplex.add('$input apad[aout]');
      finalAudioOut = 'aout';
    }

    if (filterComplex.isNotEmpty) {
      args.addAll(['-filter_complex', filterComplex.join(';')]);
    }
    
    if (finalVideoOut != '0:v') {
      args.addAll(['-map', '[$finalVideoOut]']);
    } else {
      args.addAll(['-map', '0:v']);
    }

    if (finalAudioOut.isNotEmpty) {
      if (finalAudioOut == bgAudioIndex.toString() + ':a') {
         args.addAll(['-map', finalAudioOut]);
      } else {
         args.addAll(['-map', '[$finalAudioOut]']);
      }
    }

    args.addAll([
      '-c:v',
      'libx264',
      '-preset',
      'ultrafast', // Much faster encoding
      '-b:v',
      '${videoBitrate}k',
      '-pix_fmt',
      'yuv420p',
    ]);

    if (finalAudioOut.isNotEmpty) {
      args.addAll([
        '-c:a',
        'aac',
        '-b:a',
        '192k',
      ]);
    }

    args.add(outputPath);

    // 2. Start ffmpeg. It will connect back to our server socket almost
    //    immediately since it's in listen mode on the tcp input.
    final process = await Process.start(_ffmpegPath, args);

    // 3. Accept ffmpeg's connection. Guard with a timeout in case ffmpeg
    //    fails to start (bad path, bad args, or media probing takes long)
    //    before it ever connects. Background media causes ffmpeg to probe
    //    files before binding its tcp listener, so allow extra time.
    final stderrBuffer = StringBuffer();
    process.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen(stderrBuffer.write);

    Socket videoSocket;
    try {
      videoSocket = await serverSocket.first.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          process.kill();
          final hint = stderrBuffer.toString().trim();
          throw TimeoutException(
            'FFmpeg did not connect to the frame socket within 45s.\n'
            'FFmpeg stderr:\n${hint.isEmpty ? "(no output)" : hint.length > 800 ? hint.substring(hint.length - 800) : hint}',
          );
        },
      );
    } finally {
      // Whether we got a connection or not, stop listening for more.
      await serverSocket.close();
    }

    return FfmpegEncodeSession(
      process: process,
      videoSink: videoSocket,
      listenPort: port,
    );
  }

  /// Extracts a single frame as a thumbnail.
  Future<void> extractThumbnail({
    required String videoPath,
    required String outputPath,
    required double timestampSec,
  }) async {
    final args = [
      '-ss',
      timestampSec.toString(),
      '-i',
      videoPath,
      '-vframes',
      '1',
      '-y',
      outputPath,
    ];

    final result = await Process.run(_ffmpegPath, args);
    if (result.exitCode != 0) {
      throw Exception('Failed to extract thumbnail: ${result.stderr}');
    }
  }
}
