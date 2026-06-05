// lib/services/file_service.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import 'chordpro_parser.dart';

/// Gestiona el acceso a archivos ChordPro en el dispositivo.
///
/// ## Por qué copiamos los archivos
/// En Android 10+, el selector de archivos devuelve una ruta temporal
/// en el cache de la app. Si el usuario borra el cache, la canción desaparece.
/// Al copiar a `documents/songs/`, el archivo persiste aunque se limpie el cache.
class FileService {
  static const _supportedExtensions = ['cho', 'chordpro'];

  // ---------------------------------------------------------------------------
  // Importar canciones nuevas
  // ---------------------------------------------------------------------------

  /// Abre el selector de archivos del sistema para elegir uno o varios .cho/.chordpro.
  ///
  /// - Copia cada archivo a `documents/songs/` para acceso permanente.
  /// - Parsea el contenido ChordPro y devuelve la lista de [Song].
  /// - Devuelve una lista vacía si el usuario cancela o hay errores.
  static Future<List<Song>> pickAndImportSongs() async {
    // Abrir el selector de archivos
    // FileType.any porque Android no reconoce .cho/.chordpro como MIME types
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return [];

    // Obtener la carpeta destino dentro de los documentos de la app
    final destDir = await _getSongsDirectory();

    final songs = <Song>[];
    for (final pickedFile in result.files) {
      final sourcePath = pickedFile.path;
      if (sourcePath == null) continue;

      try {
        final safeName = _sanitizeFileName(pickedFile.name);
        if (safeName.isEmpty) continue;
        final destPath = '${destDir.path}/$safeName';
        await File(sourcePath).copy(destPath);

        // Parsear desde la copia permanente
        final content = await File(destPath).readAsString();
        songs.add(ChordProParser.parse(content, filePath: destPath));
      } catch (e) {
        // Si falla un archivo, registramos el error y continuamos con los demás
        debugPrint('[FileService] Error al importar "${pickedFile.name}": $e');
      }
    }

    return songs;
  }

  // ---------------------------------------------------------------------------
  // Cargar una canción ya importada
  // ---------------------------------------------------------------------------

  /// Lee y parsea un archivo ChordPro desde [filePath].
  ///
  /// Devuelve null si el archivo no existe o falla la lectura.
  /// [filePath] debe ser la ruta a la copia en `documents/songs/`.
  static Future<Song?> loadSong(String filePath) async {
    try {
      // Finding 3: verificar que la ruta está dentro del directorio de la app
      final docsDir = (await getApplicationDocumentsDirectory()).path;
      final resolved = File(filePath).absolute.path;
      if (!resolved.startsWith(docsDir)) {
        debugPrint('[FileService] Ruta fuera del directorio permitido: $filePath');
        return null;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[FileService] Archivo no encontrado: $filePath');
        return null;
      }
      final content = await file.readAsString();
      return ChordProParser.parse(content, filePath: filePath);
    } catch (e) {
      debugPrint('[FileService] Error al cargar "$filePath": $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Guardar / crear canciones
  // ---------------------------------------------------------------------------

  /// Sobreescribe el contenido de [filePath] y devuelve la [Song] re-parseada.
  static Future<Song> saveRawContent(String filePath, String content) async {
    await File(filePath).writeAsString(content);
    return ChordProParser.parse(content, filePath: filePath);
  }

  /// Crea un archivo nuevo en documents/songs/ y devuelve la [Song] parseada.
  static Future<Song> createSong(String content) async {
    final destDir = await _getSongsDirectory();
    final parsed = ChordProParser.parse(content);
    final base = parsed.title.isEmpty
        ? 'cancion_${DateTime.now().millisecondsSinceEpoch}'
        : parsed.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();
    var filePath = '${destDir.path}/$base.cho';
    var counter = 1;
    // Finding 11: límite de iteraciones para evitar bucle infinito
    while (await File(filePath).exists() && counter <= 999) {
      filePath = '${destDir.path}/${base}_$counter.cho';
      counter++;
    }
    if (counter > 999) {
      throw Exception('Demasiados archivos con el mismo nombre base: "$base"');
    }
    await File(filePath).writeAsString(content);
    return ChordProParser.parse(content, filePath: filePath);
  }

  // ---------------------------------------------------------------------------
  // Utilidades privadas
  // ---------------------------------------------------------------------------

  /// Devuelve (y crea si no existe) el directorio `documents/songs/`.
  static Future<Directory> _getSongsDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final songsDir = Directory('${docsDir.path}/songs');
    if (!await songsDir.exists()) {
      await songsDir.create(recursive: true);
    }
    return songsDir;
  }

  /// Extrae el nombre base y elimina caracteres peligrosos para el sistema de archivos.
  static String _sanitizeFileName(String name) {
    final base = name.split(RegExp(r'[/\\]')).last;
    final safe = base
        .replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_')
        .trim();
    return safe.length > 255 ? safe.substring(0, 255) : safe;
  }
}
