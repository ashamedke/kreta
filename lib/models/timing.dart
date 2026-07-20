enum TimingRulePredicate {
  isCapture,
  isCheck,
  isCheckmate,
  isCastle,
  isPromotion,
  plyIndexRange,
  everyNthPly,
  isFlagged,
  isOpeningMoves,
  always,
}

enum TimingRuleEffect { replace, add, multiply }

/// Represents a single rule for determining timing in the video based on move properties.
class TimingRule {
  final String id;
  final TimingRulePredicate predicate;
  final Map<String, dynamic>? predicateParams;
  final TimingRuleEffect effect;
  final int? holdDurationMs;
  final int? transitionDurationMs;
  final bool enabled;

  const TimingRule({
    required this.id,
    required this.predicate,
    this.predicateParams,
    required this.effect,
    this.holdDurationMs,
    this.transitionDurationMs,
    this.enabled = true,
  });

  factory TimingRule.fromJson(Map<String, dynamic> json) {
    return TimingRule(
      id: json['id'] as String,
      predicate: TimingRulePredicate.values.firstWhere(
        (e) => e.name == json['predicate'],
        orElse: () => TimingRulePredicate.always,
      ),
      predicateParams: json['predicateParams'] as Map<String, dynamic>?,
      effect: TimingRuleEffect.values.firstWhere(
        (e) => e.name == json['effect'],
        orElse: () => TimingRuleEffect.replace,
      ),
      holdDurationMs: json['holdDurationMs'] as int?,
      transitionDurationMs: json['transitionDurationMs'] as int?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'predicate': predicate.name,
      'predicateParams': predicateParams,
      'effect': effect.name,
      'holdDurationMs': holdDurationMs,
      'transitionDurationMs': transitionDurationMs,
      'enabled': enabled,
    };
  }
}

/// A collection of timing rules and global defaults.
class TimingRules {
  final int globalDefaultHoldMs;
  final int globalDefaultTransitionMs;
  final List<TimingRule> rules;

  const TimingRules({
    this.globalDefaultHoldMs = 2000,
    this.globalDefaultTransitionMs = 500,
    required this.rules,
  });

  factory TimingRules.fromJson(Map<String, dynamic> json) {
    return TimingRules(
      globalDefaultHoldMs: json['globalDefaultHoldMs'] as int? ?? 2000,
      globalDefaultTransitionMs: json['globalDefaultTransitionMs'] as int? ?? 500,
      rules: (json['rules'] as List? ?? [])
          .map((e) => TimingRule.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'globalDefaultHoldMs': globalDefaultHoldMs,
      'globalDefaultTransitionMs': globalDefaultTransitionMs,
      'rules': rules.map((r) => r.toJson()).toList(),
    };
  }

  TimingRules copyWith({
    int? globalDefaultHoldMs,
    int? globalDefaultTransitionMs,
    List<TimingRule>? rules,
  }) {
    return TimingRules(
      globalDefaultHoldMs: globalDefaultHoldMs ?? this.globalDefaultHoldMs,
      globalDefaultTransitionMs: globalDefaultTransitionMs ?? this.globalDefaultTransitionMs,
      rules: rules ?? this.rules,
    );
  }
}
