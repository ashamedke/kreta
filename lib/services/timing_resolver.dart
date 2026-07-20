import 'package:chesscreator/models/game.dart';
import 'package:chesscreator/models/timing.dart';

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
}
