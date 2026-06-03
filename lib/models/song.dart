// lib/models/song.dart

import 'song_line.dart';

/// Representa una canción completa, con metadatos y líneas parseadas.
///
/// Se crea a través de [ChordProParser.parse] y es inmutable: si necesitas
/// cambiar algo (p.ej. al transponer), usas [copyWith] para generar una copia.
class Song {
  /// ID único. Se genera a partir del path del archivo o del título+artista.
  final String id;

  /// Título de la canción, extraído de la directiva {title:}.
  final String title;

  /// Artista o banda, extraído de {artist:} o {subtitle:}.
  final String artist;

  /// Tonalidad original del archivo, p.ej. 'G', 'Am', 'C#'. Puede ser null.
  final String? key;

  /// Posición del cejilla (0 = sin cejilla), de la directiva {capo:}.
  final int capo;

  /// Tempo en BPM, de la directiva {tempo:}. Puede ser null.
  final int? tempo;

  /// Líneas del cuerpo de la canción ya parseadas (letra, secciones, vacíos).
  final List<SongLine> lines;

  /// Texto original del archivo ChordPro tal cual se leyó del disco.
  /// Se conserva para poder re-parsear la canción con transposición aplicada.
  final String rawContent;

  /// Ruta al archivo en el dispositivo. Null si fue importado de otra fuente.
  final String? filePath;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    this.key,
    this.capo = 0,
    this.tempo,
    required this.lines,
    required this.rawContent,
    this.filePath,
  });

  /// Crea una copia de esta canción con los campos indicados reemplazados.
  /// Útil para transposición: copyWith(lines: lineasTranspuestas).
  Song copyWith({
    String? title,
    String? artist,
    String? key,
    int? capo,
    int? tempo,
    List<SongLine>? lines,
    String? rawContent,
    String? filePath,
  }) {
    return Song(
      id: id, // el ID nunca cambia
      title: title ?? this.title,
      artist: artist ?? this.artist,
      key: key ?? this.key,
      capo: capo ?? this.capo,
      tempo: tempo ?? this.tempo,
      lines: lines ?? this.lines,
      rawContent: rawContent ?? this.rawContent,
      filePath: filePath ?? this.filePath,
    );
  }

  @override
  String toString() => '$title — $artist';
}
