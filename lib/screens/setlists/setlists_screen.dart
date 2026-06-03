// lib/screens/setlists/setlists_screen.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/setlists_provider.dart';
import '../../providers/library_provider.dart';
import '../../models/setlist.dart';
import '../../services/setlist_export_service.dart';
import 'setlist_detail_screen.dart';

/// Pantalla con la lista de todos los setlists del usuario.
///
/// - FAB: crear nuevo setlist (diálogo con nombre)
/// - Tap: abrir [SetlistDetailScreen]
/// - Long press: renombrar o eliminar
class SetlistsScreen extends ConsumerWidget {
  const SetlistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlists = ref.watch(setlistsProvider);

    return Scaffold(
      backgroundColor: ViewerColors.background,
      appBar: AppBar(
        backgroundColor: ViewerColors.background,
        foregroundColor: ViewerColors.title,
        elevation: 0,
        title: const Text(
          'Setlists',
          style: TextStyle(color: ViewerColors.title, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Importar setlist',
            onPressed: () => _importSetlist(context, ref),
          ),
        ],
      ),
      body: setlists.isEmpty
          ? _EmptyState(onCreateTap: () => _showCreateDialog(context, ref))
          : ListView.separated(
              itemCount: setlists.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: ViewerColors.separator),
              itemBuilder: (_, index) => _SetlistTile(
                setlist: setlists[index],
                onTap: () => _openSetlist(context, setlists[index]),
                onLongPress: () =>
                    _showOptionsSheet(context, ref, setlists[index]),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        backgroundColor: ViewerColors.chord,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo setlist'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Importar setlist
  // ---------------------------------------------------------------------------

  Future<void> _importSetlist(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    try {
      final importResult = await SetlistExportService.importFromFile(path);

      // Recargar biblioteca con las canciones importadas
      ref.read(libraryProvider.notifier).reloadAll();

      // Crear el setlist e insertar canciones
      final setlist = await ref
          .read(setlistsProvider.notifier)
          .createSetlist(importResult.name);

      for (final songId in importResult.songIds) {
        await ref
            .read(setlistsProvider.notifier)
            .addSong(setlist.id, songId);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${importResult.name}" importado · '
            '${importResult.added} nueva${importResult.added == 1 ? '' : 's'}'
            '${importResult.skipped > 0 ? ', ${importResult.skipped} ya existía${importResult.skipped == 1 ? '' : 'n'}' : ''}',
          ),
          backgroundColor: ViewerColors.chord,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al importar: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Navegación
  // ---------------------------------------------------------------------------

  void _openSetlist(BuildContext context, Setlist setlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SetlistDetailScreen(setlistId: setlist.id),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Diálogos
  // ---------------------------------------------------------------------------

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    _showNameDialog(
      context: context,
      title: 'Nuevo setlist',
      hint: 'Concierto Madrid, Ensayo martes…',
      confirmLabel: 'Crear',
      onConfirm: (name) async {
        await ref.read(setlistsProvider.notifier).createSetlist(name);
      },
    );
  }

  void _showOptionsSheet(
      BuildContext context, WidgetRef ref, Setlist setlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: ViewerColors.section),
              title: const Text('Renombrar',
                  style: TextStyle(color: ViewerColors.lyric)),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, ref, setlist);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Eliminar',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, ref, setlist);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(
      BuildContext context, WidgetRef ref, Setlist setlist) {
    _showNameDialog(
      context: context,
      title: 'Renombrar setlist',
      initialValue: setlist.name,
      hint: 'Nombre del setlist',
      confirmLabel: 'Guardar',
      onConfirm: (name) async {
        await ref
            .read(setlistsProvider.notifier)
            .renameSetlist(setlist.id, name);
      },
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, Setlist setlist) {
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
              ref
                  .read(setlistsProvider.notifier)
                  .deleteSetlist(setlist.id);
              Navigator.pop(ctx);
            },
            style:
                TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  /// Diálogo genérico para introducir un nombre de texto.
  void _showNameDialog({
    required BuildContext context,
    required String title,
    required String hint,
    required String confirmLabel,
    required Future<void> Function(String) onConfirm,
    String initialValue = '',
  }) {
    final controller = TextEditingController(text: initialValue);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(title,
            style: const TextStyle(color: ViewerColors.title)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: ViewerColors.lyric),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: ViewerColors.artist),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: ViewerColors.separator)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: ViewerColors.chord)),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              onConfirm(value);
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onConfirm(controller.text);
                Navigator.pop(ctx);
              }
            },
            style: TextButton.styleFrom(foregroundColor: ViewerColors.chord),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets privados
// ---------------------------------------------------------------------------

class _SetlistTile extends StatelessWidget {
  final Setlist setlist;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SetlistTile({
    required this.setlist,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: ViewerColors.section.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.queue_music,
            color: ViewerColors.section, size: 22),
      ),
      title: Text(
        setlist.name,
        style: const TextStyle(
          color: ViewerColors.title,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        '${setlist.songCount} canción${setlist.songCount == 1 ? '' : 'es'}',
        style: const TextStyle(color: ViewerColors.artist, fontSize: 13),
      ),
      trailing: const Icon(Icons.chevron_right,
          color: ViewerColors.separator, size: 20),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;

  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.queue_music_outlined,
                size: 64, color: ViewerColors.separator),
            const SizedBox(height: 16),
            const Text(
              'Sin setlists aún',
              style: TextStyle(
                  color: ViewerColors.artist,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea tu primer setlist para\norganizar el repertorio de un concierto',
              style:
                  TextStyle(color: ViewerColors.separator, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Crear setlist'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ViewerColors.chord,
                side: const BorderSide(color: ViewerColors.chord),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
