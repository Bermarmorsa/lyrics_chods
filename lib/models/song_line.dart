// lib/models/song_line.dart

/// Un segmento dentro de una línea de letra: un acorde opcional más el texto
/// que aparece debajo de él.
///
/// Ejemplo: "[G]Hola " → ChordSegment(chord: 'G', text: 'Hola ')
/// Ejemplo: "intro "   → ChordSegment(chord: null, text: 'intro ')
class ChordSegment {
  /// El acorde, p.ej. 'G', 'Am7', 'C#m'. Null si no hay acorde en esta posición.
  final String? chord;

  /// El texto de letra que va debajo del acorde (puede ser vacío).
  final String text;

  const ChordSegment({this.chord, required this.text});

  @override
  String toString() => chord != null ? '[$chord]$text' : text;
}

// -----------------------------------------------------------------------------

/// Tipo de línea parseada en un archivo ChordPro.
enum SongLineType {
  /// Línea con letra y, opcionalmente, acordes intercalados.
  lyric,

  /// Cabecera de sección: Verso, Estribillo, Puente, etc.
  section,

  /// Línea en blanco, usada como separador visual entre estrofas.
  empty,
}

// -----------------------------------------------------------------------------

/// Representa una línea ya parseada del archivo ChordPro.
///
/// Hay tres variantes según [type]:
/// - [SongLineType.lyric]   → tiene [segments] con los pares acorde+texto
/// - [SongLineType.section] → tiene [sectionLabel] con el nombre de la sección
/// - [SongLineType.empty]   → sin datos, solo marca un espacio en blanco
class SongLine {
  final SongLineType type;

  /// Solo válido cuando type == lyric.
  /// Lista de segmentos acorde+texto que forman la línea.
  final List<ChordSegment> segments;

  /// Solo válido cuando type == section.
  /// Nombre de la sección, p.ej. 'Estribillo', 'Verso 1'.
  final String? sectionLabel;

  // Constructor privado — usamos los factory constructors de abajo.
  const SongLine._({
    required this.type,
    this.segments = const [],
    this.sectionLabel,
  });

  /// Crea una línea de letra con sus segmentos.
  factory SongLine.lyric(List<ChordSegment> segments) =>
      SongLine._(type: SongLineType.lyric, segments: segments);

  /// Crea una cabecera de sección con su etiqueta.
  factory SongLine.section(String label) =>
      SongLine._(type: SongLineType.section, sectionLabel: label);

  /// Crea una línea en blanco.
  factory SongLine.empty() => const SongLine._(type: SongLineType.empty);

  /// Devuelve true si esta línea tiene al menos un acorde definido.
  bool get hasChords =>
      type == SongLineType.lyric && segments.any((s) => s.chord != null);

  /// Texto plano de la línea (sin acordes), útil para búsquedas.
  String get plainText => segments.map((s) => s.text).join();
}
