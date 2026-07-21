import 'dart:typed_data';
import 'package:flutter/material.dart';

class AudioWaveformPainter extends CustomPainter {
  final Float32List peaks;
  final double pixelsPerMs;
  final int startTimeMs;
  final int? endTimeMs;
  final Color color;

  AudioWaveformPainter({
    required this.peaks,
    required this.pixelsPerMs,
    required this.startTimeMs,
    this.endTimeMs,
    this.color = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final maxAmplitude = size.height / 2;

    // The peaks list is 100Hz (1 sample per 10ms)
    final double msPerSample = 10.0;
    
    // We only need to draw the samples that fit in the width of the canvas
    final totalDurationMs = size.width / pixelsPerMs;
    final totalSamples = (totalDurationMs / msPerSample).ceil();
    
    // Calculate how many samples are available vs how many we need
    final samplesToDraw = totalSamples.clamp(0, peaks.length);

    for (int i = 0; i < samplesToDraw; i++) {
      final floatVal = peaks[i].abs();
      // clamp floatVal to 0.0 - 1.0 just in case
      final normalized = floatVal.clamp(0.0, 1.0);
      
      final x = (i * msPerSample) * pixelsPerMs;
      final yOffset = normalized * maxAmplitude;

      canvas.drawLine(
        Offset(x, centerY - yOffset),
        Offset(x, centerY + yOffset),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant AudioWaveformPainter oldDelegate) {
    return oldDelegate.peaks != peaks ||
           oldDelegate.pixelsPerMs != pixelsPerMs ||
           oldDelegate.startTimeMs != startTimeMs ||
           oldDelegate.color != color;
  }
}
