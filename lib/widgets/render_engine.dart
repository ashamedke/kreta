import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/render_job.dart';
import '../services/timing_resolver.dart';
import '../utils/virtual_clock.dart';
import 'chess_board_2d.dart';
import 'terminal_text.dart';

class RenderEngineWidget extends StatelessWidget {
  final Project project;
  final RenderPreset preset;
  final VirtualClock clock;
  final List<ResolvedTiming> resolvedTimings;

  const RenderEngineWidget({
    Key? key,
    required this.project,
    required this.preset,
    required this.clock,
    required this.resolvedTimings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine the current state based on the virtual clock
    final double currentTimeMs = clock.currentTimeMs;
    
    // Find the current ply index and how far into it we are
    double accumulatedTimeMs = 0;
    
    double? plyAnimationProgress;
    String fen = project.game.startingFen;
    String? lastMoveFrom;
    String? lastMoveTo;
    String? animatingPiece;
    String? animateFrom;
    String? animateTo;
    String annotationText = '';
    bool isFlagged = false;

    for (int i = 0; i < project.game.plies.length; i++) {
      final ply = project.game.plies[i];
      final timing = i < resolvedTimings.length ? resolvedTimings[i] : ResolvedTiming(holdDurationMs: 2000, transitionDurationMs: 500, appliedRules: []);
      
      final plyTotalTime = timing.holdDurationMs + timing.transitionDurationMs;
      
      if (currentTimeMs >= accumulatedTimeMs && currentTimeMs < accumulatedTimeMs + plyTotalTime) {
        annotationText = ply.annotation ?? '';
        isFlagged = ply.isFlagged;
        
        final timeInPly = currentTimeMs - accumulatedTimeMs;
        
        // Is it transitioning?
        if (timeInPly < timing.transitionDurationMs && timing.transitionDurationMs > 0) {
          plyAnimationProgress = timeInPly / timing.transitionDurationMs;
          animateFrom = ply.fromSquare;
          animateTo = ply.toSquare;
          
          // Derive FEN character (upper=white, lower=black) from the pre-move position
          final String preFen = i > 0 ? project.game.plies[i - 1].resultingFen : project.game.startingFen;
          if (animateFrom != null) {
            animatingPiece = _fenCharAtSquare(preFen, animateFrom!);
          }
          
          if (i > 0) {
            final prevPly = project.game.plies[i - 1];
            fen = prevPly.resultingFen;
            lastMoveFrom = prevPly.fromSquare;
            lastMoveTo = prevPly.toSquare;
          }
        } else {
          // Holding
          fen = ply.resultingFen;
          lastMoveFrom = ply.fromSquare;
          lastMoveTo = ply.toSquare;
        }
        break;
      }
      
      accumulatedTimeMs += plyTotalTime;
      if (i == project.game.plies.length - 1 && currentTimeMs >= accumulatedTimeMs) {
        // We are past the end of the game
        fen = ply.resultingFen;
        lastMoveFrom = ply.fromSquare;
        lastMoveTo = ply.toSquare;
        annotationText = ply.annotation ?? '';
        isFlagged = ply.isFlagged;
      }
    }

    // Wrap in a fixed size box matching the preset resolution
    // Layout: board fills ~75% of height centred, annotation bar below it
    final double h = preset.height.toDouble();
    final double w = preset.width.toDouble();
    final double boardSize = h * 0.82;
    final double sidePad = (w - boardSize) / 2;

    return SizedBox(
      width: w,
      height: h,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Board — centred
            Positioned(
              left: sidePad,
              top: (h - boardSize) / 2 - h * 0.05,
              width: boardSize,
              height: boardSize,
              child: ChessBoard2D(
                fen: fen,
                size: boardSize,
                lastMoveFrom: lastMoveFrom,
                lastMoveTo: lastMoveTo,
                animationProgress: plyAnimationProgress,
                animatingPiece: animatingPiece,
                animateFrom: animateFrom,
                animateTo: animateTo,
              ),
            ),
            // Annotation bar at bottom
            Positioned(
              left: sidePad,
              right: sidePad,
              bottom: h * 0.04,
              height: h * 0.12,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: w * 0.02, vertical: h * 0.01),
                decoration: BoxDecoration(
                  color: const Color(0xDD161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D), width: 2),
                ),
                child: TerminalText(
                  fullText: annotationText.isEmpty ? '' : annotationText,
                  revealProgress: 1.0,
                  fontSize: h * 0.028,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Extract the FEN character (uppercase=white, lowercase=black) at [square] from [fen].
  String? _fenCharAtSquare(String fen, String square) {
    final col = square.codeUnitAt(0) - 97; // a=0
    final row = 8 - int.parse(square[1]);   // rank 8 = row 0
    final fenRows = fen.split(' ')[0].split('/');
    if (row < 0 || row >= 8) return null;
    int c = 0;
    for (final ch in fenRows[row].split('')) {
      if (RegExp(r'[1-8]').hasMatch(ch)) {
        c += int.parse(ch);
      } else {
        if (c == col) return ch;
        c++;
      }
    }
    return null;
  }
}
