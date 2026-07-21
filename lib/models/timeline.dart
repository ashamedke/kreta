import 'timing.dart';
import 'track.dart';

export 'timeline_item.dart';
export 'track.dart';

/// The timeline structure for a video.
class Timeline {
  final String gameId;
  final List<Track> tracks;
  final TimingRules timingRules;
  final int? introMs;
  final int? outroMs;

  const Timeline({
    required this.gameId,
    required this.tracks,
    required this.timingRules,
    this.introMs,
    this.outroMs,
  });

  factory Timeline.fromJson(Map<String, dynamic> json) {
    return Timeline(
      gameId: json['gameId'] as String,
      tracks: (json['tracks'] as List? ?? [])
          .map((e) => Track.fromJson(e as Map<String, dynamic>))
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
      'tracks': tracks.map((t) => t.toJson()).toList(),
      'timingRules': timingRules.toJson(),
      'introMs': introMs,
      'outroMs': outroMs,
    };
  }

  Timeline copyWith({
    String? gameId,
    List<Track>? tracks,
    TimingRules? timingRules,
    int? introMs,
    int? outroMs,
  }) {
    return Timeline(
      gameId: gameId ?? this.gameId,
      tracks: tracks ?? this.tracks,
      timingRules: timingRules ?? this.timingRules,
      introMs: introMs ?? this.introMs,
      outroMs: outroMs ?? this.outroMs,
    );
  }
}
