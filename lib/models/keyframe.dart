import 'dart:math';

enum EasingCurve {
  linear,
  easeIn,
  easeOut,
  easeInOut
}

EasingCurve _curveFromString(String val) {
  return EasingCurve.values.firstWhere((e) => e.name == val, orElse: () => EasingCurve.linear);
}

class Keyframe<T> {
  final double timeMs;
  final T value;
  final EasingCurve curve;

  const Keyframe({
    required this.timeMs,
    required this.value,
    this.curve = EasingCurve.linear,
  });

  Map<String, dynamic> toJson() => {
    'timeMs': timeMs,
    'value': value,
    'curve': curve.name,
  };

  factory Keyframe.fromJson(Map<String, dynamic> json) {
    return Keyframe(
      timeMs: (json['timeMs'] as num).toDouble(),
      value: json['value'] as T,
      curve: _curveFromString(json['curve'] as String? ?? 'linear'),
    );
  }
}
