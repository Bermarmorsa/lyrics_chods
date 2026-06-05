// lib/providers/concerts_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/concert_recording.dart';
import '../services/concert_service.dart';

class ConcertsNotifier extends AsyncNotifier<List<ConcertRecording>> {
  @override
  Future<List<ConcertRecording>> build() => ConcertService.loadAll();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(ConcertService.loadAll);
  }

  Future<void> delete(String id) async {
    await ConcertService.delete(id);
    await refresh();
  }

  Future<ConcertRecording?> importFile() async {
    final recording = await ConcertService.pickAndImport();
    if (recording != null) await refresh();
    return recording;
  }
}

final concertsProvider =
    AsyncNotifierProvider<ConcertsNotifier, List<ConcertRecording>>(
  ConcertsNotifier.new,
);
