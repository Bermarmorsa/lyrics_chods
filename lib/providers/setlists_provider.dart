// lib/providers/setlists_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/setlist.dart';
import '../services/storage_service.dart';

final setlistsProvider =
    NotifierProvider<SetlistsNotifier, List<Setlist>>(SetlistsNotifier.new);

/// Gestiona el estado de todos los setlists.
///
/// Estado: lista de [Setlist] en memoria, espejo de lo guardado en Hive.
/// La fuente de verdad es Hive; el estado es un reflejo para que la UI
/// sea reactiva sin leer disco en cada frame.
class SetlistsNotifier extends Notifier<List<Setlist>> {
  @override
  List<Setlist> build() => StorageService.getAllSetlists();

  // ---------------------------------------------------------------------------
  // CRUD de setlists
  // ---------------------------------------------------------------------------

  /// Crea un nuevo setlist vacío. Devuelve el objeto creado.
  Future<Setlist> createSetlist(String name) async {
    final setlist = Setlist(
      // ID único basado en microsegundos — suficiente para uso local
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      songIds: const [],
      createdAt: DateTime.now(),
    );
    await StorageService.saveSetlist(setlist);
    state = [setlist, ...state]; // más reciente primero
    return setlist;
  }

  Future<void> deleteSetlist(String id) async {
    await StorageService.deleteSetlist(id);
    state = state.where((s) => s.id != id).toList();
  }

  Future<void> renameSetlist(String id, String newName) async {
    state = await _updateSetlist(
      id,
      (s) => s.copyWith(name: newName.trim()),
    );
  }

  // ---------------------------------------------------------------------------
  // Gestión de canciones dentro de un setlist
  // ---------------------------------------------------------------------------

  /// Añade [songId] al final del setlist. No hace nada si ya está.
  Future<void> addSong(String setlistId, String songId) async {
    final setlist = _find(setlistId);
    if (setlist == null || setlist.songIds.contains(songId)) return;
    state = await _updateSetlist(
      setlistId,
      (s) => s.copyWith(songIds: [...s.songIds, songId]),
    );
  }

  Future<void> removeSong(String setlistId, String songId) async {
    state = await _updateSetlist(
      setlistId,
      (s) => s.copyWith(
        songIds: s.songIds.where((id) => id != songId).toList(),
      ),
    );
  }

  /// Reordena las canciones tras un drag & drop.
  ///
  /// [ReorderableListView] llama a onReorder(oldIndex, newIndex) donde
  /// [newIndex] ya incluye el desplazamiento por la eliminación, por lo que
  /// hay que ajustarlo cuando oldIndex < newIndex.
  Future<void> reorderSongs(
      String setlistId, int oldIndex, int newIndex) async {
    final setlist = _find(setlistId);
    if (setlist == null) return;

    final ids = List<String>.from(setlist.songIds);
    if (oldIndex < newIndex) newIndex -= 1;
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);

    state = await _updateSetlist(setlistId, (s) => s.copyWith(songIds: ids));
  }

  // ---------------------------------------------------------------------------
  // Helpers privados
  // ---------------------------------------------------------------------------

  Setlist? _find(String id) {
    final matches = state.where((s) => s.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  /// Aplica [transform] al setlist con [id], guarda en Hive y devuelve la
  /// nueva lista de estado.
  Future<List<Setlist>> _updateSetlist(
    String id,
    Setlist Function(Setlist) transform,
  ) async {
    final updated = state.map((s) {
      if (s.id != id) return s;
      return transform(s);
    }).toList();

    final changed = updated.firstWhere((s) => s.id == id,
        orElse: () => state.first);
    await StorageService.saveSetlist(changed);
    return updated;
  }
}
