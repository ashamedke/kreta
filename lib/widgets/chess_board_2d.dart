import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/asset_cache_service.dart';

class ChessBoard2D extends StatelessWidget {
  final String fen;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final bool isFlipped;
  final double size;
  final double? animationProgress;
  final String? animatingPiece;
  final String? animateFrom;
  final String? animateTo;

  const ChessBoard2D({
    Key? key,
    required this.fen,
    this.lastMoveFrom,
    this.lastMoveTo,
    this.isFlipped = false,
    required this.size,
    this.animationProgress,
    this.animatingPiece,
    this.animateFrom,
    this.animateTo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: ChessBoardPainter(
          fen: fen,
          lastMoveFrom: lastMoveFrom,
          lastMoveTo: lastMoveTo,
          isFlipped: isFlipped,
          animationProgress: animationProgress,
          animatingPiece: animatingPiece,
          animateFrom: animateFrom,
          animateTo: animateTo,
        ),
      ),
    );
  }
}

class ChessBoardPainter extends CustomPainter {
  final String fen;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final bool isFlipped;
  final double? animationProgress;
  final String? animatingPiece;
  final String? animateFrom;
  final String? animateTo;

  // Board 6 geometry in the 729x729 crop:
  // The full source image is 1366x768. The board crop starts at (318,19).
  // Inside the crop the 8x8 squares run from (23,24) to (707,707).
  static const double _cropSize   = 729.0;
  static const double _cropX      = 318.0;
  static const double _cropY      = 19.0;
  static const double _innerLeft  = 23.0;
  static const double _innerTop   = 24.0;
  static const double _innerRight = 707.0;
  static const double _innerBot   = 707.0;

  ChessBoardPainter({
    required this.fen,
    this.lastMoveFrom,
    this.lastMoveTo,
    this.isFlipped = false,
    this.animationProgress,
    this.animatingPiece,
    this.animateFrom,
    this.animateTo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / _cropSize;

    // 1. Draw the board image (crop from full 1366x768 source)
    final boardImage = AssetCacheService().boardImage;
    if (boardImage != null) {
      final src = Rect.fromLTWH(_cropX, _cropY, _cropSize, _cropSize);
      final dst = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(boardImage, src, dst, Paint());
    } else {
      final double sq = size.width / 8;
      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          canvas.drawRect(
            Rect.fromLTWH(c * sq, r * sq, sq, sq),
            Paint()..color = (r + c) % 2 == 0 ? AppColors.boardLight : AppColors.boardDark,
          );
        }
      }
    }

    // 2. Compute inner grid geometry in widget space
    final double bL = _innerLeft * scale;
    final double bT = _innerTop  * scale;
    final double bR = (_cropSize - _innerRight) * scale;
    final double bB = (_cropSize - _innerBot)   * scale;
    final double sqW = (size.width  - bL - bR) / 8.0;
    final double sqH = (size.height - bT - bB) / 8.0;

    Offset _origin(int col, int row) => Offset(
      bL + (isFlipped ? 7 - col : col) * sqW,
      bT + (isFlipped ? 7 - row : row) * sqH,
    );

    // 3. Highlight last move
    final hlPaint = Paint()..color = const Color(0xFF6fbf6f).withValues(alpha: 0.45);
    void highlight(String sq) {
      final c = sq.codeUnitAt(0) - 97;
      final r = 8 - int.parse(sq[1]);
      final o = _origin(c, r);
      canvas.drawRect(Rect.fromLTWH(o.dx, o.dy, sqW, sqH), hlPaint);
    }
    if (lastMoveFrom != null) highlight(lastMoveFrom!);
    if (lastMoveTo   != null) highlight(lastMoveTo!);

    // 4. File (A-H) and rank (1-8) labels in the border areas
    final double fontSize = (sqW * 0.20).clamp(10.0, 20.0);
    final labelStyle = TextStyle(
      color: const Color(0xFF7A5C14),
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
    );

    for (int i = 0; i < 8; i++) {
      // File labels along bottom border
      final file = String.fromCharCode(65 + (isFlipped ? 7 - i : i));
      final fp = TextPainter(text: TextSpan(text: file, style: labelStyle), textDirection: TextDirection.ltr)..layout();
      fp.paint(canvas, Offset(bL + i * sqW + (sqW - fp.width) / 2, size.height - bB + (bB - fp.height) / 2));

      // Rank labels along left border
      final rank = isFlipped ? '${i + 1}' : '${8 - i}';
      final rp = TextPainter(text: TextSpan(text: rank, style: labelStyle), textDirection: TextDirection.ltr)..layout();
      rp.paint(canvas, Offset((bL - rp.width) / 2, bT + i * sqH + (sqH - rp.height) / 2));
    }

    // 5. Draw static pieces
    final fenRows = fen.split(' ')[0].split('/');
    for (int row = 0; row < 8; row++) {
      int col = 0;
      for (final ch in fenRows[row].split('')) {
        if (RegExp(r'[1-8]').hasMatch(ch)) {
          col += int.parse(ch);
        } else {
          final sq = '${String.fromCharCode(97 + (isFlipped ? 7 - col : col))}${8 - (isFlipped ? 7 - row : row)}';
          final isAnimating = animatingPiece != null && animateFrom == sq && animationProgress != null;
          if (!isAnimating) _drawPiece(canvas, ch, _origin(col, row), sqW, sqH);
          col++;
        }
      }
    }

    // 6. Draw animating piece
    if (animatingPiece != null && animateFrom != null && animateTo != null && animationProgress != null) {
      int fc = animateFrom!.codeUnitAt(0) - 97;
      int fr = 8 - int.parse(animateFrom![1]);
      int tc = animateTo!.codeUnitAt(0) - 97;
      int tr = 8 - int.parse(animateTo![1]);
      final fo = _origin(fc, fr);
      final to = _origin(tc, tr);
      _drawPiece(
        canvas,
        animatingPiece!,
        Offset(fo.dx + (to.dx - fo.dx) * animationProgress!, fo.dy + (to.dy - fo.dy) * animationProgress!),
        sqW, sqH,
      );
    }
  }

  void _drawPiece(Canvas canvas, String ch, Offset origin, double sqW, double sqH) {
    final image = AssetCacheService().pieceImages[ch];
    if (image == null) return;
    final double srcW = image.width.toDouble();
    final double srcH = image.height.toDouble();
    // Scale to 90% of square width, maintain aspect ratio, bottom-align with small padding
    final double tW = sqW * 0.90;
    final double tH = tW * (srcH / srcW);
    final double x = origin.dx + (sqW - tW) / 2;
    final double y = origin.dy + sqH - tH - sqH * 0.03;
    canvas.drawImageRect(image, Rect.fromLTWH(0, 0, srcW, srcH), Rect.fromLTWH(x, y, tW, tH), Paint());
  }

  @override
  bool shouldRepaint(covariant ChessBoardPainter old) =>
      old.fen != fen ||
      old.lastMoveFrom != lastMoveFrom ||
      old.lastMoveTo != lastMoveTo ||
      old.isFlipped != isFlipped ||
      old.animationProgress != animationProgress;
}
