import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/game.dart' show FloatingText, BoardArrow;
import '../models/project.dart';
import '../models/render_job.dart';
import '../models/timeline.dart';
import '../services/timing_resolver.dart';
import '../utils/virtual_clock.dart';
import 'chess_board_2d.dart';
import 'terminal_text.dart';

class RenderEngineWidget extends StatelessWidget {
  final Project project;
  final RenderPreset preset;
  final VirtualClock clock;
  final List<ResolvedTiming> resolvedTimings;

  /// Whether to draw the analysis-log (annotation) overlay at all. This is
  /// decoupled from the board layout on purpose: by default the export is
  /// the board in isolation, with no space reserved for the log. When
  /// enabled, the log draws as an overlay on top of the board rather than
  /// pushing the board into a smaller centred region.
  final bool showAnalysisLog;

  const RenderEngineWidget({
    Key? key,
    required this.project,
    required this.preset,
    required this.clock,
    required this.resolvedTimings,
    this.showAnalysisLog = false,
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
    bool isCheck = false;
    double textRevealProgress = 1.0;
    List<FloatingText> currentFloatingTexts = [];
    List<BoardArrow> currentArrows = [];
    List<Layer> activeOverlays = [];

    for (int i = 0; i < project.game.plies.length; i++) {
      final ply = project.game.plies[i];
      final timing = i < resolvedTimings.length ? resolvedTimings[i] : ResolvedTiming(holdDurationMs: 2000, transitionDurationMs: 500, appliedRules: []);
      
      final plyTotalTime = timing.holdDurationMs + timing.transitionDurationMs;
      
      if (currentTimeMs >= accumulatedTimeMs && currentTimeMs < accumulatedTimeMs + plyTotalTime) {
        annotationText = ply.annotation ?? '';
        isFlagged = ply.isFlagged;
        isCheck = ply.isCheck;
        currentFloatingTexts = ply.floatingTexts;
        currentArrows = ply.arrows;
        
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
          textRevealProgress = 0.0;
        } else {
          // Holding
          fen = ply.resultingFen;
          lastMoveFrom = ply.fromSquare;
          lastMoveTo = ply.toSquare;
          
          final holdTime = timeInPly - timing.transitionDurationMs;
          final textLen = annotationText.length;
          if (textLen > 0) {
             final typeTimeMs = (textLen / 20.0) * 1000.0;
             textRevealProgress = holdTime / typeTimeMs;
             if (textRevealProgress > 1.0) textRevealProgress = 1.0;
             if (textRevealProgress < 0.0) textRevealProgress = 0.0;
          } else {
             textRevealProgress = 1.0;
          }
          // In holding phase, check applies. (Actually, check applies as soon as the move finishes, which is the hold phase).
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
        isCheck = ply.isCheck;
        currentFloatingTexts = ply.floatingTexts;
        currentArrows = ply.arrows;
      }
    }

    // Determine active media overlays
    for (var layer in project.timeline.layers) {
      if (layer.type == LayerType.overlay) {
         if (currentTimeMs >= layer.startTimeMs && 
             (layer.endTimeMs == null || currentTimeMs < layer.endTimeMs!)) {
            activeOverlays.add(layer);
         }
      }
    }

    // Canvas dimensions from the preset
    final double h = preset.height.toDouble();
    final double w = preset.width.toDouble();

    // The board must remain square — use the smaller of width/height so the
    // board fits entirely within the canvas without stretching.
    // It is then centred via Align so there are clean letterbox/pillarbox bars.
    final double boardSize = math.min(w, h);

    return SizedBox(
      width: w,
      height: h,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Board — square, centred in the canvas.
            Align(
              alignment: Alignment.center,
              child: ChessBoard2D(
                fen: fen,
                size: boardSize,
                lastMoveFrom: lastMoveFrom,
                lastMoveTo: lastMoveTo,
                animationProgress: plyAnimationProgress,
                animatingPiece: animatingPiece,
                animateFrom: animateFrom,
                animateTo: animateTo,
                isCheck: isCheck,
                arrows: currentArrows,
              ),
            ),
            // Analysis log — optional overlay, off by default. Drawn on
            // top of the board rather than reserving its own layout band.
            if (showAnalysisLog)
              Positioned(
                left: w * 0.06,
                right: w * 0.06,
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
                    revealProgress: textRevealProgress,
                    fontSize: h * 0.028,
                  ),
                ),
              ),
            // Floating Texts
            for (final text in currentFloatingTexts)
              Positioned(
                left: w * text.x,
                top: h * text.y,
                child: Text(
                  text.text,
                  style: TextStyle(
                    color: Color(int.parse(text.color.replaceFirst('#', '0xFF'))),
                    fontSize: text.fontSize * h,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            // Media Overlays
            for (final layer in activeOverlays)
              Positioned(
                left: w * (layer.x ?? 0.0),
                top: h * (layer.y ?? 0.0),
                width: w * (layer.width ?? 1.0),
                height: h * (layer.height ?? 1.0),
                child: Opacity(
                  opacity: layer.opacity,
                  child: Image.file(
                    File(layer.assetPath),
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => const Center(child: Icon(Icons.broken_image, color: Colors.red)),
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
