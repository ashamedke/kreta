import 'package:uuid/uuid.dart';

enum RenderStatus { idle, preparing, rendering, encoding, complete, failed }

/// Contains configurations for video rendering presets.
class RenderPreset {
  final String name;
  final int width;
  final int height;
  final int fps;
  final int videoBitrate;

  const RenderPreset({
    required this.name,
    required this.width,
    required this.height,
    required this.fps,
    required this.videoBitrate,
  });

  static const youtube1080p30 = RenderPreset(
    name: 'youtube1080p30',
    width: 1920,
    height: 1080,
    fps: 30,
    videoBitrate: 8000,
  );

  static const youtube1080p60 = RenderPreset(
    name: 'youtube1080p60',
    width: 1920,
    height: 1080,
    fps: 60,
    videoBitrate: 12000,
  );

  static const youtube4k30 = RenderPreset(
    name: 'youtube4k30',
    width: 3840,
    height: 2160,
    fps: 30,
    videoBitrate: 35000,
  );

  static const preview480p = RenderPreset(
    name: 'preview480p',
    width: 854,
    height: 480,
    fps: 30,
    videoBitrate: 2500,
  );

  static const hd720p = RenderPreset(
    name: 'hd720p',
    width: 1280,
    height: 720,
    fps: 30,
    videoBitrate: 5000,
  );

  factory RenderPreset.fromJson(Map<String, dynamic> json) {
    return RenderPreset(
      name: json['name'] as String,
      width: json['width'] as int,
      height: json['height'] as int,
      fps: json['fps'] as int,
      videoBitrate: json['videoBitrate'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'width': width,
      'height': height,
      'fps': fps,
      'videoBitrate': videoBitrate,
    };
  }
}

/// Represents the state of a video rendering job.
class RenderJob {
  final String id;
  final String projectId;
  final RenderPreset preset;
  final RenderStatus status;
  final int currentFrame;
  final int totalFrames;
  final String? outputPath;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? completedAt;

  RenderJob({
    String? id,
    required this.projectId,
    required this.preset,
    required this.status,
    required this.currentFrame,
    required this.totalFrames,
    this.outputPath,
    this.errorMessage,
    DateTime? startedAt,
    this.completedAt,
  })  : id = id ?? const Uuid().v4(),
        startedAt = startedAt ?? DateTime.now();

  factory RenderJob.fromJson(Map<String, dynamic> json) {
    return RenderJob(
      id: json['id'] as String?,
      projectId: json['projectId'] as String,
      preset: RenderPreset.fromJson(json['preset'] as Map<String, dynamic>),
      status: RenderStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => RenderStatus.idle,
      ),
      currentFrame: json['currentFrame'] as int,
      totalFrames: json['totalFrames'] as int,
      outputPath: json['outputPath'] as String?,
      errorMessage: json['errorMessage'] as String?,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'preset': preset.toJson(),
      'status': status.name,
      'currentFrame': currentFrame,
      'totalFrames': totalFrames,
      'outputPath': outputPath,
      'errorMessage': errorMessage,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  /// Computed property for rendering progress (0.0 to 1.0)
  double get progress {
    if (totalFrames == 0) return 0.0;
    return currentFrame / totalFrames;
  }

  /// Computed property for estimated time of arrival (ETA) string
  String get eta {
    if (status != RenderStatus.rendering && status != RenderStatus.encoding) {
      return '--:--';
    }
    if (currentFrame == 0 || totalFrames == 0) return 'Calculating...';
    
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    final msPerFrame = elapsedMs / currentFrame;
    final remainingFrames = totalFrames - currentFrame;
    final remainingMs = remainingFrames * msPerFrame;
    
    final duration = Duration(milliseconds: remainingMs.round());
    return _formatDuration(duration);
  }

  /// Computed property for total elapsed time
  String get formattedDuration {
    if (completedAt != null) {
      return _formatDuration(completedAt!.difference(startedAt));
    }
    return _formatDuration(DateTime.now().difference(startedAt));
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
