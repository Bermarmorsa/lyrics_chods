// lib/models/song_summary.dart

import 'song.dart';

/// Versión ligera de [Song] pensada para mostrar en la biblioteca.
///
/// Solo contiene los metadatos necesarios para listar canciones.
/// El objeto [Song] completo (con todas las líneas parseadas) se construye
/// bajo demanda en [FileService.loadSong] cuando el usuario abre la canción.
///
/// Se serializa a/desde [Map] para guardarse en Hive sin generación de código.
class SongSummary {
  final String id;
  final String title;
  final String artist;
  final String? key;
  final int capo;

  /// Ruta al archivo .cho en el directorio de documentos de la app.
  final String? filePath;

  /// Override de auto-ajuste específico para esta canción.
  /// null = usar el ajuste global de la app.
  final int? autoFitScreens;

  const SongSummary({
    required this.id,
    required this.title,
    required this.artist,
    this.key,
    this.capo = 0,
    this.filePath,
    this.autoFitScreens,
  });

  SongSummary copyWith({
    String? title,
    String? artist,
    String? key,
    int? capo,
    String? filePath,
    Object? autoFitScreens = _sentinel,
  }) => SongSummary(
    id: id,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    key: key ?? this.key,
    capo: capo ?? this.capo,
    filePath: filePath ?? this.filePath,
    autoFitScreens: autoFitScreens == _sentinel
        ? this.autoFitScreens
        : autoFitScreens as int?,
  );

  static const Object _sentinel = Object();

  /// Crea un [SongSummary] a partir de un [Song] ya parseado.
  factory SongSummary.fromSong(Song song) => SongSummary(
        id: song.id,
        title: song.title,
        artist: song.artist,
        key: song.key,
        capo: song.capo,
        filePath: song.filePath,
      );

  // ---------------------------------------------------------------------------
  // Serialización para Hive (guardamos como Map con tipos primitivos)
  // ---------------------------------------------------------------------------

  /// Convierte a Map para guardar en Hive.
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'key': key,
        'capo': capo,
        'filePath': filePath,
        'autoFitScreens': autoFitScreens,
      };

  /// Reconstruye desde un Map leído de Hive.
  factory SongSummary.fromMap(Map map) => SongSummary(
        id: map['id'] as String,
        title: map['title'] as String,
        artist: map['artist'] as String,
        key: map['key'] as String?,
        capo: (map['capo'] as int?) ?? 0,
        filePath: map['filePath'] as String?,
        autoFitScreens: map['autoFitScreens'] as int?,
      );

  @override
  String toString() => '$title — $artist';
}
