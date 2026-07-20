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
    };
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
