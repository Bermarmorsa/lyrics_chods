// lib/screens/setlists/setlist_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/setlist.dart';
import '../../models/song_summary.dart';
import '../../providers/setlists_provider.dart';
import '../../providers/library_provider.dart';
import '../../services/file_service.dart';
import '../../services/setlist_export_service.dart';
import '../viewer/viewer_screen.dart';

/// Muestra las canciones de un setlist con posibilidad de:
///   - Reordenar arrastrando (drag & drop con [ReorderableListView])
///   - Eliminar canciones del setlist (botón ×)
///   - Añadir canciones desde la biblioteca (FAB → bottom sheet)
///   - Abrir el visor con contexto de setlist (tap)
class SetlistDetailScreen extends ConsumerWidget {
  /// Pasamos el ID en lugar del objeto para que la pantalla siempre
  /// refleje el estado más reciente del provider.
  final String setlistId;

  const SetlistDetailScreen({super.key, required this.setlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Obtenemos el setlist actualizado del provider en cada rebuild
    final setlists = ref.watch(setlistsProvider);
    final setlistMatches = setlists.where((s) => s.id == setlistId);
    if (setlistMatches.isEmpty) {
      // El setlist fue eliminado mientras esta pantalla estaba abierta
      return Scaffold(
        backgroundColor: ViewerColors.background,
        appBar: AppBar(backgroundColor: ViewerColors.background),
        body: const Center(
          child: Text('Este setlist ya no existe',
              style: TextStyle(color: ViewerColors.artist)),
        ),
      );
    }
    final setlist = setlistMatches.first;

    // Cruzamos los IDs del setlist con la biblioteca para obtener los datos
    final library = ref.watch(libraryProvider);
    final songs = _resolveSongs(setlist.songIds, library);

    return Scaffold(
      backgroundColor: ViewerColors.background,
      appBar: AppBar(
        backgroundColor: ViewerColors.background,
        foregroundColor: ViewerColors.title,
        elevation: 0,
        title: Text(
          setlist.name,
          style: const TextStyle(
              color: ViewerColors.title, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (setlist.songCount > 0) ...[
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Exportar setlist',
              onPressed: () => _exportSetlist(context, ref, setlist, library),
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Empezar desde el principio',
              onPressed: () => _openSongAt(context, ref, setlist, songs, 0),
            ),
          ],
        ],
      ),
      body: setlist.songIds.isEmpty
          ? _EmptySetlist(onAddTap: () => _showAddSheet(context, ref, setlist))
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: songs.length,
              // El key debe ser estable y único — usamos el ID de la canción
              itemBuilder: (ctx, index) => _SetlistSongTile(
                key: ValueKey(setlist.songIds[index]),
                position: index + 1,
                summary: songs[index],
                onTap: () => _openSongAt(context, ref, setlist, songs, index),
                onRemove: () => ref
                    .read(setlistsProvider.notifier)
                    .removeSong(setlist.id, setlist.songIds[index]),
              ),
              onReorder: (oldIndex, newIndex) {
                ref
                    .read(setlistsProvider.notifier)
                    .reorderSongs(setlist.id, oldIndex, newIndex);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref, setlist),
        backgroundColor: ViewerColors.chord,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Añadir canción'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Exportar setlist
  // ---------------------------------------------------------------------------

  Future<void> _exportSetlist(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
    List<SongSummary> library,
  ) async {
    try {
      await SetlistExportService.exportAndShare(setlist, library);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Abrir canción en el visor con contexto de setlist
  // ---------------------------------------------------------------------------

  Future<void> _openSongAt(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
    List<SongSummary?> songs,
    int index,
  ) async {
    final summary = songs[index];
    if (summary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Canción no encontrada en la biblioteca'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (summary.filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta canción no tiene archivo local'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Indicador de carga mientras se lee el archivo
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final song = await FileService.loadSong(summary.filePath!);

    if (!context.mounted) return;
    Navigator.pop(context); // cerrar indicador

    if (song == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cargar el archivo'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewerScreen(
          song: song,
          summary: summary,
          setlistContext: SetlistContext(
            setlist: setlist,
            currentIndex: index,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom sheet para añadir canciones desde la biblioteca
  // ---------------------------------------------------------------------------

  void _showAddSheet(BuildContext context, WidgetRef ref, Setlist setlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true, // ocupa hasta el 90% de la pantalla
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => _AddSongsSheet(
          setlist: setlist,
          scrollController: scrollController,
          onAdd: (songId) async {
            await ref
                .read(setlistsProvider.notifier)
                .addSong(setlist.id, songId);
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Resuelve los IDs del setlist a objetos [SongSummary] de la biblioteca.
  /// Si un ID no existe en la biblioteca, devuelve null en esa posición.
  static List<SongSummary?> _resolveSongs(
    List<String> songIds,
    List<SongSummary> library,
  ) {
    return songIds.map((id) {
      final matches = library.where((s) => s.id == id);
      return matches.isEmpty ? null : matches.first;
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// Widget: fila de canción en el setlist
// ---------------------------------------------------------------------------

class _SetlistSongTile extends StatelessWidget {
  final int position;
  final SongSummary? summary; // null si la canción ya no está en la biblioteca
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SetlistSongTile({
    super.key,
    required this.position,
    required this.summary,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = summary != null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      // Número de posición en el setlist
      leading: SizedBox(
        width: 32,
        child: Text(
          '$position',
          style: TextStyle(
            color: isAvailable ? ViewerColors.chord : ViewerColors.separator,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      title: Text(
        summary?.title ?? '(canción no disponible)',
        style: TextStyle(
          color: isAvailable ? ViewerColors.title : ViewerColors.separator,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: summary != null
          ? Text(
              summary!.artist,
              style: const TextStyle(
                  color: ViewerColors.artist, fontSize: 13),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón de eliminar del setlist
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: ViewerColors.separator, size: 20),
            tooltip: 'Quitar del setlist',
            onPressed: onRemove,
          ),
          // Handle de arrastre (ReorderableListView lo usa para reordenar)
          ReorderableDragStartListener(
            index: position - 1,
            child: const Icon(Icons.drag_handle,
                color: ViewerColors.separator),
          ),
        ],
      ),
      onTap: isAvailable ? onTap : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Widget: bottom sheet para añadir canciones
// ---------------------------------------------------------------------------

class _AddSongsSheet extends ConsumerWidget {
  final Setlist setlist;
  final ScrollController scrollController;
  final Future<void> Function(String songId) onAdd;

  const _AddSongsSheet({
    required this.setlist,
    required this.scrollController,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    // Solo mostrar canciones que aún no están en el setlist
    final available =
        library.where((s) => !setlist.songIds.contains(s.id)).toList();

    return Column(
      children: [
        // Barra de título
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Text(
                'Añadir al setlist',
                style: TextStyle(
                    color: ViewerColors.title,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: ViewerColors.artist),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Divider(color: ViewerColors.separator, height: 1),
        // Lista de canciones disponibles
        Expanded(
          child: available.isEmpty
              ? const Center(
                  child: Text(
                    'Todas las canciones ya están en este setlist',
                    style: TextStyle(color: ViewerColors.artist),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  itemCount: available.length,
                  itemBuilder: (_, index) {
                    final song = available[index];
                    return ListTile(
                      leading: const Icon(Icons.music_note,
                          color: ViewerColors.chord, size: 20),
                      title: Text(song.title,
                          style: const TextStyle(color: ViewerColors.lyric)),
                      subtitle: Text(song.artist,
                          style:
                              const TextStyle(color: ViewerColors.artist)),
                      trailing: const Icon(Icons.add_circle_outline,
                          color: ViewerColors.chord),
                      onTap: () async {
                        await onAdd(song.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EmptySetlist extends StatelessWidget {
  final VoidCallback onAddTap;
  const _EmptySetlist({required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.playlist_add,
              size: 64, color: ViewerColors.separator),
          const SizedBox(height: 16),
          const Text('Setlist vacío',
              style: TextStyle(color: ViewerColors.artist, fontSize: 16)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onAddTap,
            icon: const Icon(Icons.add),
            label: const Text('Añadir canciones'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ViewerColors.chord,
              side: const BorderSide(color: ViewerColors.chord),
            ),
          ),
        ],
      ),
    );
  }
}
