// lib/providers/library_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song_summary.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';

/// Provider global de la biblioteca de canciones.
///
/// Cualquier widget que haga `ref.watch(libraryProvider)` se reconstruye
/// automáticamente cada vez que la lista cambia.
final libraryProvider =
    NotifierProvider<LibraryNotifier, List<SongSummary>>(LibraryNotifier.new);

/// Gestiona el estado de la biblioteca: lista de [SongSummary] en memoria.
///
/// ## Ciclo de vida del estado
/// 1. `build()` se ejecuta una sola vez al crearse el provider.
///    Lee los metadatos guardados en Hive y los carga en memoria.
/// 2. `importSongs()` abre el selector de archivos, los importa y actualiza el estado.
/// 3. `removeSong()` borra de Hive y actualiza el estado.
///
/// La fuente de verdad es Hive; el estado en memoria es un reflejo ordenado.
class LibraryNotifier extends Notifier<List<SongSummary>> {
  @override
  List<SongSummary> build() {
    // Carga inicial: leer todos los metadatos guardados en Hive
    return StorageService.getAllSongs();
  }

  /// Abre el selector de archivos, importa las canciones seleccionadas
  /// y devuelve cuántas canciones nuevas se añadieron.
  ///
  /// Las canciones ya existentes (mismo ID) se omiten para no duplicar.
  Future<int> importSongs() async {
    final songs = await FileService.pickAndImportSongs();
    if (songs.isEmpty) return 0; // usuario canceló o no se importó nada

    int added = 0;
    for (final song in songs) {
      final summary = SongSummary.fromSong(song);

      // Saltar si ya existe (misma ruta de archivo = mismo ID)
      if (StorageService.containsSong(summary.id)) continue;

      await StorageService.saveSong(summary);
      added++;
    }

    if (added > 0) {
      // Recargar desde Hive para que el orden alfabético sea correcto
      state = StorageService.getAllSongs();
    }

    return added;
  }

  /// Elimina una canción de la biblioteca (Hive + estado en memoria).
  /// No borra el archivo físico del dispositivo.
  Future<void> removeSong(String id) async {
    await StorageService.deleteSong(id);
    state = state.where((s) => s.id != id).toList();
  }

  /// Añade (o actualiza si ya existe) una canción importada externamente.
  /// Usado por [DriveNotifier] para registrar canciones descargadas de Drive.
  Future<void> addSong(SongSummary summary) async {
    await StorageService.saveSong(summary); // upsert: crea o sobreescribe
    state = StorageService.getAllSongs();   // recarga en orden alfabético
  }

  /// Recarga la biblioteca desde Hive (útil tras importaciones externas).
  void reloadAll() {
    state = StorageService.getAllSongs();
  }

  /// Guarda el override de auto-ajuste de pantallas para una canción concreta.
  Future<void> updateSongAutoFit(String id, int? screens) async {
    final matches = state.where((s) => s.id == id);
    if (matches.isEmpty) return;
    final updated = matches.first.copyWith(autoFitScreens: screens);
    await StorageService.saveSong(updated);
    state = state.map((s) => s.id == id ? updated : s).toList();
  }
}
