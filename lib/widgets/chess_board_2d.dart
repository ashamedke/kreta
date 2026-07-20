import 'package:flutter/material.dart';
import '../utils/constants.dart';

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
    final symbol = PieceSymbols.getSymbol(pieceChar);
    final isWhite = PieceSymbols.isWhite(pieceChar);

    final textStyle = TextStyle(
      fontSize: squareSize * 0.8,
      color: isWhite ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A2E),
      shadows: isWhite
          ? [const Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 2)]
          : null,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: symbol, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final xOffset = col * squareSize + (squareSize - textPainter.width) / 2;
    final yOffset = row * squareSize + (squareSize - textPainter.height) / 2;
    
    if (!isWhite) {
      // Outline for black pieces
      final outlineStyle = textStyle.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white54,
        shadows: [],
      );
      final outlinePainter = TextPainter(
        text: TextSpan(text: symbol, style: outlineStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      outlinePainter.paint(canvas, Offset(xOffset, yOffset));
    }

    textPainter.paint(canvas, Offset(xOffset, yOffset));
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
