// lib/providers/recording_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/concert_recording.dart';
import '../services/concert_service.dart';
import 'concerts_provider.dart';

class RecordingState {
  final RecordingStatus status;
  final DateTime? startTime;
  final int pausedOffsetMs; // ms totales acumulados en pausa
  final DateTime? pausedAt; // momento en que se pausó (null si no está en pausa)
  final String setlistId;
  final String setlistName;
  final List<String> songTitles;
  final List<ConcertEvent> events;

  const RecordingState({
    this.status = RecordingStatus.idle,
    this.startTime,
    this.pausedOffsetMs = 0,
    this.pausedAt,
    this.setlistId = '',
    this.setlistName = '',
    this.songTitles = const [],
    this.events = const [],
  });

  bool get isIdle => status == RecordingStatus.idle;
  bool get isRecording => status == RecordingStatus.recording;
  bool get isPaused => status == RecordingStatus.paused;
  bool get isActive => status != RecordingStatus.idle;

  /// Milisegundos de concierto activo (sin contar pausa).
  int get activeElapsedMs {
    if (startTime == null) return 0;
    final total = DateTime.now().difference(startTime!).inMilliseconds;
    final currentPause = pausedAt != null
        ? DateTime.now().difference(pausedAt!).inMilliseconds
        : 0;
    return total - pausedOffsetMs - currentPause;
  }

  RecordingState copyWith({
    RecordingStatus? status,
    DateTime? startTime,
    int? pausedOffsetMs,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    String? setlistId,
    String? setlistName,
    List<String>? songTitles,
    List<ConcertEvent>? events,
  }) =>
      RecordingState(
        status: status ?? this.status,
        startTime: startTime ?? this.startTime,
        pausedOffsetMs: pausedOffsetMs ?? this.pausedOffsetMs,
        pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
        setlistId: setlistId ?? this.setlistId,
        setlistName: setlistName ?? this.setlistName,
        songTitles: songTitles ?? this.songTitles,
        events: events ?? this.events,
      );
}

class RecordingNotifier extends Notifier<RecordingState> {
  @override
  RecordingState build() => const RecordingState();

  void startRecording({
    required String setlistId,
    required String setlistName,
    required List<String> songTitles,
  }) {
    state = RecordingState(
      status: RecordingStatus.recording,
      startTime: DateTime.now(),
      setlistId: setlistId,
      setlistName: setlistName,
      songTitles: songTitles,
    );
  }

  void pauseRecording() {
    if (!state.isRecording) return;
    state = state.copyWith(
      status: RecordingStatus.paused,
      pausedAt: DateTime.now(),
    );
  }

  void resumeRecording() {
    if (!state.isPaused) return;
    final addedMs = state.pausedAt != null
        ? DateTime.now().difference(state.pausedAt!).inMilliseconds
        : 0;
    state = state.copyWith(
      status: RecordingStatus.recording,
      pausedOffsetMs: state.pausedOffsetMs + addedMs,
      clearPausedAt: true,
    );
  }

  void addEvent({
    required ConcertEventType type,
    required int songIndex,
    required double scrollFraction,
  }) {
    if (!state.isRecording) return;
    final event = ConcertEvent(
      elapsedMs: state.activeElapsedMs,
      type: type,
      songIndex: songIndex,
      scrollFraction: scrollFraction,
    );
    state = state.copyWith(
      events: [...state.events, event],
    );
  }

  /// Para la grabación y guarda con el nombre dado. Devuelve el objeto guardado.
  Future<ConcertRecording?> stopAndSave({required String name}) async {
    if (!state.isActive) return null;

    final recording = ConcertRecording(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      setlistId: state.setlistId,
      setlistName: state.setlistName,
      songTitles: state.songTitles,
      startTime: state.startTime!,
      durationMs: state.activeElapsedMs,
      events: List.unmodifiable(state.events),
    );

    await ConcertService.save(recording);

    // Refrescar la lista de conciertos
    ref.read(concertsProvider.notifier).refresh();

    state = const RecordingState(); // reset a idle
    return recording;
  }

  void cancel() {
    state = const RecordingState();
  }
}

final recordingProvider =
    NotifierProvider<RecordingNotifier, RecordingState>(RecordingNotifier.new);
