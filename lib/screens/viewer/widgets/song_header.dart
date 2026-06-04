// lib/screens/viewer/widgets/song_header.dart

import 'package:flutter/material.dart';
import '../../../models/song.dart';
import '../../../core/theme/app_theme.dart';

/// Muestra el título, artista y metadatos opcionales (tonalidad, cejilla)
/// de la canción al inicio de la pantalla de visualización.
class SongHeader extends StatelessWidget {
  final Song song;
  final double fontSize;
  final bool compact;

  const SongHeader({
    super.key,
    required this.song,
    required this.fontSize,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(song.title, style: ViewerTextStyles.songTitle(fontSize)),
          const SizedBox(height: 4),
          Text(song.artist, style: ViewerTextStyles.songArtist(fontSize)),
          if (song.key != null || song.capo > 0) ...[
            const SizedBox(height: 8),
            _MetaChips(song: song, fontSize: fontSize),
          ],
          const SizedBox(height: 20),
          Divider(color: ViewerColors.separator, thickness: 1),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCompact() {
    final parts = <String>[song.title];
    if (song.artist.isNotEmpty) parts.add(song.artist);
    if (song.key != null) parts.add(song.key!);
    if (song.capo > 0) parts.add('Cejilla ${song.capo}');

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parts.join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ViewerColors.artist,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Divider(color: ViewerColors.separator, thickness: 1),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Fila con chips pequeños para tonalidad y cejilla.
class _MetaChips extends StatelessWidget {
  final Song song;
  final double fontSize;

  const _MetaChips({required this.song, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        if (song.key != null)
          _MetaChip(label: 'Tonalidad: ${song.key}', fontSize: fontSize),
        if (song.capo > 0)
          _MetaChip(label: 'Cejilla: ${song.capo}', fontSize: fontSize),
        if (song.tempo != null)
          _MetaChip(label: '${song.tempo} BPM', fontSize: fontSize),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final double fontSize;

  const _MetaChip({required this.label, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: ViewerColors.separator,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: ViewerColors.artist,
          fontSize: fontSize * 0.65,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
