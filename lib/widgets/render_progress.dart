import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/constants.dart';
import '../utils/virtual_clock.dart';
import '../models/render_job.dart';
import '../models/project.dart';
import '../services/render_service.dart';
import '../services/ffmpeg_service.dart';
import '../services/timing_resolver.dart';
import 'render_engine.dart';

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
  
  Future<void> _startRenderLoop() async {
    final renderService = context.read<RenderService>();
    final ffmpegService = context.read<FfmpegService>();
    
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
        final isRelease = const bool.fromEnvironment('dart.vm.product');
        final baseDir = isRelease ? '${File(Platform.resolvedExecutable).parent.path}/data/flutter_assets' : Directory.current.path;
        
        for (int i = 0; i < widget.project.game.plies.length; i++) {
          final ply = widget.project.game.plies[i];
          final timing = _resolvedTimings[i];
          final plyTotalTime = timing.holdDurationMs + timing.transitionDurationMs;
          
          if (timing.transitionDurationMs > 0 || i == 0) {
             final int hitTimeMs = (accumulatedTimeMs + timing.transitionDurationMs).toInt();
             final bool isCapture = ply.capturedPiece != null;
             final bool isPromotion = ply.isPromotion;
             String soundFile = 'put.wav';
             if (isPromotion) soundFile = 'promotion.wav';
             else if (isCapture) soundFile = 'capture.wav';
             
             audioCues.add(AudioCue('$baseDir/assets/audio/$soundFile', hitTimeMs));
          }
          accumulatedTimeMs += plyTotalTime;
        }
      }
      
      // 2. Setup temp directory for frames
      final tempDir = await getTemporaryDirectory();
      final framesDir = Directory('${tempDir.path}/chesscreator_frames_${DateTime.now().millisecondsSinceEpoch}');
      await framesDir.create();
      
      // 3. Render loop
      for (int f = 0; f < totalFrames; f++) {
        if (_isCancelled) {
          renderService.cancelRender();
          return;
        }
        
        // Update virtual clock
        if (widget.isThumbnail) {
           _clock.seekToFrame((totalDurationMs / 1000 * _clock.fps).ceil() ~/ 2); // Middle of the game
        } else {
           _clock.seekToFrame(f);
        }
        setState(() {}); // Rebuild RenderEngineWidget with new clock time
        
        // Wait for frame to paint
        await Future.delayed(const Duration(milliseconds: 16)); 
        
        // Capture image
        final boundary = _renderKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 1.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          final bytes = byteData!.buffer.asUint8List();
          
          if (widget.isThumbnail) {
             final frameFile = File(widget.renderJob.outputPath ?? '');
             await frameFile.writeAsBytes(bytes);
          } else {
             final frameFile = File('${framesDir.path}/frame_${f.toString().padLeft(6, '0')}.png');
             await frameFile.writeAsBytes(bytes);
          }
        }
        
        // Update progress
        renderService.updateProgress(f);
      }
      
      // 4. FFmpeg Encode (skip for thumbnail)
      if (!_isCancelled) {
        if (!widget.isThumbnail) {
           await ffmpegService.encodeVideo(
             framesDir: framesDir.path,
             outputPath: widget.renderJob.outputPath ?? '',
             fps: _clock.fps,
             videoBitrate: widget.renderJob.preset.videoBitrate,
             backgroundVideoPath: widget.project.backgroundVideoPath,
             audioPath: widget.project.backgroundMusicPath,
             audioCues: audioCues,
           );
        }
        renderService.completeRender(widget.renderJob.outputPath ?? '');
      }
      
      // Cleanup frames
      await framesDir.delete(recursive: true);
      
    } catch (e) {
      renderService.failRender(e.toString());
    } finally {
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
