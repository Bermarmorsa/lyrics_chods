// lib/services/concert_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../models/concert_recording.dart';

class ConcertService {
  // ---------------------------------------------------------------------------
  // Directorio de conciertos
  // ---------------------------------------------------------------------------

  static Future<Directory> _concertsDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/concerts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ---------------------------------------------------------------------------
  // Guardar
  // ---------------------------------------------------------------------------

  static Future<void> save(ConcertRecording recording) async {
    final dir = await _concertsDir();
    final file = File('${dir.path}/${recording.id}.concert');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(recording.toMap()),
    );
  }

  // ---------------------------------------------------------------------------
  // Cargar todos
  // ---------------------------------------------------------------------------

  static Future<List<ConcertRecording>> loadAll() async {
    final dir = await _concertsDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.concert'))
        .toList();

    final recordings = <ConcertRecording>[];
    for (final file in files) {
      try {
        final raw = await file.readAsString();
        final map = jsonDecode(raw) as Map<dynamic, dynamic>;
        recordings.add(ConcertRecording.fromMap(map));
      } catch (e) {
        debugPrint('[ConcertService] Error leyendo ${file.path}: $e');
      }
    }

    recordings.sort((a, b) => b.startTime.compareTo(a.startTime));
    return recordings;
  }

  // ---------------------------------------------------------------------------
  // Eliminar
  // ---------------------------------------------------------------------------

  static Future<void> delete(String id) async {
    final dir = await _concertsDir();
    final file = File('${dir.path}/$id.concert');
    if (await file.exists()) await file.delete();
  }

  // ---------------------------------------------------------------------------
  // Exportar (share)
  // ---------------------------------------------------------------------------

  static Future<void> exportAndShare(ConcertRecording recording) async {
    final tempDir = await getTemporaryDirectory();
    final safeName =
        recording.name.replaceAll(RegExp(r'[<>:"/\\|?*\s]'), '_');
    final file = File('${tempDir.path}/$safeName.concert');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(recording.toMap()),
    );
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: recording.name,
    );
  }

  // ---------------------------------------------------------------------------
  // Importar desde archivo
  // ---------------------------------------------------------------------------

  /// Abre el picker de archivos, lee el .concert y lo guarda.
  /// Devuelve null si el usuario cancela o hay error.
  static Future<ConcertRecording?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final path = result.files.single.path;
    if (path == null) return null;

    return importFromFile(path);
  }

  static Future<ConcertRecording?> importFromFile(String filePath) async {
    try {
      final raw = await File(filePath).readAsString();
      final map = jsonDecode(raw) as Map<dynamic, dynamic>;

      // Validar que es un archivo de concierto
      if (!map.containsKey('events') || !map.containsKey('songTitles')) {
        return null;
      }

      final recording = ConcertRecording.fromMap(map);

      // Guardar con nuevo ID para evitar colisiones si ya existe
      final existing = await _fileForId(recording.id);
      if (await existing.exists()) return recording; // ya importado

      await save(recording);
      return recording;
    } catch (e) {
      debugPrint('[ConcertService] Error importando $filePath: $e');
      return null;
    }
  }

  static Future<File> _fileForId(String id) async {
    final dir = await _concertsDir();
    return File('${dir.path}/$id.concert');
  }
}
