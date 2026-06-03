// lib/screens/viewer/widgets/chord_line.dart

import 'package:flutter/material.dart';
import '../../../models/song_line.dart';
import '../../../core/theme/app_theme.dart';

/// Renderiza una línea de letra [SongLine] con acordes encima del texto.
///
/// Cada [ChordSegment] se muestra como una mini-columna:
///
///   G        Am7
///   Hola     mundo
///
/// Los segmentos se agrupan en un [Wrap] para que las líneas largas
/// se partan correctamente sin separar el acorde de su texto.
class ChordLine extends StatelessWidget {
  final SongLine line;
  final double fontSize;

  const ChordLine({super.key, required this.line, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    assert(line.type == SongLineType.lyric,
        'ChordLine solo acepta líneas de tipo lyric');

    final lyricStyle = ViewerTextStyles.lyric(fontSize);

    // Optimización: líneas sin acordes se renderizan como Text simple
    if (!line.hasChords) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(line.plainText, style: lyricStyle),
      );
    }

    final chordStyle = ViewerTextStyles.chord(fontSize);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Wrap(
        // WrapCrossAlignment.end alinea la base del texto de todos los segmentos
        crossAxisAlignment: WrapCrossAlignment.end,
        children: line.segments
            .map((s) => _ChordSegmentWidget(
                  segment: s,
                  chordStyle: chordStyle,
                  lyricStyle: lyricStyle,
                ))
            .toList(),
      ),
    );
  }
}

/// Muestra un par (acorde, texto) como una mini-columna de dos filas.
///
/// Si el segmento no tiene acorde, la fila superior se renderiza
/// con texto vacío para mantener la altura consistente con el resto
/// de la línea (todos los segmentos deben tener la misma altura total).
class _ChordSegmentWidget extends StatelessWidget {
  final ChordSegment segment;
  final TextStyle chordStyle;
  final TextStyle lyricStyle;

  const _ChordSegmentWidget({
    required this.segment,
    required this.chordStyle,
    required this.lyricStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Pequeño espacio a la derecha para que los acordes no se peguen
      padding: const EdgeInsets.only(right: 2),
      child: IntrinsicWidth(
        // IntrinsicWidth: la columna toma el ancho del hijo más ancho.
        // Sin esto, [Cmaj7] sobre 'a' haría que el acorde se solape
        // con el siguiente segmento.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fila del acorde — texto vacío si no hay acorde en esta posición,
            // pero la altura de la línea se conserva gracias al estilo.
            Text(
              segment.chord ?? '',
              style: chordStyle,
            ),
            // Fila de la letra
            Text(
              segment.text,
              style: lyricStyle,
            ),
          ],
        ),
      ),
    );
  }
}
