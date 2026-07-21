import 'package:uuid/uuid.dart';
import 'animatable_property.dart';

abstract class TimelineItem {
  final String id;
  final int startTimeMs;
  final int? endTimeMs;
  final int? sourcePlyIndex; // Used for syncing relative to a chess move

  const TimelineItem({
    required this.id,
    required this.startTimeMs,
    this.endTimeMs,
    this.sourcePlyIndex,
  });

  Map<String, dynamic> toJson();
  
  static TimelineItem fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'overlay':
        return OverlayItem.fromJson(json);
      case 'audio':
        return AudioItem.fromJson(json);
      case 'arrow':
        return ArrowItem.fromJson(json);
      case 'floatingText':
        return FloatingTextItem.fromJson(json);
      case 'chessMove':
        return ChessMoveItem.fromJson(json);
      default:
        throw Exception('Unknown TimelineItem type: $type');
    }
  }

  TimelineItem copyWith({
    String? id,
    int? startTimeMs,
    int? endTimeMs,
    int? sourcePlyIndex,
  });
}

class OverlayItem extends TimelineItem {
  final String assetPath;
  final AnimatableProperty<double> opacity;
  final AnimatableProperty<double?> x;
  final AnimatableProperty<double?> y;
  final AnimatableProperty<double?> width;
  final AnimatableProperty<double?> height;
  final bool loop;

  OverlayItem({
    String? id,
    required int startTimeMs,
    int? endTimeMs,
    int? sourcePlyIndex,
    required this.assetPath,
    AnimatableProperty<double>? opacity,
    AnimatableProperty<double?>? x,
    AnimatableProperty<double?>? y,
    AnimatableProperty<double?>? width,
    AnimatableProperty<double?>? height,
    this.loop = false,
  }) : opacity = opacity ?? AnimatableProperty.constant(1.0),
       x = x ?? AnimatableProperty.constant(null),
       y = y ?? AnimatableProperty.constant(null),
       width = width ?? AnimatableProperty.constant(null),
       height = height ?? AnimatableProperty.constant(null),
       super(
         id: id ?? const Uuid().v4(),
         startTimeMs: startTimeMs,
         endTimeMs: endTimeMs,
         sourcePlyIndex: sourcePlyIndex,
       );

  factory OverlayItem.fromJson(Map<String, dynamic> json) {
    return OverlayItem(
      id: json['id'],
      startTimeMs: json['startTimeMs'],
      endTimeMs: json['endTimeMs'],
      sourcePlyIndex: json['sourcePlyIndex'],
      assetPath: json['assetPath'],
      opacity: AnimatableProperty.fromJson(json['opacity'], 1.0),
      x: AnimatableProperty.fromJson<double?>(json['x'], null),
      y: AnimatableProperty.fromJson<double?>(json['y'], null),
      width: AnimatableProperty.fromJson<double?>(json['width'], null),
      height: AnimatableProperty.fromJson<double?>(json['height'], null),
      loop: json['loop'] ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'overlay',
        'id': id,
        'startTimeMs': startTimeMs,
        'endTimeMs': endTimeMs,
        'sourcePlyIndex': sourcePlyIndex,
        'assetPath': assetPath,
        'opacity': opacity.toJson(),
        'x': x.toJson(),
        'y': y.toJson(),
        'width': width.toJson(),
        'height': height.toJson(),
        'loop': loop,
      };

  @override
  OverlayItem copyWith({
    String? id,
    int? startTimeMs,
    int? endTimeMs,
    int? sourcePlyIndex,
    String? assetPath,
    AnimatableProperty<double>? opacity,
    AnimatableProperty<double?>? x,
    AnimatableProperty<double?>? y,
    AnimatableProperty<double?>? width,
    AnimatableProperty<double?>? height,
    bool? loop,
  }) {
    return OverlayItem(
      id: id ?? this.id,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      endTimeMs: endTimeMs ?? this.endTimeMs,
      sourcePlyIndex: sourcePlyIndex ?? this.sourcePlyIndex,
      assetPath: assetPath ?? this.assetPath,
      opacity: opacity ?? this.opacity,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      loop: loop ?? this.loop,
    );
  }
}

class AudioItem extends TimelineItem {
  final String assetPath;
  final double volume;

  AudioItem({
    String? id,
    required int startTimeMs,
    int? endTimeMs,
    int? sourcePlyIndex,
    required this.assetPath,
    this.volume = 1.0,
  }) : super(
         id: id ?? const Uuid().v4(),
         startTimeMs: startTimeMs,
         endTimeMs: endTimeMs,
         sourcePlyIndex: sourcePlyIndex,
       );

  factory AudioItem.fromJson(Map<String, dynamic> json) {
    return AudioItem(
      id: json['id'],
      startTimeMs: json['startTimeMs'],
      endTimeMs: json['endTimeMs'],
      sourcePlyIndex: json['sourcePlyIndex'],
      assetPath: json['assetPath'],
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'audio',
        'id': id,
        'startTimeMs': startTimeMs,
        'endTimeMs': endTimeMs,
        'sourcePlyIndex': sourcePlyIndex,
        'assetPath': assetPath,
        'volume': volume,
      };

  @override
  AudioItem copyWith({
    String? id,
    int? startTimeMs,
    int? endTimeMs,
    int? sourcePlyIndex,
    String? assetPath,
    double? volume,
  }) {
    return AudioItem(
      id: id ?? this.id,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      endTimeMs: endTimeMs ?? this.endTimeMs,
      sourcePlyIndex: sourcePlyIndex ?? this.sourcePlyIndex,
      assetPath: assetPath ?? this.assetPath,
      volume: volume ?? this.volume,
    );
  }
}

abstract class AnnotationItem extends TimelineItem {
  AnnotationItem({
    String? id,
    required int startTimeMs,
    int? endTimeMs,
    int? sourcePlyIndex,
  }) : super(
         id: id ?? const Uuid().v4(),
         startTimeMs: startTimeMs,
         endTimeMs: endTimeMs,
         sourcePlyIndex: sourcePlyIndex,
       );
}

class ArrowItem extends AnnotationItem {
  final String fromSquare;
  final String toSquare;
  final String color;
  final String? text;

