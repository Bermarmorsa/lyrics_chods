// lib/services/setlist_export_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/setlist.dart';
import '../models/song_summary.dart';
import 'chordpro_parser.dart';
import 'storage_service.dart';

/// Resultado de una importación de setlist.
class SetlistImportResult {
  final String name;
  final List<String> songIds; // IDs de todas las canciones (nuevas + existentes)
  final int added;            // canciones nuevas añadidas a la biblioteca
  final int skipped;          // canciones que ya existían

  const SetlistImportResult({
    required this.name,
    required this.songIds,
    required this.added,
    required this.skipped,
  });
}

/// Gestiona la exportación e importación de setlists en formato JSON (.setlist).
class SetlistExportService {
  static const int _version = 1;

  // ---------------------------------------------------------------------------
  // Exportación
  // ---------------------------------------------------------------------------

  /// Serializa el setlist con el contenido de cada canción y abre el
  /// diálogo de compartir del sistema operativo.
  static Future<void> exportAndShare(
    Setlist setlist,
    List<SongSummary> library,
  ) async {
    final songs = <Map<String, dynamic>>[];

    for (final songId in setlist.songIds) {
      final matches = library.where((s) => s.id == songId);
      if (matches.isEmpty) continue;
      final summary = matches.first;
      if (summary.filePath == null) continue;

      try {
        final content = await File(summary.filePath!).readAsString();
        songs.add({
          'title': summary.title,
          'artist': summary.artist,
          if (summary.key != null) 'key': summary.key,
          'capo': summary.capo,
          if (summary.autoFitScreens != null)
            'autoFitScreens': summary.autoFitScreens,
          'content': content,
        });
      } catch (e) {
        debugPrint('[SetlistExport] Error leyendo "${summary.title}": $e');
      }
    }

    final data = {
      'name': setlist.name,
      'version': _version,
      'exportedAt': DateTime.now().toIso8601String(),
      'songs': songs,
    };

    final tempDir = await getTemporaryDirectory();
    final safeName =
        setlist.name.replaceAll(RegExp(r'[<>:"/\\|?*\s]'), '_');
    final file = File('${tempDir.path}/$safeName.setlist');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: setlist.name,
    );
  }

  // ---------------------------------------------------------------------------
  // Importación
  // ---------------------------------------------------------------------------

  /// Lee un archivo .setlist, escribe los .cho en documentos y guarda los
  /// metadatos en Hive. Devuelve los IDs de las canciones para crear el setlist.
  static Future<SetlistImportResult> importFromFile(String filePath) async {
    final raw = await File(filePath).readAsString();
    final data = jsonDecode(raw) as Map<String, dynamic>;

    final name = data['name'] as String? ?? 'Setlist importado';
    final songsJson = (data['songs'] as List<dynamic>?) ?? [];

    final destDir = await _getSongsDirectory();
    final songIds = <String>[];
    int added = 0;
    int skipped = 0;

    for (final item in songsJson) {
      final map = item as Map<String, dynamic>;
      final content = map['content'] as String? ?? '';
      if (content.isEmpty) continue;

      final title = (map['title'] as String? ?? 'Sin título')
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
          .trim();

      // Buscar una ruta libre para el archivo .cho
      var destPath = '${destDir.path}/$title.cho';
      var counter = 1;
      while (await File(destPath).exists()) {
        final existing = await File(destPath).readAsString();
        if (existing.trim() == content.trim()) break; // mismo contenido, reusar
        destPath = '${destDir.path}/${title}_$counter.cho';
        counter++;
      }

      // Comprobar si ya está en la biblioteca por ID
      final songId = destPath.hashCode.abs().toString();
      if (StorageService.containsSong(songId)) {
        songIds.add(songId);
        skipped++;
        continue;
      }

      await File(destPath).writeAsString(content);

      final parsed = ChordProParser.parse(content, filePath: destPath);
      final summary = SongSummary(
        id: parsed.id,
        title: parsed.title,
        artist: parsed.artist,
        key: parsed.key,
        capo: parsed.capo,
        filePath: destPath,
        autoFitScreens: map['autoFitScreens'] as int?,
      );

      await StorageService.saveSong(summary);
      songIds.add(summary.id);
      added++;
    }

    return SetlistImportResult(
      name: name,
      songIds: songIds,
      added: added,
      skipped: skipped,
    );
  }

  // ---------------------------------------------------------------------------
  // Utilidades privadas
  // ---------------------------------------------------------------------------

  static Future<Directory> _getSongsDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/songs');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
