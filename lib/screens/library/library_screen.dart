// lib/screens/library/library_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/song_summary.dart';
import '../../providers/library_provider.dart';
import '../../services/file_service.dart';
import '../viewer/viewer_screen.dart';
import '../drive/drive_screen.dart';
import '../editor/editor_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/song_tile.dart';

/// Pantalla principal de la app: muestra la biblioteca de canciones.
///
/// - Barra de búsqueda para filtrar por título o artista
/// - FAB para importar archivos .cho/.chordpro desde el dispositivo
/// - Navega a [ViewerScreen] al seleccionar una canción
///
/// Usa [ConsumerStatefulWidget] porque necesita estado local para:
///   - El texto de búsqueda ([TextEditingController])
///   - El indicador de carga mientras se importa ([_isImporting])
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isImporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ref.watch() → se reconstruye automáticamente cuando cambia la lista
    final allSongs = ref.watch(libraryProvider);

    // Filtrar por título o artista según el texto de búsqueda
    final filtered = _searchQuery.isEmpty
        ? allSongs
        : allSongs.where((s) {
            final q = _searchQuery.toLowerCase();
            return s.title.toLowerCase().contains(q) ||
                s.artist.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: ViewerColors.background,
      appBar: AppBar(
        backgroundColor: ViewerColors.background,
        foregroundColor: ViewerColors.title,
        elevation: 0,
        title: const Text(
          'Chord Viewer',
          style: TextStyle(color: ViewerColors.title, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined),
            tooltip: 'Google Drive',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DriveScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          _SearchBar(
            controller: _searchController,
            onChanged: (q) => setState(() => _searchQuery = q),
          ),

          // Divisor sutil
          Divider(height: 1, color: ViewerColors.separator),

          // Cuerpo: lista o estado vacío
          Expanded(
            child: filtered.isEmpty
                ? _EmptyState(hasQuery: _searchQuery.isNotEmpty)
                : _SongList(songs: filtered, onTap: _openSong),
          ),
        ],
      ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'fab_nueva',
            onPressed: _newSong,
            backgroundColor: ViewerColors.section,
            foregroundColor: Colors.white,
            tooltip: 'Nueva canción',
            child: const Icon(Icons.edit_note),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'fab_importar',
            onPressed: _isImporting ? null : _importSongs,
            backgroundColor: ViewerColors.chord,
            foregroundColor: Colors.black,
            icon: _isImporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.add),
            label: Text(_isImporting ? 'Importando…' : 'Importar'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------

  void _newSong() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditorScreen()),
    );
  }

  Future<void> _importSongs() async {
    setState(() => _isImporting = true);
    try {
      final count =
          await ref.read(libraryProvider.notifier).importSongs();
      if (mounted && count > 0) {
        _showSnackBar('$count canción${count == 1 ? '' : 'es'} importada${count == 1 ? '' : 's'}');
      } else if (mounted && count == 0) {
        // El usuario canceló o todos los archivos ya estaban importados
        // No mostramos mensaje para no interrumpir el flujo
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error al importar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _openSong(SongSummary summary) async {
    if (summary.filePath == null) {
      _showSnackBar('Esta canción no tiene archivo local', isError: true);
      return;
    }

    // Mostrar indicador de carga mientras se lee y parsea el archivo
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final song = await FileService.loadSong(summary.filePath!);

    if (!mounted) return;
    Navigator.pop(context); // cerrar el indicador de carga

    if (song == null) {
      _showSnackBar(
        'No se encontró el archivo. ¿Fue movido o borrado?',
        isError: true,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ViewerScreen(song: song, summary: summary)),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : ViewerColors.chord,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets privados
// ---------------------------------------------------------------------------

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: ViewerColors.lyric),
        decoration: InputDecoration(
          hintText: 'Buscar por título o artista…',
          hintStyle: const TextStyle(color: ViewerColors.artist),
          prefixIcon: const Icon(Icons.search, color: ViewerColors.artist),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon:
                      const Icon(Icons.clear, color: ViewerColors.artist, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }
}

class _SongList extends StatelessWidget {
  final List<SongSummary> songs;
  final void Function(SongSummary) onTap;

  const _SongList({required this.songs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: songs.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, indent: 72, color: ViewerColors.separator),
      itemBuilder: (_, index) =>
          SongTile(summary: songs[index], onTap: onTap),
    );
  }
}

class _EmptyState extends StatelessWidget {
  /// True si hay una búsqueda activa que no dio resultados.
  final bool hasQuery;

  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.library_music_outlined,
              size: 64,
              color: ViewerColors.separator,
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery
                  ? 'Sin resultados para la búsqueda'
                  : 'Tu biblioteca está vacía',
              style: const TextStyle(
                  color: ViewerColors.artist,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            if (!hasQuery) ...[
              const SizedBox(height: 8),
              const Text(
                'Toca el botón "Importar" para añadir\narchivos .cho o .chordpro',
                style: TextStyle(color: ViewerColors.separator, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
