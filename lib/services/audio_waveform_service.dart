import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'ffmpeg_service.dart';

class AudioWaveformService extends ChangeNotifier {
  static final AudioWaveformService _instance = AudioWaveformService._internal();
  factory AudioWaveformService() => _instance;
  AudioWaveformService._internal();

  final Map<String, Float32List> _cache = {};

  /// Resolves the peaks for an audio file. Returns null if ffmpeg fails or is unavailable.
  Future<Float32List?> getWaveform(String audioPath, FfmpegService ffmpegService) async {
    if (_cache.containsKey(audioPath)) {
      return _cache[audioPath];
    }
    
    if (!ffmpegService.isAvailable) return null;

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/waveform_${DateTime.now().millisecondsSinceEpoch}.raw');
      
      // Extract to mono, 100 samples per second, 32-bit float
      final result = await Process.run(ffmpegService.ffmpegPath, [
        '-y',
        '-i', audioPath,
        '-f', 'f32le',
        '-ac', '1',
        '-ar', '100', // 100 Hz = 1 sample per 10ms
        tempFile.path
      ]);

      if (result.exitCode != 0) {
        debugPrint('Waveform extraction failed: ${result.stderr}');
        return null;
      }

      if (await tempFile.exists()) {
        final bytes = await tempFile.readAsBytes();
        final Float32List floats = Float32List.view(bytes.buffer);
        _cache[audioPath] = floats;
        await tempFile.delete();
        return floats;
      }
    } catch (e) {
      debugPrint('Waveform generation error: $e');
    }
    
    return null;
  }
}
