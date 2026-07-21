import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';

class ChessBoard3D extends StatefulWidget {
  final String fen;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final bool isFlipped;

  /// Width of the widget. As with ChessBoard2D, omitting [height] keeps
  /// this square (the original behavior).
  final double size;

  /// Optional explicit height for a non-square viewport (e.g. a full
  /// 1920x1080 export canvas). `Cube`'s perspective projection is set up
  /// from the widget's own render-box size each frame, so an unequal
  /// width/height here should produce a correctly-proportioned (not
  /// stretched) 3D view that simply fills a wider or taller viewport —
  /// unlike the 2D board, there's no source-image stretching concern.
  /// That said, this hasn't been visually verified against the actual
  /// `flutter_cube` behavior — check the export before shipping it.
  final double? height;

  final double? animationProgress;
  final String? animatingPiece;
  final String? animateFrom;
  final String? animateTo;
  final bool isFlagged;

  const ChessBoard3D({
    Key? key,
    required this.fen,
    this.lastMoveFrom,
    this.lastMoveTo,
    this.isFlipped = false,
    required this.size,
    this.height,
    this.animationProgress,
    this.animatingPiece,
    this.animateFrom,
    this.animateTo,
    this.isFlagged = false,
  }) : super(key: key);

  @override
  State<ChessBoard3D> createState() => _ChessBoard3DState();
}

class _ChessBoard3DState extends State<ChessBoard3D> {
  Scene? _scene;
  final List<Object> _pieceObjects = [];

  void _onSceneCreated(Scene scene) {
    _scene = scene;
    scene.camera.position.z = 10;
    scene.camera.position.y = 5;
    scene.camera.target.y = 0;
    scene.camera.zoom = 5;
    
    // Add light
    scene.light.position.setValues(0, 10, 10);
    scene.light.setColor(Colors.white, 1.0, 1.0, 1.0);

    // Add board
    final board = Object(fileName: 'assets/models/board.obj', position: Vector3(0, 0, 0));
    scene.world.add(board);
    
    _updatePieces();
  }

  @override
  void didUpdateWidget(ChessBoard3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_scene != null) {
      bool shouldUpdateCamera = false;
      if (oldWidget.isFlagged != widget.isFlagged) {
        if (widget.isFlagged) {
          _scene!.camera.zoom = 8;
          _scene!.camera.position.z = 8;
          _scene!.camera.position.y = 3;
        } else {
          _scene!.camera.zoom = 5;
          _scene!.camera.position.z = 10;
          _scene!.camera.position.y = 5;
        }
        shouldUpdateCamera = true;
      }
      
      if (oldWidget.fen != widget.fen || 
          oldWidget.animationProgress != widget.animationProgress || 
          oldWidget.isFlipped != widget.isFlipped) {
        _updatePieces();
      } else if (shouldUpdateCamera) {
        _scene!.update();
      }
    }
  }

  void _updatePieces() {
    if (_scene == null) return;
    
    // Remove old pieces
    for (var obj in _pieceObjects) {
      _scene!.world.remove(obj);
    }
    _pieceObjects.clear();

    final rows = widget.fen.split(' ')[0].split('/');
    for (int row = 0; row < 8; row++) {
      int col = 0;
      for (int i = 0; i < rows[row].length; i++) {
        final char = rows[row][i];
        if (RegExp(r'[1-8]').hasMatch(char)) {
          col += int.parse(char);
        } else {
          final square = _colRowToSquare(col, row);
          
          bool shouldDrawStatic = true;
          if (widget.animatingPiece != null && widget.animateFrom == square && widget.animationProgress != null) {
            shouldDrawStatic = false;
          }

          if (shouldDrawStatic) {
            _addPieceObj(char, col.toDouble(), row.toDouble());
          }
          col++;
        }
      }
    }

    // Add animating piece
    if (widget.animatingPiece != null && widget.animateFrom != null && widget.animateTo != null && widget.animationProgress != null) {
      final fromCoord = _squareToColRow(widget.animateFrom!);
      final toCoord = _squareToColRow(widget.animateTo!);
      
      final currentCol = fromCoord[0] + (toCoord[0] - fromCoord[0]) * widget.animationProgress!;
      final currentRow = fromCoord[1] + (toCoord[1] - fromCoord[1]) * widget.animationProgress!;
      
      _addPieceObj(widget.animatingPiece!, currentCol, currentRow);
    }
    
    // Re-render
    _scene!.update();
  }
  
  void _addPieceObj(String pieceChar, double col, double row) {
    // Coordinate mapping: 
    // Chess board is 8x8. We made the board.obj from -4 to 4, so each square is 1x1.
    // Top-left (a8) col=0, row=0 -> x=-3.5, z=-3.5
    double x = (col - 3.5);
    double z = (row - 3.5);
    
    if (widget.isFlipped) {
      x = -x;
      z = -z;
    }
    
    final isWhite = pieceChar.toUpperCase() == pieceChar;
    final lowerChar = pieceChar.toLowerCase();
    
    String pieceName = 'pawn';
    if (lowerChar == 'p') pieceName = 'pawn';
    else if (lowerChar == 'n') pieceName = 'knight';
    else if (lowerChar == 'b') pieceName = 'bishop';
    else if (lowerChar == 'r') pieceName = 'rook';
    else if (lowerChar == 'q') pieceName = 'queen';
    else if (lowerChar == 'k') pieceName = 'king';

    final colorPrefix = isWhite ? 'white' : 'black';
    final fileName = 'assets/models/${colorPrefix}_$pieceName.obj';

    final piece = Object(
      fileName: fileName,
      position: Vector3(x, 0.0, z),
      scale: Vector3(1.0, 1.0, 1.0),
    );
    
    _scene!.world.add(piece);
    _pieceObjects.add(piece);
  }

  String _colRowToSquare(int col, int row) {
    final colStr = String.fromCharCode('a'.codeUnitAt(0) + col);
    final rowStr = '${8 - row}';
    return '$colStr$rowStr';
  }
  
  List<double> _squareToColRow(String square) {
    final col = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final row = 8 - int.parse(square[1]);
    return [col.toDouble(), row.toDouble()];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.height ?? widget.size,
      child: Cube(
        onSceneCreated: _onSceneCreated,
      ),
    );
  }
}
