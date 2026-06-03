// lib/screens/library/widgets/song_tile.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/song_summary.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/library_provider.dart';
import '../../editor/editor_screen.dart';

/// Elemento de la lista de canciones en la biblioteca.
///
/// - Tap: navega a la canción (la pantalla padre gestiona la navegación)
/// - Long press: muestra diálogo de confirmación para eliminar
class SongTile extends ConsumerWidget {
  final SongSummary summary;

  /// Callback que la pantalla padre llama cuando el usuario toca el tile.
  /// Recibe el [SongSummary] seleccionado.
  final void Function(SongSummary) onTap;

  const SongTile({super.key, required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),

      // Icono de nota musical en el color de los acordes
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: ViewerColors.chord.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.music_note, color: ViewerColors.chord, size: 22),
      ),

      // Título de la canción
      title: Text(
        summary.title,
        style: const TextStyle(
          color: ViewerColors.title,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),

      // Artista y, si está disponible, tonalidad
      subtitle: _SubtitleRow(summary: summary),

      // Menú de opciones (solo eliminar por ahora)
      trailing: IconButton(
        icon: Icon(Icons.more_vert, color: ViewerColors.artist, size: 20),
        tooltip: 'Opciones',
        onPressed: () => _showOptions(context, ref),
      ),

      onTap: () => onTap(summary),
      onLongPress: () => _showDeleteDialog(context, ref),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (summary.filePath != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: ViewerColors.section),
                title: const Text('Editar canción',
                    style: TextStyle(color: ViewerColors.lyric)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditorScreen(summary: summary),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Eliminar de la biblioteca',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Eliminar canción',
            style: TextStyle(color: ViewerColors.title)),
        content: Text(
          '¿Eliminar "${summary.title}" de la biblioteca?\n\n'
          'El archivo del dispositivo no se borrará.',
          style: const TextStyle(color: ViewerColors.artist),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(libraryProvider.notifier).removeSong(summary.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// Fila de subtítulo: artista + chip de tonalidad
class _SubtitleRow extends StatelessWidget {
  final SongSummary summary;

  const _SubtitleRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              summary.artist,
              style: const TextStyle(color: ViewerColors.artist, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (summary.key != null) ...[
            const SizedBox(width: 8),
            _KeyChip(keyName: summary.key!),
          ],
        ],
      ),
    );
  }
}

// Chip pequeño para mostrar la tonalidad (ej: "G", "Am")
class _KeyChip extends StatelessWidget {
  final String keyName;

  const _KeyChip({required this.keyName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: ViewerColors.chord.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        keyName,
        style: const TextStyle(
          color: ViewerColors.chord,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
