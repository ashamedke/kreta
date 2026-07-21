import 'dart:math';
import 'keyframe.dart';

class AnimatableProperty<T> {
  final List<Keyframe<T>> keyframes;
  final T defaultValue;

  AnimatableProperty({List<Keyframe<T>>? keyframes, required this.defaultValue}) 
    : keyframes = (keyframes != null && keyframes.isNotEmpty) 
        ? (List.from(keyframes)..sort((a, b) => a.timeMs.compareTo(b.timeMs)))
        : [Keyframe(timeMs: 0, value: defaultValue)];

  factory AnimatableProperty.constant(T value) {
    return AnimatableProperty(
      defaultValue: value,
      keyframes: [Keyframe(timeMs: 0, value: value)],
    );
  }

  T evaluate(double currentMs) {
    if (keyframes.isEmpty) return defaultValue;
    if (keyframes.length == 1) return keyframes.first.value;

    if (currentMs <= keyframes.first.timeMs) return keyframes.first.value;
    if (currentMs >= keyframes.last.timeMs) return keyframes.last.value;

    // Find bounding keyframes
    int idx = 0;
    while (idx < keyframes.length - 1 && keyframes[idx + 1].timeMs < currentMs) {
      idx++;
    }

    final k1 = keyframes[idx];
    final k2 = keyframes[idx + 1];

    final progress = (currentMs - k1.timeMs) / (k2.timeMs - k1.timeMs);
    final eased = _applyCurve(progress, k1.curve);

    return _lerp(k1.value, k2.value, eased);
  }

  double _applyCurve(double t, EasingCurve curve) {
    switch (curve) {
      case EasingCurve.linear:
        return t;
      case EasingCurve.easeIn:
        return t * t;
      case EasingCurve.easeOut:
        return t * (2 - t);
      case EasingCurve.easeInOut:
        return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
    }
  }

  T _lerp(T a, T b, double t) {
    if (a is double && b is double) {
      return (a + (b - a) * t) as T;
    }
    // For non-lerpable types (like int, Color, string), just step if t>=1
    return t >= 1.0 ? b : a;
  }

  List<dynamic> toJson() => keyframes.map((k) => k.toJson()).toList();

  void setKeyframe(double timeMs, T value, {EasingCurve curve = EasingCurve.linear}) {
    // If it's a constant property with 1 keyframe exactly at 0 and we are just modifying it
    if (keyframes.length == 1) {
      keyframes[0] = Keyframe(timeMs: keyframes[0].timeMs, value: value, curve: curve);
      return;
    }

    // Try to find a keyframe at the exact time
    for (int i = 0; i < keyframes.length; i++) {
      if ((keyframes[i].timeMs - timeMs).abs() < 1.0) {
        keyframes[i] = Keyframe(timeMs: timeMs, value: value, curve: curve);
        return;
      }
    }

    // Otherwise insert it and re-sort
    keyframes.add(Keyframe(timeMs: timeMs, value: value, curve: curve));
    keyframes.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  }
  static AnimatableProperty<T> fromJson<T>(dynamic json, T defaultValue) {
    if (json == null) return AnimatableProperty.constant(defaultValue);
    
    // Fallback migration: If it's just a raw value (e.g. static double from old save)
    if (json is num && defaultValue is double) {
      return AnimatableProperty.constant(json.toDouble() as T);
    }
    if (json is String && defaultValue is String) {
      return AnimatableProperty.constant(json as T);
    }
    
    // Proper JSON array of keyframes
    if (json is List) {
      final kfs = json.map((k) => Keyframe<T>.fromJson(k as Map<String, dynamic>)).toList();
      return AnimatableProperty(keyframes: kfs, defaultValue: defaultValue);
    }
    
    return AnimatableProperty.constant(defaultValue);
  }
}
