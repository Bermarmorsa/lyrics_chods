// lib/core/utils/chord_utils.dart

import '../../models/song.dart';
import '../../models/song_line.dart';

/// Utilidades de transposición de acordes.
///
/// Toda la lógica es pura (sin estado, sin Flutter) para que sea
/// fácilmente testeable y reutilizable desde cualquier capa.
///
/// La transposición es no-destructiva: devuelve nuevos objetos sin
/// modificar el Song original. El archivo .cho nunca se toca.
class ChordUtils {
  ChordUtils._();

  // Doce notas cromáticas (índice = semitonos desde C)
  static const _sharpNotes = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];
  static const _flatNotes = [
    'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'
  ];

  // Captura la raíz del acorde (1 o 2 caracteres) y su sufijo.
  // Ejemplos: "Am7" → root="A", suffix="m7"
  //           "C#m" → root="C#", suffix="m"
  //           "G"   → root="G",  suffix=""
  static final _rootRegex = RegExp(r'^([A-G][#b]?)(.*)$');

  // ---------------------------------------------------------------------------
  // API pública
  // ---------------------------------------------------------------------------

  /// Transpone un acorde individual [chord] por [semitones] semitonos.
  ///
  /// - Conserva el sufijo (m, maj7, sus4, dim, etc.)
  /// - Transpone también la nota del bajo en acordes como G/B
  /// - Si no reconoce el acorde (p.ej. "N.C."), lo devuelve sin cambios
  /// - [useFlats]: si true, usa bemoles (Bb) en vez de sostenidos (A#)
  ///
  /// ```dart
  /// ChordUtils.transposeChord('G', 2)            // → 'A'
  /// ChordUtils.transposeChord('C#m7', -1)        // → 'Cm7'
  /// ChordUtils.transposeChord('G/B', 2)          // → 'A/C#'
  /// ChordUtils.transposeChord('Bb', 2)           // → 'C'
  /// ChordUtils.transposeChord('G', 3, useFlats: true)  // → 'Bb'
  /// ```
  static String transposeChord(
    String chord,
    int semitones, {
    bool useFlats = false,
  }) {
    if (semitones == 0 || chord.isEmpty) return chord;

    final notes = useFlats ? _flatNotes : _sharpNotes;

    // Acordes con nota en el bajo: "G/B" → transponer "G" y "B" por separado
    final slashIdx = chord.indexOf('/');
    if (slashIdx > 0) {
      final main = _transposeRootPart(chord.substring(0, slashIdx), semitones, notes);
      final bass = _transposeRootPart(chord.substring(slashIdx + 1), semitones, notes);
      return '$main/$bass';
    }

    return _transposeRootPart(chord, semitones, notes);
  }

  /// Transpone todos los acordes de [song] y devuelve un nuevo [Song].
  /// El [Song] original no se modifica (es inmutable).
  ///
  /// Si [semitones] es 0, devuelve el mismo objeto sin clonar.
  static Song transposeSong(
    Song song,
    int semitones, {
    bool useFlats = false,
  }) {
    if (semitones == 0) return song; // optimización: nada que hacer

    final newLines = song.lines.map((line) {
      // Solo las líneas de letra con acordes necesitan procesarse
      if (line.type != SongLineType.lyric || !line.hasChords) return line;

      final newSegments = line.segments.map((seg) {
        if (seg.chord == null) return seg;
        return ChordSegment(
          chord: transposeChord(seg.chord!, semitones, useFlats: useFlats),
          text: seg.text,
        );
      }).toList();

      return SongLine.lyric(newSegments);
    }).toList();

    return song.copyWith(
      lines: newLines,
      // También actualizamos la tonalidad en los metadatos
      key: song.key != null
          ? transposeChord(song.key!, semitones, useFlats: useFlats)
          : null,
    );
  }

  /// Devuelve true si la tonalidad [key] usa bemoles convencionalmente.
  /// Útil para elegir el valor por defecto de [useFlats] al abrir una canción.
  ///
  /// Tonalidades con bemoles: F, Bb, Eb, Ab, Db, Gb (mayores)
  ///                          Dm, Gm, Cm, Fm, Bbm, Ebm (menores)
  static bool keyPrefersFlats(String? key) {
    if (key == null) return false;
    const flatKeys = {
      'F', 'Bb', 'Eb', 'Ab', 'Db', 'Gb',
      'Dm', 'Gm', 'Cm', 'Fm', 'Bbm', 'Ebm',
    };
    return flatKeys.contains(key);
  }

  // ---------------------------------------------------------------------------
  // Helpers privados
  // ---------------------------------------------------------------------------

  /// Transpone la raíz de [chordPart] conservando su sufijo.
  static String _transposeRootPart(
    String chordPart,
    int semitones,
    List<String> notes,
  ) {
    final match = _rootRegex.firstMatch(chordPart);
    if (match == null) return chordPart; // no reconocido (ej: "N.C.", "X")

    final root = match.group(1)!;
    final suffix = match.group(2) ?? '';

    final semitone = _noteToSemitone(root);
    if (semitone < 0) return chordPart; // nota desconocida

    // La doble operación % asegura resultado positivo con semitones negativos.
    // En Dart, (-1 % 12) = -1, por eso sumamos 12 antes del segundo %.
    final newSemitone = ((semitone + semitones) % 12 + 12) % 12;
    return notes[newSemitone] + suffix;
  }

  /// Convierte el nombre de una nota a su índice de semitono (0–11).
  /// Devuelve -1 si la nota no es reconocida.
  static int _noteToSemitone(String note) {
    const map = {
      'C': 0,  'C#': 1, 'Db': 1,
      'D': 2,  'D#': 3, 'Eb': 3,
      'E': 4,
      'F': 5,  'F#': 6, 'Gb': 6,
      'G': 7,  'G#': 8, 'Ab': 8,
      'A': 9,  'A#': 10, 'Bb': 10,
      'B': 11,
    };
    return map[note] ?? -1;
  }
}
