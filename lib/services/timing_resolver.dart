import 'package:chesscreator/models/game.dart';
import 'package:chesscreator/models/timing.dart';
import 'package:chesscreator/models/timeline.dart';

/// Represents the resolved timing duration for a single ply.
class ResolvedTiming {
  final int holdDurationMs;
  final int transitionDurationMs;
  final List<String> appliedRules;

  ResolvedTiming({
    required this.holdDurationMs,
    required this.transitionDurationMs,
    required this.appliedRules,
  });
}

/// Engine to evaluate TimingRules and assign durations to plies.
class TimingResolver {
  /// Resolves the timing for a single ply given the rules.
  ResolvedTiming resolveTiming(Ply ply, TimingRules rules) {

    // Evaluate dynamic rules in order
    for (final rule in rules.rules) {
      if (_evaluatePredicate(rule.predicate, rule.predicateParams, ply)) {
        return ResolvedTiming(
          holdDurationMs: rule.holdDurationMs ?? rules.globalDefaultHoldMs,
          transitionDurationMs: rule.transitionDurationMs ?? rules.globalDefaultTransitionMs,
          appliedRules: [rule.id],
        );
      }
    }

    // Global defaults
    return ResolvedTiming(
      holdDurationMs: rules.globalDefaultHoldMs,
      transitionDurationMs: rules.globalDefaultTransitionMs,
      appliedRules: ['GlobalDefault'],
    );
  }

  /// Resolves timings for all plies.
  List<ResolvedTiming> resolveAllTimings(List<Ply> plies, TimingRules rules) {
    return plies.map((ply) => resolveTiming(ply, rules)).toList();
  }

  /// Calculates the total duration for the entire sequence.
  int calculateTotalDuration(List<Ply> plies, TimingRules rules, {int introMs = 0, int outroMs = 0}) {
    int totalMs = introMs + outroMs;
    for (final ply in plies) {
      final timing = resolveTiming(ply, rules);
      totalMs += timing.holdDurationMs + timing.transitionDurationMs;
    }
    return totalMs;
  }

  /// Evaluates a specific predicate for a ply.
  bool _evaluatePredicate(TimingRulePredicate predicate, Map<String, dynamic>? params, Ply ply) {
    switch (predicate) {
      case TimingRulePredicate.isCapture:
        return ply.capturedPiece != null;
      case TimingRulePredicate.isCheck:
        return ply.isCheck;
      case TimingRulePredicate.isCheckmate:
        return ply.isCheckmate;
      case TimingRulePredicate.isCastle:
        return ply.isCastle;
      case TimingRulePredicate.isPromotion:
        return ply.isPromotion;
      case TimingRulePredicate.always:
        if (params == null || !params.containsKey('piece')) return false;
        return ply.pieceMoved?.toLowerCase() == (params['piece'] as String).toLowerCase();
      case TimingRulePredicate.plyIndexRange:
        if (params == null) return false;
        final minIndex = params['min'] as int?;
        final maxIndex = params['max'] as int?;
        if (minIndex != null && ply.index < minIndex) return false;
        if (maxIndex != null && ply.index > maxIndex) return false;
        return true;
      default:
        return false;
    }
  }

  /// Synchronizes the Game's plies with the Timeline's tracks.
  Timeline syncTimelineWithGame(Timeline timeline, Game game) {
    int introMs = timeline.introMs ?? 0;
    int currentMs = introMs;
    
    List<ChessMoveItem> newItems = [];
    final resolvedTimings = resolveAllTimings(game.plies, timeline.timingRules);
    
    for (int i = 0; i < game.plies.length; i++) {
      final ply = game.plies[i];
      final timing = resolvedTimings[i];
      
      final duration = timing.holdDurationMs + timing.transitionDurationMs;
      
      // Preserve existing ID if present
      String? existingId;
      try {
        final videoTrack = timeline.tracks.firstWhere((t) => t.type == TrackType.video);
        final existingItem = videoTrack.items.whereType<ChessMoveItem>().firstWhere((item) => item.plyIndex == ply.index);
        existingId = existingItem.id;
      } catch (e) {
        // Not found, will generate new UUID
      }

      newItems.add(ChessMoveItem(
        id: existingId,
        startTimeMs: currentMs,
        endTimeMs: currentMs + duration,
        plyIndex: ply.index,
      ));
      
      currentMs += duration;
    }
    
    Track videoTrack;
    try {
      videoTrack = timeline.tracks.firstWhere((t) => t.type == TrackType.video);
    } catch (_) {
      videoTrack = Track(name: 'Video', type: TrackType.video);
    }

    final newVideoTrack = videoTrack.copyWith(items: newItems);
    
    final newTracks = timeline.tracks.where((t) => t.type != TrackType.video).toList();
    newTracks.insert(0, newVideoTrack);
    
    // Ripple edit AnnotationItems based on sourcePlyIndex
    final List<Track> updatedTracks = [];
    for (final track in newTracks) {
      if (track.type == TrackType.annotation) {
        final updatedItems = track.items.map((item) {
          if (item is AnnotationItem && item.sourcePlyIndex != null) {
            try {
              final sourceMove = newItems.firstWhere((move) => move.plyIndex == item.sourcePlyIndex);
              final duration = item.endTimeMs != null ? (item.endTimeMs! - item.startTimeMs) : null;
              if (item is ArrowItem) {
                return item.copyWith(
                  startTimeMs: sourceMove.startTimeMs, 
                  endTimeMs: duration != null ? sourceMove.startTimeMs + duration : null
                );
              } else if (item is FloatingTextItem) {
                return item.copyWith(
                  startTimeMs: sourceMove.startTimeMs, 
                  endTimeMs: duration != null ? sourceMove.startTimeMs + duration : null
                );
              }
            } catch (_) {
              // source move not found, keep as is
            }
          }
          return item;
        }).toList();
        updatedTracks.add(track.copyWith(items: updatedItems));
      } else {
        updatedTracks.add(track);
      }
    }
    
    return timeline.copyWith(tracks: updatedTracks);
  }
}
