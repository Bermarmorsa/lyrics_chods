// lib/services/chordpro_parser.dart

import '../models/song.dart';
import '../models/song_line.dart';

/// Parsea texto en formato ChordPro y produce un objeto [Song].
///
/// ## Formato soportado
///
/// **Directivas de metadatos** (al principio del archivo):
///   {title: Nombre}   · {t: Nombre}
///   {artist: Banda}   · {a: Banda}  · {subtitle: Banda}
///   {key: G}          · {capo: 2}   · {tempo: 120}
///
/// **Directivas de sección** (marcan bloques dentro de la canción):
///   {verse}  · {verse: Verso 1}
///   {chorus} · {chorus: Estribillo}
///   {bridge}
///   {start_of_verse}  ... {end_of_verse}   (o abreviado {sov}/{eov})
///   {start_of_chorus} ... {end_of_chorus}  (o {soc}/{eoc})
///   {start_of_bridge} ... {end_of_bridge}  (o {sob}/{eob})
///   {comment: Nota visible al músico}
///
/// **Líneas de letra**:
///   [G]Hola [Am]mundo  →  texto con acordes intercalados
///   Solo texto          →  línea de letra sin acordes
///   (línea vacía)       →  separador visual entre estrofas
class ChordProParser {
  // Detecta directivas: {clave} o {clave: valor}
  // Grupos: 1=clave, 2=valor (opcional)
  static final _directiveRegex = RegExp(r'^\{(\w+)(?::\s*(.*?))?\s*\}$');

  // Detecta pares [acorde]texto dentro de una línea
  // Grupos: 1=acorde, 2=texto que sigue al acorde
  static final _chordPattern = RegExp(r'\[([^\]]*)\]([^\[]*)');

  /// Parsea [content] (texto ChordPro) y devuelve un [Song].
  ///
  /// [filePath] es opcional: si se provee, se usa como base para el ID.
  static Song parse(String content, {String? filePath}) {
    // Valores por defecto de los metadatos
    String title = 'Sin título';
    String artist = 'Desconocido';
    String? key;
    int capo = 0;
    int? tempo;

    final songLines = <SongLine>[];

    for (final rawLine in content.split('\n')) {
      // Quitar \r (saltos de línea de Windows) y espacios al final
      final line = rawLine.trimRight();

      // --- Línea en blanco ---
      if (line.trim().isEmpty) {
        // Evitamos añadir vacíos al principio de la lista
        if (songLines.isNotEmpty) {
          songLines.add(SongLine.empty());
        }
        continue;
      }

      // --- ¿Es una directiva? ---
      final directiveMatch = _directiveRegex.firstMatch(line.trim());
      if (directiveMatch != null) {
        final directive = directiveMatch.group(1)!.toLowerCase();
        final value = (directiveMatch.group(2) ?? '').trim();

        _handleDirective(
          directive: directive,
          value: value,
          songLines: songLines,
          // Callbacks para actualizar metadatos
          onTitle: (v) => title = v,
          onArtist: (v) => artist = v,
          onKey: (v) => key = v,
          onCapo: (v) => capo = v,
          onTempo: (v) => tempo = v,
        );
        continue;
      }

      // --- Línea de letra (con o sin acordes) ---
      songLines.add(_parseLyricLine(line));
    }

    return Song(
      id: _generateId(title, artist, filePath),
      title: title,
      artist: artist,
      key: key,
      capo: capo,
      tempo: tempo,
      lines: _trimTrailingEmpties(songLines),
      rawContent: content,
      filePath: filePath,
    );
  }

  // ---------------------------------------------------------------------------
  // Manejo de directivas
  // ---------------------------------------------------------------------------

