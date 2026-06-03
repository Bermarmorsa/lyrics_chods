// test/chord_utils_test.dart
// Ejecutar con: flutter test test/chord_utils_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:chord_viewer/core/utils/chord_utils.dart';
import 'package:chord_viewer/models/song_line.dart';
import 'package:chord_viewer/services/chordpro_parser.dart';

void main() {
  group('ChordUtils.transposeChord — casos básicos', () {
    test('0 semitonos devuelve el acorde original sin cambios', () {
      expect(ChordUtils.transposeChord('G', 0), 'G');
      expect(ChordUtils.transposeChord('Am7', 0), 'Am7');
    });

    test('sube 2 semitonos: G → A', () {
      expect(ChordUtils.transposeChord('G', 2), 'A');
    });

    test('baja 2 semitonos: A → G', () {
      expect(ChordUtils.transposeChord('A', -2), 'G');
    });

    test('envuelve hacia arriba: B +1 → C', () {
      expect(ChordUtils.transposeChord('B', 1), 'C');
    });

    test('envuelve hacia abajo: C -1 → B', () {
      expect(ChordUtils.transposeChord('C', -1), 'B');
    });

    test('más de una octava: G +14 = G +2 → A', () {
      expect(ChordUtils.transposeChord('G', 14), 'A');
    });

    test('más de una octava hacia abajo: G -14 = G -2 → F', () {
      expect(ChordUtils.transposeChord('G', -14), 'F');
    });
  });

  group('ChordUtils.transposeChord — sufijos', () {
    test('conserva el sufijo menor: Am → Bm (+2)', () {
      expect(ChordUtils.transposeChord('Am', 2), 'Bm');
    });

    test('conserva sufijos complejos: C#m7 -1 → Cm7', () {
      expect(ChordUtils.transposeChord('C#m7', -1), 'Cm7');
    });

    test('conserva sus4: Dsus4 +1 → Ebsus4 (con bemoles)', () {
      expect(ChordUtils.transposeChord('Dsus4', 1, useFlats: true), 'Ebsus4');
    });

    test('conserva maj7: Fmaj7 +2 → Gmaj7', () {
      expect(ChordUtils.transposeChord('Fmaj7', 2), 'Gmaj7');
    });
  });

  group('ChordUtils.transposeChord — sostenidos vs bemoles', () {
    test('G +3 con sostenidos → A#', () {
      expect(ChordUtils.transposeChord('G', 3, useFlats: false), 'A#');
    });

    test('G +3 con bemoles → Bb', () {
      expect(ChordUtils.transposeChord('G', 3, useFlats: true), 'Bb');
    });

    test('raíz con bemol: Bb +2 → C (sin accidental)', () {
      expect(ChordUtils.transposeChord('Bb', 2), 'C');
    });

    test('raíz con sostenido: F# +1 → G', () {
      expect(ChordUtils.transposeChord('F#', 1), 'G');
    });

    test('Eb (bemol) +2 → F', () {
      expect(ChordUtils.transposeChord('Eb', 2), 'F');
    });
  });

  group('ChordUtils.transposeChord — nota en el bajo (slash chords)', () {
    test('G/B +2 → A/C#', () {
      expect(ChordUtils.transposeChord('G/B', 2), 'A/C#');
    });

    test('C/E -1 → B/D#', () {
      expect(ChordUtils.transposeChord('C/E', -1), 'B/D#');
    });

    test('Am/G +2 → Bm/A', () {
      expect(ChordUtils.transposeChord('Am/G', 2), 'Bm/A');
    });
  });

  group('ChordUtils.transposeChord — acordes no reconocidos', () {
    test('N.C. se devuelve sin cambios', () {
      expect(ChordUtils.transposeChord('N.C.', 3), 'N.C.');
    });

    test('string vacío se devuelve sin cambios', () {
      expect(ChordUtils.transposeChord('', 3), '');
    });
  });

  // ---------------------------------------------------------------------------

  group('ChordUtils.transposeSong', () {
    test('0 semitonos devuelve el mismo objeto (sin clonar)', () {
      final song = ChordProParser.parse('{title: T}\n[G]Hola\n');
      final result = ChordUtils.transposeSong(song, 0);
      expect(identical(result, song), true);
    });

    test('transpone todos los acordes de la canción', () {
      const content = '''
{title: Test}
[G]Cuan[C]do [D]sale [Am]el sol
''';
      final song = ChordProParser.parse(content);
      final transposed = ChordUtils.transposeSong(song, 2);

      final line = transposed.lines
          .firstWhere((l) => l.type == SongLineType.lyric);
      expect(line.segments[0].chord, 'A');
      expect(line.segments[1].chord, 'D');
      expect(line.segments[2].chord, 'E');
      expect(line.segments[3].chord, 'Bm');
    });

    test('el texto de la letra no cambia', () {
      final song = ChordProParser.parse('{title: T}\n[G]Hola [Am]mundo\n');
      final transposed = ChordUtils.transposeSong(song, 5);

      final line = transposed.lines
          .firstWhere((l) => l.type == SongLineType.lyric);
      expect(line.segments[0].text, 'Hola ');
      expect(line.segments[1].text, 'mundo');
    });

    test('transpone la tonalidad en los metadatos', () {
      final song = ChordProParser.parse('{title: T}\n{key: G}\n[G]Hola\n');
      final transposed = ChordUtils.transposeSong(song, 2);
      expect(transposed.key, 'A');
    });

    test('las líneas sin acordes no se modifican', () {
      final song =
          ChordProParser.parse('{title: T}\nEsta línea no tiene acordes\n');
      final transposed = ChordUtils.transposeSong(song, 3);

      final line = transposed.lines
          .firstWhere((l) => l.type == SongLineType.lyric);
      expect(line.hasChords, false);
      expect(line.plainText, 'Esta línea no tiene acordes');
    });

    test('sube y baja la misma cantidad da el original', () {
      const content = '{title: T}\n[G]a [Am]b [C#m7]c\n';
      final song = ChordProParser.parse(content);
      final up = ChordUtils.transposeSong(song, 5);
      final down = ChordUtils.transposeSong(up, -5);

      final origLine =
          song.lines.firstWhere((l) => l.type == SongLineType.lyric);
      final roundLine =
          down.lines.firstWhere((l) => l.type == SongLineType.lyric);

      for (int i = 0; i < origLine.segments.length; i++) {
        expect(roundLine.segments[i].chord, origLine.segments[i].chord);
      }
    });
  });

  // ---------------------------------------------------------------------------

  group('ChordUtils.keyPrefersFlats', () {
    test('Bb prefiere bemoles', () {
      expect(ChordUtils.keyPrefersFlats('Bb'), true);
    });

    test('Eb prefiere bemoles', () {
      expect(ChordUtils.keyPrefersFlats('Eb'), true);
    });

    test('G no prefiere bemoles', () {
      expect(ChordUtils.keyPrefersFlats('G'), false);
    });

    test('null no prefiere bemoles', () {
      expect(ChordUtils.keyPrefersFlats(null), false);
    });

    test('Gm no prefiere bemoles (menor con sostenido)', () {
      expect(ChordUtils.keyPrefersFlats('Gm'), false);
    });

    test('Gm no prefiere bemoles (verificar que no se confunde)', () {
      expect(ChordUtils.keyPrefersFlats('Gm'), false);
    });
  });
}
