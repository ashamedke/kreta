import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import '../utils/constants.dart';
import '../services/asset_cache_service.dart';
import '../models/game.dart' show BoardArrow;

// ---------------------------------------------------------------------------
// Layering rationale:
//
// The old single-painter version's shouldRepaint returned true whenever
// `animationProgress` changed — which is every frame of every transition.
// That meant the board image, both highlight rects, the check glow, all
// 16 rank/file labels, and all up-to-31 static pieces were re-rasterized
// on every frame, even though only the one moving piece actually changes
// between frames.
//
// Splitting into two CustomPaint layers (each its own RepaintBoundary)
// means Flutter can reuse the static layer's rasterized layer across
// frames — during a transition, only the small animating-piece layer
// actually repaints. The static layer only repaints at phase boundaries
// (ply change, or the moment a transition starts/ends), not on every
// animationProgress tick.
// ---------------------------------------------------------------------------

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
  final bool isCheck;
  final List<BoardArrow> arrows;

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
    this.isCheck = false,
    this.arrows = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isPieceAnimating = animationProgress != null;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Static layer: board, highlights, check glow, labels, arrows,
          // and every piece that isn't currently mid-move. Only repaints
          // when the ply-level state actually changes.
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _StaticBoardPainter(
                  fen: fen,
                  lastMoveFrom: lastMoveFrom,
                  lastMoveTo: lastMoveTo,
                  isFlipped: isFlipped,
                  isCheck: isCheck,
                  arrows: arrows,
                  isPieceAnimating: isPieceAnimating,
                  animatingFromSquare: animateFrom,
                ),
              ),
            ),
          ),
          // Animating layer: just the single moving piece. Repaints every
          // frame during a transition — that's fine, it's a tiny paint.
          if (isPieceAnimating && animatingPiece != null && animateFrom != null && animateTo != null)
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _AnimatingPiecePainter(
                    isFlipped: isFlipped,
                    animationProgress: animationProgress!,
                    animatingPiece: animatingPiece!,
                    animateFrom: animateFrom!,
                    animateTo: animateTo!,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shared board geometry, factored out so both painters compute identical
/// square origins without duplicating (and risking drift between) the math.
class _BoardGeometry {
  // Board geometry in the 729x729 crop:
  // The full source image is 1366x768. The board crop starts at (318,19).
  // Inside the crop the 8x8 squares run from (23,24) to (707,707).
  static const double cropSize = 729.0;
  static const double cropX = 318.0;
  static const double cropY = 19.0;
  static const double innerLeft = 23.0;
  static const double innerTop = 24.0;
  static const double innerRight = 707.0;
  static const double innerBot = 707.0;

  final double scale;
  final double bL, bT, bR, bB;
  final double sqW, sqH;
  final bool isFlipped;

  _BoardGeometry(Size size, this.isFlipped)
      : scale = size.width / cropSize,
        bL = innerLeft * (size.width / cropSize),
        bT = innerTop * (size.width / cropSize),
        bR = (cropSize - innerRight) * (size.width / cropSize),
        bB = (cropSize - innerBot) * (size.width / cropSize),
        sqW = (size.width - innerLeft * (size.width / cropSize) - (cropSize - innerRight) * (size.width / cropSize)) / 8.0,
        sqH = (size.height - innerTop * (size.width / cropSize) - (cropSize - innerBot) * (size.width / cropSize)) / 8.0;

  Offset origin(int col, int row) => Offset(
        bL + (isFlipped ? 7 - col : col) * sqW,
        bT + (isFlipped ? 7 - row : row) * sqH,
      );
}

void _drawPieceOn(Canvas canvas, String ch, Offset origin, double sqW, double sqH) {
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

void _drawArrowOn(Canvas canvas, Offset start, Offset end, Color color, double sqW) {
  final paint = Paint()
    ..color = color.withValues(alpha: 0.8)
    ..strokeWidth = sqW * 0.15
    ..strokeCap = StrokeCap.round;

  canvas.drawLine(start, end, paint);

  final d = end - start;
  final angle = d.direction;
  final arrowHeadLen = sqW * 0.4;

  final path = Path();
  path.moveTo(end.dx, end.dy);
  path.lineTo(
    end.dx - arrowHeadLen * math.cos(angle - math.pi / 6),
    end.dy - arrowHeadLen * math.sin(angle - math.pi / 6),
  );
  path.lineTo(
    end.dx - arrowHeadLen * math.cos(angle + math.pi / 6),
    end.dy - arrowHeadLen * math.sin(angle + math.pi / 6),
  );
  path.close();

  final headPaint = Paint()..color = color.withValues(alpha: 0.8);
  canvas.drawPath(path, headPaint);
}

class _StaticBoardPainter extends CustomPainter {
  final String fen;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final bool isFlipped;
  final bool isCheck;
  final List<BoardArrow> arrows;

  /// Whether a piece is currently mid-transition. When true, the piece
  /// at [animatingFromSquare] is skipped here (the animating-piece layer
  /// draws it instead). We deliberately don't take animationProgress
  /// itself — that would defeat the whole point of this split.
  final bool isPieceAnimating;
  final String? animatingFromSquare;

  _StaticBoardPainter({
    required this.fen,
    this.lastMoveFrom,
    this.lastMoveTo,
    this.isFlipped = false,
    this.isCheck = false,
    this.arrows = const [],
    this.isPieceAnimating = false,
    this.animatingFromSquare,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geo = _BoardGeometry(size, isFlipped);

    // 1. Draw the board image (crop from full 1366x768 source)
    final boardImage = AssetCacheService().boardImage;
    if (boardImage != null) {
      final src = Rect.fromLTWH(_BoardGeometry.cropX, _BoardGeometry.cropY, _BoardGeometry.cropSize, _BoardGeometry.cropSize);
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

    // 2. Highlight last move
    final hlPaint = Paint()..color = const Color(0xFF6fbf6f).withValues(alpha: 0.45);
    void highlight(String sq) {
      final c = sq.codeUnitAt(0) - 97;
      final r = 8 - int.parse(sq[1]);
      final o = geo.origin(c, r);
      canvas.drawRect(Rect.fromLTWH(o.dx, o.dy, geo.sqW, geo.sqH), hlPaint);
    }
    if (lastMoveFrom != null) highlight(lastMoveFrom!);
    if (lastMoveTo != null) highlight(lastMoveTo!);

    // Highlight check in red
    if (isCheck) {
      final fenParts = fen.split(' ');
      if (fenParts.length >= 2) {
        final activeColor = fenParts[1];
        final kingChar = activeColor == 'w' ? 'K' : 'k';
        final fenRows = fenParts[0].split('/');
        for (int r = 0; r < 8; r++) {
          int c = 0;
          for (final ch in fenRows[r].split('')) {
            if (RegExp(r'[1-8]').hasMatch(ch)) {
              c += int.parse(ch);
            } else {
              if (ch == kingChar) {
                final o = geo.origin(c, r);
                final Rect kingRect = Rect.fromLTWH(o.dx, o.dy, geo.sqW, geo.sqH);
                final checkPaint = Paint()
                  ..shader = RadialGradient(
                    colors: [Colors.red.withValues(alpha: 0.8), Colors.red.withValues(alpha: 0.0)],
                    stops: const [0.2, 0.8],
                  ).createShader(kingRect);
                canvas.drawRect(kingRect, checkPaint);
              }
              c++;
            }
          }
        }
      }
    }

    // 3. File (A-H) and rank (1-8) labels in the border areas
    final double fontSize = (geo.sqW * 0.20).clamp(10.0, 20.0);
    final labelStyle = TextStyle(
      color: Colors.white,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
    );

    for (int i = 0; i < 8; i++) {
      // File labels along bottom border
      final file = String.fromCharCode(65 + (isFlipped ? 7 - i : i));
      final fp = TextPainter(text: TextSpan(text: file, style: labelStyle), textDirection: TextDirection.ltr)..layout();
      fp.paint(canvas, Offset(geo.bL + i * geo.sqW + (geo.sqW - fp.width) / 2, size.height - geo.bB + (geo.bB - fp.height) / 2));

      // Rank labels along left border
      final rank = isFlipped ? '${i + 1}' : '${8 - i}';
      final rp = TextPainter(text: TextSpan(text: rank, style: labelStyle), textDirection: TextDirection.ltr)..layout();
      rp.paint(canvas, Offset((geo.bL - rp.width) / 2, geo.bT + i * geo.sqH + (geo.sqH - rp.height) / 2));
    }

    // 4. Draw static pieces (skips the one currently animating, if any)
    final fenRows = fen.split(' ')[0].split('/');
    for (int row = 0; row < 8; row++) {
      int col = 0;
      for (final ch in fenRows[row].split('')) {
        if (RegExp(r'[1-8]').hasMatch(ch)) {
          col += int.parse(ch);
        } else {
          final sq = '${String.fromCharCode(97 + (isFlipped ? 7 - col : col))}${8 - (isFlipped ? 7 - row : row)}';
          final isAnimatingHere = isPieceAnimating && animatingFromSquare == sq;
          if (!isAnimatingHere) _drawPieceOn(canvas, ch, geo.origin(col, row), geo.sqW, geo.sqH);
          col++;
        }
      }
    }

    // 5. Draw Arrows
    for (final arrow in arrows) {
      if (arrow.fromSquare.length >= 2 && arrow.toSquare.length >= 2) {
        int fc = arrow.fromSquare.codeUnitAt(0) - 97;
        int fr = 8 - int.parse(arrow.fromSquare[1]);
        int tc = arrow.toSquare.codeUnitAt(0) - 97;
        int tr = 8 - int.parse(arrow.toSquare[1]);

        final fo = geo.origin(fc, fr);
        final to = geo.origin(tc, tr);

        final start = Offset(fo.dx + geo.sqW / 2, fo.dy + geo.sqH / 2);
        final end = Offset(to.dx + geo.sqW / 2, to.dy + geo.sqH / 2);

        _drawArrowOn(canvas, start, end, Color(int.parse(arrow.color.replaceFirst('#', '0xFF'))), geo.sqW);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StaticBoardPainter old) =>
      old.fen != fen ||
      old.lastMoveFrom != lastMoveFrom ||
      old.lastMoveTo != lastMoveTo ||
      old.isFlipped != isFlipped ||
      old.isCheck != isCheck ||
      old.isPieceAnimating != isPieceAnimating ||
      old.animatingFromSquare != animatingFromSquare ||
      !listEquals(old.arrows, arrows);
}

class _AnimatingPiecePainter extends CustomPainter {
  final bool isFlipped;
  final double animationProgress;
  final String animatingPiece;
  final String animateFrom;
  final String animateTo;

  _AnimatingPiecePainter({
    required this.isFlipped,
    required this.animationProgress,
    required this.animatingPiece,
    required this.animateFrom,
    required this.animateTo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geo = _BoardGeometry(size, isFlipped);

    int fc = animateFrom.codeUnitAt(0) - 97;
    int fr = 8 - int.parse(animateFrom[1]);
    int tc = animateTo.codeUnitAt(0) - 97;
    int tr = 8 - int.parse(animateTo[1]);
    final fo = geo.origin(fc, fr);
    final to = geo.origin(tc, tr);

    final double curvedProgress = Curves.easeInOutCubic.transform(animationProgress);

    _drawPieceOn(
      canvas,
      animatingPiece,
      Offset(fo.dx + (to.dx - fo.dx) * curvedProgress, fo.dy + (to.dy - fo.dy) * curvedProgress),
      geo.sqW,
      geo.sqH,
    );
  }

  @override
  bool shouldRepaint(covariant _AnimatingPiecePainter old) =>
      old.animationProgress != animationProgress ||
      old.animatingPiece != animatingPiece ||
      old.animateFrom != animateFrom ||
      old.animateTo != animateTo ||
      old.isFlipped != isFlipped;
}
