// test/chordpro_parser_test.dart
//
// Ejecutar con: flutter test
// No requiere dispositivo ni emulador.

import 'package:flutter_test/flutter_test.dart';
import 'package:chord_viewer/models/song_line.dart';
import 'package:chord_viewer/services/chordpro_parser.dart';

void main() {
  // group() agrupa tests relacionados para que el output sea más legible
  group('ChordProParser — metadatos', () {
    test('extrae título y artista', () {
      const content = '''
{title: Amanecer}
{artist: Mi Banda}
''';
      final song = ChordProParser.parse(content);
      expect(song.title, 'Amanecer');
      expect(song.artist, 'Mi Banda');
    });

    test('acepta alias {t:} y {a:}', () {
      const content = '''
{t: Canción corta}
{a: Artista}
''';
      final song = ChordProParser.parse(content);
      expect(song.title, 'Canción corta');
      expect(song.artist, 'Artista');
    });

    test('extrae key, capo y tempo', () {
      const content = '''
{title: Test}
{key: Am}
{capo: 3}
{tempo: 90}
''';
      final song = ChordProParser.parse(content);
      expect(song.key, 'Am');
      expect(song.capo, 3);
      expect(song.tempo, 90);
    });

    test('valores por defecto cuando no hay metadatos', () {
      const content = '[G]Hola mundo\n';
      final song = ChordProParser.parse(content);
      expect(song.title, 'Sin título');
      expect(song.artist, 'Desconocido');
      expect(song.capo, 0);
      expect(song.tempo, isNull);
    });
  });

  group('ChordProParser — líneas de letra', () {
    test('parsea el ejemplo del enunciado completo', () {
      const content = '''
{title: Amanecer}
{artist: Mi Banda}

[G]Cuan[C]do el sol sa[D]le por el ho[G]rizonte
[Em]Todo [C]cambia de [D]co[G]lor
''';
      final song = ChordProParser.parse(content);
      expect(song.title, 'Amanecer');
      expect(song.artist, 'Mi Banda');

      final lyricsOnly =
          song.lines.where((l) => l.type == SongLineType.lyric).toList();
      expect(lyricsOnly.length, 2);

      // Primera línea: [G]Cuan[C]do el sol sa[D]le por el ho[G]rizonte
      final seg = lyricsOnly[0].segments;
      expect(seg[0].chord, 'G');
      expect(seg[0].text, 'Cuan');
      expect(seg[1].chord, 'C');
      expect(seg[1].text, 'do el sol sa');
      expect(seg[2].chord, 'D');
      expect(seg[2].text, 'le por el ho');
      expect(seg[3].chord, 'G');
      expect(seg[3].text, 'rizonte');
    });

    test('línea sin acordes produce un único segmento sin chord', () {
      const content = '{title: T}\nEsta línea no tiene acordes\n';
      final song = ChordProParser.parse(content);
      final line =
          song.lines.firstWhere((l) => l.type == SongLineType.lyric);
      expect(line.hasChords, false);
      expect(line.segments.length, 1);
      expect(line.segments[0].chord, isNull);
      expect(line.segments[0].text, 'Esta línea no tiene acordes');
    });

    test('texto antes del primer acorde se preserva', () {
      const content = '{title: T}\nIntro: [G]sol [C]luna\n';
      final song = ChordProParser.parse(content);
      final line =
          song.lines.firstWhere((l) => l.type == SongLineType.lyric);
      expect(line.segments[0].chord, isNull);
      expect(line.segments[0].text, 'Intro: ');
      expect(line.segments[1].chord, 'G');
    });

    test('acorde al final de línea (sin texto después) funciona', () {
      const content = '{title: T}\n[G]Hola [C]\n';
      final song = ChordProParser.parse(content);
      final line =
          song.lines.firstWhere((l) => l.type == SongLineType.lyric);
      expect(line.segments.last.chord, 'C');
      expect(line.segments.last.text, ''); // texto vacío es válido
    });

    test('hasChords devuelve true cuando hay al menos un acorde', () {
      const content = '{title: T}\n[Am]Verso\n';
      final song = ChordProParser.parse(content);
      expect(
          song.lines.firstWhere((l) => l.type == SongLineType.lyric).hasChords,
          true);
    });
  });

  group('ChordProParser — secciones', () {
    test('detecta {chorus} y {verse}', () {
      const content = '''
{title: T}
{chorus}
[G]Estribillo
{verse: Verso 1}
[Am]Letra
''';
      final song = ChordProParser.parse(content);
      final sections =
          song.lines.where((l) => l.type == SongLineType.section).toList();
      expect(sections.length, 2);
      expect(sections[0].sectionLabel, 'Estribillo');
      expect(sections[1].sectionLabel, 'Verso 1');
    });

    test('detecta {start_of_chorus}...{end_of_chorus}', () {
      const content = '''
{title: T}
{start_of_chorus}
[G]Estribillo
{end_of_chorus}
''';
      final song = ChordProParser.parse(content);
      final sections =
          song.lines.where((l) => l.type == SongLineType.section).toList();
      expect(sections.length, 1);
      expect(sections[0].sectionLabel, 'Estribillo');
    });

    test('detecta {comment:} como sección especial', () {
      const content = '''
{title: T}
{comment: Repetir 2 veces}
[G]Verso
''';
      final song = ChordProParser.parse(content);
      final sections =
          song.lines.where((l) => l.type == SongLineType.section).toList();
      expect(sections.any((s) => s.sectionLabel!.contains('Repetir 2 veces')),
          true);
    });
  });

  group('ChordProParser — líneas en blanco', () {
    test('las líneas en blanco se convierten en SongLineType.empty', () {
      const content = '''
{title: T}
[G]Verso

[Am]Estribillo
''';
      final song = ChordProParser.parse(content);
      expect(song.lines.any((l) => l.type == SongLineType.empty), true);
    });

    test('no hay líneas en blanco al final', () {
      const content = '{title: T}\n[G]Hola\n\n\n';
      final song = ChordProParser.parse(content);
      expect(song.lines.last.type, isNot(SongLineType.empty));
    });
  });

  group('ChordProParser — rawContent', () {
    test('rawContent preserva el texto original intacto', () {
      const content = '{title: Test}\n[G]Hola\n';
      final song = ChordProParser.parse(content);
      expect(song.rawContent, content);
    });
  });
}