  static void _handleDirective({
    required String directive,
    required String value,
    required List<SongLine> songLines,
    required void Function(String) onTitle,
    required void Function(String) onArtist,
    required void Function(String?) onKey,
    required void Function(int) onCapo,
    required void Function(int?) onTempo,
  }) {
    switch (directive) {
      // --- Metadatos ---
      case 'title' || 't':
        if (value.isNotEmpty) onTitle(value);

      case 'artist' || 'a' || 'subtitle':
        // 'subtitle' es usado por algunas herramientas como campo de artista
        if (value.isNotEmpty) onArtist(value);

      case 'key':
        onKey(value.isNotEmpty ? value : null);

      case 'capo':
        onCapo(int.tryParse(value) ?? 0);

      case 'tempo':
        onTempo(int.tryParse(value));

      // --- Secciones simples (sin bloque start/end) ---
      case 'verse':
        songLines.add(SongLine.section(value.isNotEmpty ? value : 'Verso'));

      case 'chorus':
        songLines.add(SongLine.section(value.isNotEmpty ? value : 'Estribillo'));

      case 'bridge':
        songLines.add(SongLine.section(value.isNotEmpty ? value : 'Puente'));

      case 'intro':
        songLines.add(SongLine.section('Intro'));

      case 'outro':
        songLines.add(SongLine.section('Outro'));

      case 'tag':
        songLines.add(SongLine.section(value.isNotEmpty ? value : 'Tag'));

      case 'pre-chorus' || 'prechorus':
        songLines.add(SongLine.section(value.isNotEmpty ? value : 'Pre-estribillo'));

      // --- Secciones con bloque start/end ---
      // Cuando el archivo usa {start_of_chorus}...{end_of_chorus},
      // solo añadimos la cabecera al encontrar el "start".
      // El "end" lo ignoramos: la siguiente sección o línea en blanco ya separa.
      case 'start_of_verse' || 'sov':
        songLines.add(SongLine.section(value.isNotEmpty ? value : 'Verso'));

      case 'start_of_chorus' || 'soc':
        songLines.add(SongLine.section(value.isNotEmpty ? value : 'Estribillo'));

      case 'start_of_bridge' || 'sob':
        songLines.add(SongLine.section(value.isNotEmpty ? value : 'Puente'));

      case 'start_of_tab' || 'sot':
        songLines.add(SongLine.section('Tab'));

      case 'end_of_verse' ||
            'eov' ||
            'end_of_chorus' ||
            'eoc' ||
            'end_of_bridge' ||
            'eob' ||
            'end_of_tab' ||
            'eot':
        // No hacemos nada; la estructura visual ya viene dada por las líneas
        break;

      // --- Comentarios visibles al músico ---
      case 'comment' || 'c' || 'comment_italic' || 'ci' || 'comment_box' || 'cb':
        if (value.isNotEmpty) {
          // Usamos el prefijo ► para que la UI lo diferencie visualmente
          songLines.add(SongLine.section('► $value'));
        }

      // Cualquier otra directiva (define, textsize, etc.) se ignora
      default:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Parseo de líneas de letra
  // ---------------------------------------------------------------------------

  /// Convierte una línea de texto ChordPro en un [SongLine] de tipo lyric.
  ///
  /// Algoritmo:
  /// 1. Si no hay '[', es texto puro → un único segmento sin acorde.
  /// 2. Si hay texto antes del primer '[', se añade como segmento sin acorde.
  /// 3. Se extraen todos los pares [acorde]texto con regex.
  ///
  /// Ejemplo: "[G]Hola [Am]mundo" →
  ///   [ ChordSegment('G', 'Hola '), ChordSegment('Am', 'mundo') ]
  static SongLine _parseLyricLine(String line) {
    if (!line.contains('[')) {
      // Texto puro, sin acordes
      return SongLine.lyric([ChordSegment(text: line)]);
    }

    final segments = <ChordSegment>[];

    // Texto antes del primer '[': p.ej. "Intro: [G]..." → "Intro: " sin acorde
    final firstBracket = line.indexOf('[');
    if (firstBracket > 0) {
      segments.add(ChordSegment(text: line.substring(0, firstBracket)));
    }

    // Extraer todos los pares [acorde]texto
    for (final match in _chordPattern.allMatches(line)) {
      final chordStr = match.group(1)!.trim();
      final text = match.group(2)!;

      // Si el acorde está vacío (p.ej. "[]texto"), lo tratamos como sin acorde
      segments.add(ChordSegment(
        chord: chordStr.isNotEmpty ? chordStr : null,
        text: text,
      ));
    }

    return SongLine.lyric(segments);
  }

  // ---------------------------------------------------------------------------
  // Utilidades
  // ---------------------------------------------------------------------------

  /// Genera un ID estable para la canción.
  /// Prioriza el path del archivo; si no hay, usa título+artista.
  ///
  /// Nota: hashCode de Dart no es criptográfico pero es suficiente como ID local.
  static String _generateId(String title, String artist, String? filePath) {
    if (filePath != null && filePath.isNotEmpty) {
      return filePath.hashCode.abs().toString();
    }
    return '${title}_$artist'.hashCode.abs().toString();
  }

  /// Elimina las líneas en blanco al final de la lista (limpieza estética).
  static List<SongLine> _trimTrailingEmpties(List<SongLine> lines) {
    var end = lines.length;
    while (end > 0 && lines[end - 1].type == SongLineType.empty) {
      end--;
    }
    return lines.sublist(0, end);
  }
}
