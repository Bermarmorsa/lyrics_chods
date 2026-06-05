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
        elapsedMs: ((map['t'] as num?)?.toInt() ?? 0).clamp(0, 86400000),
        type: _typeFromString((map['type'] as String?) ?? ''),
        songIndex: ((map['songIndex'] as num?)?.toInt() ?? 0).clamp(0, 999),
        scrollFraction:
            ((map['scrollFraction'] as num?)?.toDouble() ?? 0.0)
                .clamp(0.0, 1.0),
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

  factory ConcertRecording.fromMap(Map<dynamic, dynamic> map) {
    String _cap(String? s, int max) {
      final v = (s ?? '').trim();
      return v.length > max ? v.substring(0, max) : v;
    }

    final rawId = (map['id'] as String?) ??
        DateTime.now().millisecondsSinceEpoch.toString();

    return ConcertRecording(
      id: rawId,
      name: _cap(map['name'] as String?, 200).isEmpty
          ? 'Concierto'
          : _cap(map['name'] as String?, 200),
      setlistId: _cap(map['setlistId'] as String?, 200),
      setlistName: _cap(map['setlistName'] as String?, 200),
      songTitles: ((map['songTitles'] as List?) ?? [])
          .map((e) => _cap(e?.toString(), 200))
          .toList(),
      startTime: map['startTime'] != null
          ? (DateTime.tryParse(map['startTime'] as String) ?? DateTime.now())
          : DateTime.now(),
      durationMs:
          ((map['durationMs'] as num?)?.toInt() ?? 0).clamp(0, 86400000),
      events: ((map['events'] as List?) ?? [])
          .map((e) => ConcertEvent.fromMap(e as Map))
          .toList(),
    );
  }
}
