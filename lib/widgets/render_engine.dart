import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/render_job.dart';
import '../services/timing_resolver.dart';
import '../utils/virtual_clock.dart';
import 'chess_board_2d.dart';
import 'chess_board_3d.dart';
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
          animatingPiece = ply.pieceMoved;
          animateFrom = ply.fromSquare;
          animateTo = ply.toSquare;
          
          if (i > 0) {
            final prevPly = project.game.plies[i - 1];
            fen = prevPly.resultingFen; // Start from previous fen
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
    return SizedBox(
      width: preset.width.toDouble(),
      height: preset.height.toDouble(),
      child: Container(
        color: Colors.transparent, // Transparent background for FFmpeg composite
        child: Stack(
          children: [
            if (project.layoutType == LayoutType.splitScreen)
              Padding(
                padding: EdgeInsets.all(preset.width * 0.05), // 5% padding
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left side: 3D Board
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ChessBoard3D(
                          fen: fen,
                          size: preset.height * 0.8,
                          lastMoveFrom: lastMoveFrom,
                          lastMoveTo: lastMoveTo,
                          animationProgress: plyAnimationProgress,
                          animatingPiece: animatingPiece,
                          animateFrom: animateFrom,
                          animateTo: animateTo,
                          isFlagged: isFlagged,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: preset.width * 0.05),
                  // Right side: 2D Board + Terminal
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: ChessBoard2D(
                                fen: fen,
                                size: preset.height * 0.5,
                                lastMoveFrom: lastMoveFrom,
                                lastMoveTo: lastMoveTo,
                                animationProgress: plyAnimationProgress,
                                animatingPiece: animatingPiece,
                                animateFrom: animateFrom,
                                animateTo: animateTo,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: preset.height * 0.05),
                        Expanded(
                          flex: 1,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(preset.width * 0.02),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161B22),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF30363D), width: 4),
                            ),
                            child: TerminalText(
                              fullText: annotationText.isEmpty ? "No annotation for this move." : annotationText,
                              revealProgress: 1.0, // Fully revealed for MVP offline render logic
                              fontSize: preset.height * 0.03,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
              // Picture-in-Picture Layout
              Stack(
                children: [
                  Positioned.fill(
                    child: Center(
                      child: ChessBoard3D(
                        fen: fen,
                        size: preset.height * 0.9,
                        lastMoveFrom: lastMoveFrom,
                        lastMoveTo: lastMoveTo,
                        animationProgress: plyAnimationProgress,
                        animatingPiece: animatingPiece,
                        animateFrom: animateFrom,
                        animateTo: animateTo,
                        isFlagged: isFlagged,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: preset.height * 0.05,
                    right: preset.width * 0.05,
                    width: preset.width * 0.3,
                    height: preset.height * 0.7,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF161B22),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF30363D), width: 4),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: ChessBoard2D(
                                  fen: fen,
                                  size: preset.width * 0.25,
                                  lastMoveFrom: lastMoveFrom,
                                  lastMoveTo: lastMoveTo,
                                  animationProgress: plyAnimationProgress,
                                  animatingPiece: animatingPiece,
                                  animateFrom: animateFrom,
                                  animateTo: animateTo,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: preset.height * 0.02),
                        Expanded(
                          flex: 1,
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(preset.width * 0.01),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161B22),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF30363D), width: 4),
                            ),
                            child: TerminalText(
                              fullText: annotationText.isEmpty ? "No annotation for this move." : annotationText,
                              revealProgress: 1.0,
                              fontSize: preset.height * 0.02,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            // Vignette overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.8,
                      colors: [
                        Colors.transparent,
                        Color(0xB3000000), // ~70% black opacity
                      ],
                      stops: [0.7, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
