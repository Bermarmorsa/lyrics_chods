// lib/services/storage_service.dart

import 'package:hive_flutter/hive_flutter.dart';
import '../models/song_summary.dart';
import '../models/setlist.dart';

/// Persiste canciones y setlists en cajas Hive locales.
///
/// Ambas cajas se abren en [init] antes de runApp. Todas las
/// operaciones posteriores son síncronas (Hive lee de memoria).
class StorageService {
  static const _songsBox = 'songs_metadata';
  static const _setlistsBox = 'setlists_metadata';
  static const _settingsBox = 'app_settings';
  static const _settingsKey = 'settings'; // clave única dentro de la caja

  // ---------------------------------------------------------------------------
  // Inicialización — llamar una vez en main() antes de runApp
  // ---------------------------------------------------------------------------

  static Future<void> init() async {
    await Hive.openBox(_songsBox);
    await Hive.openBox(_setlistsBox);
    await Hive.openBox(_settingsBox);
  }

  static Box get _songs => Hive.box(_songsBox);
  static Box get _setlists => Hive.box(_setlistsBox);
  static Box get _settings => Hive.box(_settingsBox);

  // ---------------------------------------------------------------------------
  // Canciones
  // ---------------------------------------------------------------------------

  static List<SongSummary> getAllSongs() {
    return _songs.values
        .map((v) => SongSummary.fromMap(v as Map))
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  static Future<void> saveSong(SongSummary summary) async {
    await _songs.put(summary.id, summary.toMap());
  }

  static Future<void> deleteSong(String id) async {
    await _songs.delete(id);
  }

  static bool containsSong(String id) => _songs.containsKey(id);

  // ---------------------------------------------------------------------------
  // Setlists
  // ---------------------------------------------------------------------------

  /// Devuelve todos los setlists ordenados por fecha de creación (más reciente primero).
  static List<Setlist> getAllSetlists() {
    return _setlists.values
        .map((v) => Setlist.fromMap(v as Map))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> saveSetlist(Setlist setlist) async {
    await _setlists.put(setlist.id, setlist.toMap());
  }

  static Future<void> deleteSetlist(String id) async {
    await _setlists.delete(id);
  }

  // ---------------------------------------------------------------------------
  // Ajustes de la app
  // ---------------------------------------------------------------------------

  /// Lee el mapa de ajustes de Hive. Devuelve null si no hay datos guardados
  /// (primera ejecución → el provider usará los valores por defecto).
  static Map? loadSettingsMap() =>
      _settings.get(_settingsKey) as Map?;

  /// Persiste el mapa de ajustes. Se llama en background (sin await en el UI).
  static Future<void> saveSettingsMap(Map map) async =>
      _settings.put(_settingsKey, map);
}
