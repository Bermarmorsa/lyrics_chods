// lib/models/concert_recording.dart

enum RecordingStatus { idle, recording, paused }

enum ConcertEventType { pedalNext, pedalPrev, songChange }

class ConcertEvent {
  final int elapsedMs;
  final ConcertEventType type;
  final int songIndex;
  final double scrollFraction;

  const ConcertEvent({
    required this.elapsedMs,
    required this.type,
    required this.songIndex,
    required this.scrollFraction,
  });

  Map<String, dynamic> toMap() => {
        't': elapsedMs,
        'type': _typeToString(type),
        'songIndex': songIndex,
        'scrollFraction': scrollFraction,
      };

  factory ConcertEvent.fromMap(Map<dynamic, dynamic> map) => ConcertEvent(
        elapsedMs: map['t'] as int,
        type: _typeFromString(map['type'] as String),
        songIndex: map['songIndex'] as int,
        scrollFraction: (map['scrollFraction'] as num).toDouble(),
      );

  static String _typeToString(ConcertEventType t) => switch (t) {
        ConcertEventType.pedalNext => 'pedal_next',
        ConcertEventType.pedalPrev => 'pedal_prev',
        ConcertEventType.songChange => 'song_change',
      };

  static ConcertEventType _typeFromString(String s) => switch (s) {
        'pedal_next' => ConcertEventType.pedalNext,
        'pedal_prev' => ConcertEventType.pedalPrev,
        _ => ConcertEventType.songChange,
      };
}

class ConcertRecording {
  final String id;
  final String name;
  final String setlistId;
  final String setlistName;
  final List<String> songTitles;
  final DateTime startTime;
  final int durationMs;
  final List<ConcertEvent> events;

  const ConcertRecording({
    required this.id,
    required this.name,
    required this.setlistId,
    required this.setlistName,
    required this.songTitles,
    required this.startTime,
    required this.durationMs,
    required this.events,
  });

  ConcertRecording copyWith({String? name}) => ConcertRecording(
        id: id,
        name: name ?? this.name,
        setlistId: setlistId,
        setlistName: setlistName,
        songTitles: songTitles,
        startTime: startTime,
        durationMs: durationMs,
        events: events,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'version': 1,
        'name': name,
        'setlistId': setlistId,
        'setlistName': setlistName,
        'songTitles': List<String>.from(songTitles),
        'startTime': startTime.toIso8601String(),
        'durationMs': durationMs,
        'events': events.map((e) => e.toMap()).toList(),
      };

  factory ConcertRecording.fromMap(Map<dynamic, dynamic> map) =>
      ConcertRecording(
        id: map['id'] as String,
        name: map['name'] as String,
        setlistId: map['setlistId'] as String,
        setlistName: map['setlistName'] as String,
        songTitles: List<String>.from(map['songTitles'] as List),
        startTime: DateTime.parse(map['startTime'] as String),
        durationMs: map['durationMs'] as int,
        events: (map['events'] as List)
            .map((e) => ConcertEvent.fromMap(e as Map))
            .toList(),
      );
}
