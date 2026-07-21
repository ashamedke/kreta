import 'package:uuid/uuid.dart';
import 'game.dart';
import 'timeline.dart';
import 'timing.dart';

enum LayoutType { splitScreen, pictureInPicture }

/// Represents a ChessCreator project.
class Project {
  final String id;
  final String name;
  final Game game;
  final Timeline timeline;
  final LayoutType layoutType;
  final String? outputPath;
  final String? backgroundVideoPath;
  final String? backgroundMusicPath;
  final String? localModelsPath;
  final double localModelsScale;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    String? id,
    required this.name,
    required this.game,
    required this.timeline,
    this.layoutType = LayoutType.splitScreen,
    this.outputPath,
    this.backgroundVideoPath,
    this.backgroundMusicPath,
    this.localModelsPath,
    this.localModelsScale = 1.0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Creates a new project with defaults initialized.
  factory Project.create(String name, Game game) {
    final timeline = Timeline(
      gameId: game.id,
      tracks: const [],
      timingRules: const TimingRules(rules: []),
    );
    return Project(
      name: name,
      game: game,
      timeline: timeline,
    );
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String?,
      name: json['name'] as String,
      game: Game.fromJson(json['game'] as Map<String, dynamic>),
      timeline: Timeline.fromJson(json['timeline'] as Map<String, dynamic>),
      layoutType: LayoutType.values.firstWhere(
        (e) => e.name == json['layoutType'],
        orElse: () => LayoutType.splitScreen,
      ),
      outputPath: json['outputPath'] as String?,
      backgroundVideoPath: json['backgroundVideoPath'] as String?,
      backgroundMusicPath: json['backgroundMusicPath'] as String?,
      localModelsPath: json['localModelsPath'] as String?,
      localModelsScale: (json['localModelsScale'] as num?)?.toDouble() ?? 1.0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'game': game.toJson(),
      'timeline': timeline.toJson(),
      'layoutType': layoutType.name,
      'outputPath': outputPath,
      'backgroundVideoPath': backgroundVideoPath,
      'backgroundMusicPath': backgroundMusicPath,
      'localModelsPath': localModelsPath,
      'localModelsScale': localModelsScale,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Project copyWith({
    String? name,
    Game? game,
    Timeline? timeline,
    LayoutType? layoutType,
    String? outputPath,
    String? backgroundVideoPath,
    String? backgroundMusicPath,
    String? localModelsPath,
    double? localModelsScale,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      game: game ?? this.game,
      timeline: timeline ?? this.timeline,
      layoutType: layoutType ?? this.layoutType,
      outputPath: outputPath ?? this.outputPath,
      backgroundVideoPath: backgroundVideoPath ?? this.backgroundVideoPath,
      backgroundMusicPath: backgroundMusicPath ?? this.backgroundMusicPath,
      localModelsPath: localModelsPath ?? this.localModelsPath,
      localModelsScale: localModelsScale ?? this.localModelsScale,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Project clearBackgroundVideo() {
    return Project(
      id: id, name: name, game: game, timeline: timeline, layoutType: layoutType,
      outputPath: outputPath, backgroundVideoPath: null, backgroundMusicPath: backgroundMusicPath,
      createdAt: createdAt, updatedAt: updatedAt,
    );
  }

  Project clearBackgroundMusic() {
    return Project(
      id: id, name: name, game: game, timeline: timeline, layoutType: layoutType,
      outputPath: outputPath, backgroundVideoPath: backgroundVideoPath, backgroundMusicPath: null,
      localModelsPath: localModelsPath,
      createdAt: createdAt, updatedAt: updatedAt,
    );
  }
  
  Project clearLocalModelsPath() {
    return Project(
      id: id, name: name, game: game, timeline: timeline, layoutType: layoutType,
      outputPath: outputPath, backgroundVideoPath: backgroundVideoPath, backgroundMusicPath: backgroundMusicPath,
      localModelsPath: null,
      createdAt: createdAt, updatedAt: updatedAt,
    );
  }
}