  ArrowItem({
    String? id,
    required int startTimeMs,
    int? endTimeMs,
    int? sourcePlyIndex,
    required this.fromSquare,
    required this.toSquare,
    this.color = '#ff0000',
    this.text,
  }) : super(
         id: id,
         startTimeMs: startTimeMs,
         endTimeMs: endTimeMs,
         sourcePlyIndex: sourcePlyIndex,
       );

  factory ArrowItem.fromJson(Map<String, dynamic> json) {
    return ArrowItem(
      id: json['id'],
      startTimeMs: json['startTimeMs'],
      endTimeMs: json['endTimeMs'],
      sourcePlyIndex: json['sourcePlyIndex'],
      fromSquare: json['fromSquare'],
      toSquare: json['toSquare'],
      color: json['color'] ?? '#ff0000',
      text: json['text'],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'arrow',
        'id': id,
        'startTimeMs': startTimeMs,
        'endTimeMs': endTimeMs,
        'sourcePlyIndex': sourcePlyIndex,
        'fromSquare': fromSquare,
        'toSquare': toSquare,
        'color': color,
        'text': text,
      };

  @override
  ArrowItem copyWith({
    String? id,
    int? startTimeMs,
    int? endTimeMs,
    int? sourcePlyIndex,
    String? fromSquare,
    String? toSquare,
    String? color,
    String? text,
  }) {
    return ArrowItem(
      id: id ?? this.id,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      endTimeMs: endTimeMs ?? this.endTimeMs,
      sourcePlyIndex: sourcePlyIndex ?? this.sourcePlyIndex,
      fromSquare: fromSquare ?? this.fromSquare,
      toSquare: toSquare ?? this.toSquare,
      color: color ?? this.color,
      text: text ?? this.text,
    );
  }
}

class FloatingTextItem extends AnnotationItem {
  final String text;
  final AnimatableProperty<double> x;
  final AnimatableProperty<double> y;
  final String color;
  final double fontSize;

  FloatingTextItem({
    String? id,
    required int startTimeMs,
    int? endTimeMs,
    int? sourcePlyIndex,
    required this.text,
    AnimatableProperty<double>? x,
    AnimatableProperty<double>? y,
    this.color = '#ffffff',
    this.fontSize = 24.0,
  }) : x = x ?? AnimatableProperty.constant(0.5),
       y = y ?? AnimatableProperty.constant(0.5),
       super(
         id: id,
         startTimeMs: startTimeMs,
         endTimeMs: endTimeMs,
         sourcePlyIndex: sourcePlyIndex,
       );

  factory FloatingTextItem.fromJson(Map<String, dynamic> json) {
    return FloatingTextItem(
      id: json['id'],
      startTimeMs: json['startTimeMs'],
      endTimeMs: json['endTimeMs'],
      sourcePlyIndex: json['sourcePlyIndex'],
      text: json['text'],
      x: AnimatableProperty.fromJson(json['x'], 0.5),
      y: AnimatableProperty.fromJson(json['y'], 0.5),
      color: json['color'] ?? '#ffffff',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 24.0,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'floatingText',
        'id': id,
        'startTimeMs': startTimeMs,
        'endTimeMs': endTimeMs,
        'sourcePlyIndex': sourcePlyIndex,
        'text': text,
        'x': x.toJson(),
        'y': y.toJson(),
        'color': color,
        'fontSize': fontSize,
      };

  @override
  FloatingTextItem copyWith({
    String? id,
    int? startTimeMs,
    int? endTimeMs,
    int? sourcePlyIndex,
    String? text,
    AnimatableProperty<double>? x,
    AnimatableProperty<double>? y,
    String? color,
    double? fontSize,
  }) {
    return FloatingTextItem(
      id: id ?? this.id,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      endTimeMs: endTimeMs ?? this.endTimeMs,
      sourcePlyIndex: sourcePlyIndex ?? this.sourcePlyIndex,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

class ChessMoveItem extends TimelineItem {
  final int plyIndex;

  ChessMoveItem({
    String? id,
    required int startTimeMs,
    int? endTimeMs,
    required this.plyIndex,
  }) : super(
         id: id ?? const Uuid().v4(),
         startTimeMs: startTimeMs,
         endTimeMs: endTimeMs,
         sourcePlyIndex: plyIndex,
       );

  factory ChessMoveItem.fromJson(Map<String, dynamic> json) {
    return ChessMoveItem(
      id: json['id'],
      startTimeMs: json['startTimeMs'],
      endTimeMs: json['endTimeMs'],
      plyIndex: json['plyIndex'],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'chessMove',
        'id': id,
        'startTimeMs': startTimeMs,
        'endTimeMs': endTimeMs,
        'plyIndex': plyIndex,
        'sourcePlyIndex': plyIndex,
      };

  @override
  ChessMoveItem copyWith({
    String? id,
    int? startTimeMs,
    int? endTimeMs,
    int? sourcePlyIndex,
    int? plyIndex,
  }) {
    return ChessMoveItem(
      id: id ?? this.id,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      endTimeMs: endTimeMs ?? this.endTimeMs,
      plyIndex: plyIndex ?? this.plyIndex,
    );
  }
}
