import 'timing.dart';

enum LayerType { backgroundVideo, backgroundImage, musicTrack, sfxCue, overlay }

/// A timeline layer for video/audio overlays.
class Layer {
  final String id;
  final LayerType type;
  final String assetPath;
  final String? sourceTag;
  final int startTimeMs;
  final int? endTimeMs;
  final double opacity;
  final double volume;
  final bool loop;
  final double? x;
  final double? y;
  final double? width;
  final double? height;

  const Layer({
    required this.id,
    required this.type,
    required this.assetPath,
    this.sourceTag,
    required this.startTimeMs,
    this.endTimeMs,
    this.opacity = 1.0,
    this.volume = 1.0,
    this.loop = false,
    this.x,
    this.y,
    this.width,
    this.height,
  });

  factory Layer.fromJson(Map<String, dynamic> json) {
    return Layer(
      id: json['id'] as String,
      type: LayerType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LayerType.overlay,
      ),
      assetPath: json['assetPath'] as String,
      sourceTag: json['sourceTag'] as String?,
      startTimeMs: json['startTimeMs'] as int,
      endTimeMs: json['endTimeMs'] as int?,
      opacity: (json['opacity'] as num? ?? 1.0).toDouble(),
      volume: (json['volume'] as num? ?? 1.0).toDouble(),
      loop: json['loop'] as bool? ?? false,
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
      width: (json['width'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'assetPath': assetPath,
      'sourceTag': sourceTag,
      'startTimeMs': startTimeMs,
      'endTimeMs': endTimeMs,
      'opacity': opacity,
      'volume': volume,
      'loop': loop,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  Layer copyWith({
    String? id,
    LayerType? type,
    String? assetPath,
    String? sourceTag,
    int? startTimeMs,
    int? endTimeMs,
    double? opacity,
    double? volume,
    bool? loop,
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return Layer(
      id: id ?? this.id,
      type: type ?? this.type,
      assetPath: assetPath ?? this.assetPath,
      sourceTag: sourceTag ?? this.sourceTag,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      endTimeMs: endTimeMs ?? this.endTimeMs,
      opacity: opacity ?? this.opacity,
      volume: volume ?? this.volume,
      loop: loop ?? this.loop,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

/// The timeline structure for a video.
class Timeline {
  final String gameId;
  final List<Layer> layers;
  final TimingRules timingRules;
  final int? introMs;
  final int? outroMs;

  const Timeline({
    required this.gameId,
    required this.layers,
    required this.timingRules,
    this.introMs,
    this.outroMs,
  });

  factory Timeline.fromJson(Map<String, dynamic> json) {
    return Timeline(
      gameId: json['gameId'] as String,
      layers: (json['layers'] as List? ?? [])
          .map((e) => Layer.fromJson(e as Map<String, dynamic>))
          .toList(),
      timingRules: json['timingRules'] != null
          ? TimingRules.fromJson(json['timingRules'] as Map<String, dynamic>)
          : const TimingRules(rules: []),
      introMs: json['introMs'] as int?,
      outroMs: json['outroMs'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'layers': layers.map((l) => l.toJson()).toList(),
      'timingRules': timingRules.toJson(),
      'introMs': introMs,
      'outroMs': outroMs,
    };
  }

  Timeline copyWith({
    String? gameId,
    List<Layer>? layers,
    TimingRules? timingRules,
    int? introMs,
    int? outroMs,
  }) {
    return Timeline(
      gameId: gameId ?? this.gameId,
      layers: layers ?? this.layers,
      timingRules: timingRules ?? this.timingRules,
      introMs: introMs ?? this.introMs,
      outroMs: outroMs ?? this.outroMs,
    );
  }
}
