import 'package:flutter/material.dart';
import '../utils/constants.dart';

class TerminalText extends StatelessWidget {
  final String fullText;
  final double revealProgress;
  final bool showCursor;
  final double cursorBlinkProgress;
  final Color textColor;
  final double fontSize;

  const TerminalText({
    Key? key,
    required this.fullText,
    required this.revealProgress,
    this.showCursor = true,
    this.cursorBlinkProgress = 1.0,
    this.textColor = AppColors.accentGreen,
    this.fontSize = 14.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int visibleCharCount = (revealProgress.clamp(0.0, 1.0) * fullText.length).floor();
    final String visibleText = fullText.substring(0, visibleCharCount);
    final bool isCursorVisible = showCursor && (cursorBlinkProgress > 0.5);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Text(
              '> analysis.log',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: CustomPaint(
              foregroundPainter: ScanlinePainter(),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: fontSize,
                      color: textColor,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(text: visibleText),
                      if (isCursorVisible)
                        const TextSpan(text: '█'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double i = 0; i < size.height; i += 2) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
