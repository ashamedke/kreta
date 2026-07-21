import 'package:uuid/uuid.dart';
import 'timeline_item.dart';

enum TrackType { video, audio, annotation, overlay }

class Track {
  final String id;
  final String name;
  final TrackType type;
  final List<TimelineItem> items;

  Track({
    String? id,
    required this.name,
    required this.type,
    List<TimelineItem>? items,
  })  : id = id ?? const Uuid().v4(),
        items = items ?? [];

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'],
      name: json['name'],
      type: TrackType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TrackType.video,
      ),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => TimelineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'items': items.map((e) => e.toJson()).toList(),
      };

  Track copyWith({
    String? id,
    String? name,
    TrackType? type,
    List<TimelineItem>? items,
  }) {
    return Track(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      items: items ?? this.items,
    );
  }
}
