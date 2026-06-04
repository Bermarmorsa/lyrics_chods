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

class SetlistDetailScreen extends ConsumerStatefulWidget {
  final String setlistId;

  const SetlistDetailScreen({super.key, required this.setlistId});

  @override
  ConsumerState<SetlistDetailScreen> createState() =>
      _SetlistDetailScreenState();
}

class _SetlistDetailScreenState extends ConsumerState<SetlistDetailScreen> {
  final Set<String> _selectedIds = {};

  bool get _selectionMode => _selectedIds.isNotEmpty;

  void _enterSelection(String songId) {
    setState(() => _selectedIds.add(songId));
  }

  void _toggleSelection(String songId) {
    setState(() {
      if (_selectedIds.contains(songId)) {
        _selectedIds.remove(songId);
      } else {
        _selectedIds.add(songId);
      }
    });
  }

  void _cancelSelection() {
    setState(() => _selectedIds.clear());
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final setlists = ref.watch(setlistsProvider);
    final setlistMatches = setlists.where((s) => s.id == widget.setlistId);
    if (setlistMatches.isEmpty) {
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
    final library = ref.watch(libraryProvider);
    final songs = _resolveSongs(setlist.songIds, library);

    return Scaffold(
      backgroundColor: ViewerColors.background,
      appBar: _selectionMode
          ? _buildSelectionAppBar(setlist)
          : _buildNormalAppBar(context, setlist, songs, library),
      body: setlist.songIds.isEmpty
          ? _EmptySetlist(onAddTap: () => _showAddSheet(context, setlist))
          : ReorderableListView.builder(
              padding: EdgeInsets.only(bottom: _selectionMode ? 100 : 80),
              itemCount: songs.length,
              itemBuilder: (ctx, index) {
                final songId = setlist.songIds[index];
                return _SetlistSongTile(
                  key: ValueKey(songId),
                  position: index + 1,
                  summary: songs[index],
                  selectionMode: _selectionMode,
                  isSelected: _selectedIds.contains(songId),
                  onTap: _selectionMode
                      ? () => _toggleSelection(songId)
                      : () => _openSongAt(context, setlist, songs, index),
                  onLongPress: _selectionMode
                      ? null
                      : () => _enterSelection(songId),
                  onRemove: () => ref
                      .read(setlistsProvider.notifier)
                      .removeSong(setlist.id, songId),
                );
              },
              onReorder: _selectionMode
                  ? (_, __) {}
                  : (oldIndex, newIndex) {
                      ref
                          .read(setlistsProvider.notifier)
                          .reorderSongs(setlist.id, oldIndex, newIndex);
                    },
            ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddSheet(context, setlist),
              backgroundColor: ViewerColors.chord,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text('Añadir canción'),
            ),
      bottomNavigationBar: _selectionMode ? _buildSelectionBar(setlist) : null,
    );
  }

  // ---------------------------------------------------------------------------
  // AppBars
  // ---------------------------------------------------------------------------

  AppBar _buildNormalAppBar(
    BuildContext context,
    Setlist setlist,
    List<SongSummary?> songs,
    List<SongSummary> library,
  ) {
    return AppBar(
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
            onPressed: () => _exportSetlist(context, setlist, library),
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Empezar desde el principio',
            onPressed: () => _openSongAt(context, setlist, songs, 0),
          ),
        ],
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          tooltip: 'Eliminar setlist',
          onPressed: () => _showDeleteSetlistDialog(context, setlist),
        ),
      ],
    );
  }

  AppBar _buildSelectionAppBar(Setlist setlist) {
    return AppBar(
      backgroundColor: ViewerColors.background,
      foregroundColor: ViewerColors.title,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _cancelSelection,
      ),
      title: Text(
        '${_selectedIds.length} seleccionada${_selectedIds.length == 1 ? '' : 's'}',
        style: const TextStyle(color: ViewerColors.title),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _selectedIds.addAll(setlist.songIds);
            });
          },
          child: const Text('Todas',
              style: TextStyle(color: ViewerColors.chord)),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Barra inferior de selección
  // ---------------------------------------------------------------------------

  Widget _buildSelectionBar(Setlist setlist) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          border: Border(
              top: BorderSide(color: ViewerColors.separator, width: 1)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showDeleteSelectedDialog(setlist),
            icon: const Icon(Icons.delete_outline),
            label: Text(
              'Quitar ${_selectedIds.length} canción${_selectedIds.length == 1 ? '' : 'es'}',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------

  Future<void> _exportSetlist(
    BuildContext context,
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

  Future<void> _openSongAt(
    BuildContext context,
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final song = await FileService.loadSong(summary.filePath!);

    if (!context.mounted) return;
    Navigator.pop(context);

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

  void _showDeleteSetlistDialog(BuildContext context, Setlist setlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Eliminar setlist',
            style: TextStyle(color: ViewerColors.title)),
        content: Text(
          '¿Eliminar "${setlist.name}"?\n\n'
          'Las canciones de tu biblioteca no se borrarán.',
          style: const TextStyle(color: ViewerColors.artist),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(setlistsProvider.notifier).deleteSetlist(setlist.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteSelectedDialog(Setlist setlist) {
    final count = _selectedIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Quitar canciones',
            style: TextStyle(color: ViewerColors.title)),
        content: Text(
          '¿Quitar $count canción${count == 1 ? '' : 'es'} del setlist?\n\n'
          'Las canciones no se eliminarán de la biblioteca.',
          style: const TextStyle(color: ViewerColors.artist),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ids = _selectedIds.toList();
              for (final id in ids) {
                await ref
                    .read(setlistsProvider.notifier)
                    .removeSong(setlist.id, id);
              }
              _cancelSelection();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, Setlist setlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => _AddSongsSheet(
          setlist: setlist,
          scrollController: scrollController,
          onAddMultiple: (ids) async {
            for (final id in ids) {
              await ref
                  .read(setlistsProvider.notifier)
                  .addSong(setlist.id, id);
            }
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

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
  final SongSummary? summary;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onRemove;

  const _SetlistSongTile({
    super.key,
    required this.position,
    required this.summary,
    required this.selectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onRemove,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = summary != null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      tileColor: isSelected
          ? ViewerColors.chord.withValues(alpha: 0.12)
          : Colors.transparent,
      leading: selectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => onTap(),
              activeColor: ViewerColors.chord,
              side: const BorderSide(color: ViewerColors.separator),
            )
          : SizedBox(
              width: 32,
              child: Text(
                '$position',
                style: TextStyle(
                  color: isAvailable
                      ? ViewerColors.chord
                      : ViewerColors.separator,
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
              style:
                  const TextStyle(color: ViewerColors.artist, fontSize: 13),
            )
          : null,
      trailing: selectionMode
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: ViewerColors.separator, size: 20),
                  tooltip: 'Quitar del setlist',
                  onPressed: onRemove,
                ),
                ReorderableDragStartListener(
                  index: position - 1,
                  child: const Icon(Icons.drag_handle,
                      color: ViewerColors.separator),
                ),
              ],
            ),
      onTap: isAvailable ? onTap : null,
      onLongPress: onLongPress,
    );
  }
}

// ---------------------------------------------------------------------------
// Widget: bottom sheet para añadir canciones
// ---------------------------------------------------------------------------

class _AddSongsSheet extends ConsumerStatefulWidget {
  final Setlist setlist;
  final ScrollController scrollController;
  final Future<void> Function(List<String> songIds) onAddMultiple;

  const _AddSongsSheet({
    required this.setlist,
    required this.scrollController,
    required this.onAddMultiple,
  });

  @override
  ConsumerState<_AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends ConsumerState<_AddSongsSheet> {
  final Set<String> _selected = {};

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _confirm() async {
    final ids = _selected.toList();
    await widget.onAddMultiple(ids);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final available =
        library.where((s) => !widget.setlist.songIds.contains(s.id)).toList();

    return Column(
      children: [
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
                  controller: widget.scrollController,
                  itemCount: available.length,
                  itemBuilder: (_, index) {
                    final song = available[index];
                    final isSelected = _selected.contains(song.id);
                    return ListTile(
                      leading: const Icon(Icons.music_note,
                          color: ViewerColors.chord, size: 20),
                      title: Text(song.title,
                          style: const TextStyle(color: ViewerColors.lyric)),
                      subtitle: Text(song.artist,
                          style:
                              const TextStyle(color: ViewerColors.artist)),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggle(song.id),
                        activeColor: ViewerColors.chord,
                        side:
                            const BorderSide(color: ViewerColors.separator),
                      ),
                      onTap: () => _toggle(song.id),
                    );
                  },
                ),
        ),
        if (_selected.isNotEmpty) ...[
          Divider(color: ViewerColors.separator, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.playlist_add),
                label: Text(
                  'Añadir ${_selected.length} canción${_selected.length == 1 ? '' : 'es'}',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ViewerColors.chord,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
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
