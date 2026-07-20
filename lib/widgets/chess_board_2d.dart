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
    final double squareSize = size.width / 8;

    // Draw board
    final boardImage = AssetCacheService().boardImage;
    if (boardImage != null) {
      final src = Rect.fromLTWH(0, 0, boardImage.width.toDouble(), boardImage.height.toDouble());
      final dst = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(boardImage, src, dst, Paint());
    } else {
      for (int row = 0; row < 8; row++) {
        for (int col = 0; col < 8; col++) {
          final bool isLight = (row + col) % 2 == 0;
          final Paint paint = Paint()
            ..color = isLight ? AppColors.boardLight : AppColors.boardDark;
          canvas.drawRect(
            Rect.fromLTWH(col * squareSize, row * squareSize, squareSize, squareSize),
            paint,
          );
        }
      }
    }

    // Draw coordinate labels (a-h, 1-8)
    final textStyle = TextStyle(color: AppColors.surfaceLight, fontSize: squareSize * 0.2);
    for (int i = 0; i < 8; i++) {
      // Columns (a-h)
      final colStr = String.fromCharCode('a'.codeUnitAt(0) + (isFlipped ? 7 - i : i));
      final colPainter = TextPainter(
        text: TextSpan(text: colStr, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      colPainter.paint(canvas, Offset(i * squareSize + squareSize - colPainter.width - 2, size.height - colPainter.height - 2));

      // Rows (1-8)
      final rowStr = isFlipped ? '${i + 1}' : '${8 - i}';
      final rowPainter = TextPainter(
        text: TextSpan(text: rowStr, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      rowPainter.paint(canvas, Offset(2, i * squareSize + 2));
    }

    // Highlight last move
    final highlightPaint = Paint()..color = AppColors.accentBlue.withOpacity(0.4);
    if (lastMoveFrom != null) {
      final pos = _squareToPos(lastMoveFrom!);
      canvas.drawRect(
        Rect.fromLTWH(pos.dx * squareSize, pos.dy * squareSize, squareSize, squareSize),
        highlightPaint,
      );
    }
    if (lastMoveTo != null) {
      final pos = _squareToPos(lastMoveTo!);
      canvas.drawRect(
        Rect.fromLTWH(pos.dx * squareSize, pos.dy * squareSize, squareSize, squareSize),
        highlightPaint,
      );
    }

    // Parse FEN
    final rows = fen.split(' ')[0].split('/');
    for (int row = 0; row < 8; row++) {
      int col = 0;
      for (int i = 0; i < rows[row].length; i++) {
        final char = rows[row][i];
        if (RegExp(r'[1-8]').hasMatch(char)) {
          col += int.parse(char);
        } else {
          final square = _posToSquare(Offset(col.toDouble(), row.toDouble()));
          
          bool shouldDrawStatic = true;
          if (animatingPiece != null && animateFrom == square && animationProgress != null) {
            shouldDrawStatic = false;
          }

          if (shouldDrawStatic) {
            _drawPiece(canvas, char, col.toDouble(), row.toDouble(), squareSize);
          }
          col++;
        }
      }
    }

    // Draw animating piece
    if (animatingPiece != null && animateFrom != null && animateTo != null && animationProgress != null) {
      final fromPos = _squareToPos(animateFrom!);
      final toPos = _squareToPos(animateTo!);
      
      final currentX = fromPos.dx + (toPos.dx - fromPos.dx) * animationProgress!;
      final currentY = fromPos.dy + (toPos.dy - fromPos.dy) * animationProgress!;
      
      _drawPiece(canvas, animatingPiece!, currentX, currentY, squareSize);
    }
  }

  void _drawPiece(Canvas canvas, String pieceChar, double col, double row, double squareSize) {
    final image = AssetCacheService().pieceImages[pieceChar];
    if (image == null) return;

    // The piece images often have transparent padding. 
    // We scale them slightly larger than the square and offset them slightly up to create a 3D depth effect.
    final double pieceScale = 1.2;
    final double scaledSize = squareSize * pieceScale;
    
    final xOffset = col * squareSize - (scaledSize - squareSize) / 2;
    final yOffset = row * squareSize - (scaledSize - squareSize); // Shift up

    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(xOffset, yOffset, scaledSize, scaledSize);
    
    canvas.drawImageRect(image, src, dst, Paint());
  }

  Offset _squareToPos(String square) {
    final col = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final row = 8 - int.parse(square[1]);
    if (isFlipped) {
      return Offset((7 - col).toDouble(), (7 - row).toDouble());
    }
    return Offset(col.toDouble(), row.toDouble());
  }

  String _posToSquare(Offset pos) {
    int col = pos.dx.toInt();
    int row = pos.dy.toInt();
    if (isFlipped) {
      col = 7 - col;
      row = 7 - row;
    }
    final colStr = String.fromCharCode('a'.codeUnitAt(0) + col);
    final rowStr = '${8 - row}';
    return '$colStr$rowStr';
  }

  @override
  bool shouldRepaint(covariant ChessBoardPainter oldDelegate) {
    return oldDelegate.fen != fen ||
        oldDelegate.lastMoveFrom != lastMoveFrom ||
        oldDelegate.lastMoveTo != lastMoveTo ||
        oldDelegate.isFlipped != isFlipped ||
        oldDelegate.animationProgress != animationProgress;
  }
}
