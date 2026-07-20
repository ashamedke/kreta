import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class AudioCue {
  final String path;
  final int timestampMs;
  AudioCue(this.path, this.timestampMs);
}

/// Wrapper service for executing FFmpeg commands.
class FfmpegService extends ChangeNotifier {
  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;
  
  String get _ffmpegPath {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final bundledPath = '${exeDir.path}\\ffmpeg.exe';
    if (File(bundledPath).existsSync()) {
      return bundledPath;
    }
    return 'ffmpeg';
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
      filterComplex.add('[$bgVideoIndex:v][0:v]overlay=0:0:shortest=1[vout]');
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
      filterComplex.add('${amixInput}amix=inputs=$totalAudioInputs:normalize=0[aout]');
      finalAudioOut = 'aout';
    } else if (totalAudioInputs == 1) {
      // If only one input (either background or 1 cue), just map it
      finalAudioOut = audioOutputs.first.replaceAll('[', '').replaceAll(']', '');
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

    if (audioPath != null) {
      args.addAll([
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        '-shortest',
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
      throw Exception('FFmpeg failed (exit code $exitCode):\n${stderrBuffer.toString()}');
    }
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
