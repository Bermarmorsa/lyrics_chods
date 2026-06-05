// lib/screens/concerts/concerts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/concert_recording.dart';
import '../../providers/concerts_provider.dart';
import '../../services/concert_service.dart';
import 'concert_detail_screen.dart';

class ConcertsScreen extends ConsumerWidget {
  const ConcertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncConcerts = ref.watch(concertsProvider);

    return Scaffold(
      backgroundColor: ViewerColors.background,
      appBar: AppBar(
        backgroundColor: ViewerColors.background,
        foregroundColor: ViewerColors.title,
        elevation: 0,
        title: const Text(
          'Conciertos',
          style: TextStyle(
              color: ViewerColors.title, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Importar concierto',
            onPressed: () => _importConcert(context, ref),
          ),
        ],
      ),
      body: asyncConcerts.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: ViewerColors.artist)),
        ),
        data: (concerts) => concerts.isEmpty
            ? const _EmptyConcerts()
            : ListView.builder(
                itemCount: concerts.length,
                itemBuilder: (ctx, i) => _ConcertTile(
                  recording: concerts[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ConcertDetailScreen(recording: concerts[i]),
                    ),
                  ),
                  onDelete: () =>
                      _confirmDelete(context, ref, concerts[i]),
                  onExport: () =>
                      ConcertService.exportAndShare(concerts[i]),
                ),
              ),
      ),
    );
  }

  Future<void> _importConcert(BuildContext context, WidgetRef ref) async {
    final recording =
        await ref.read(concertsProvider.notifier).importFile();
    if (!context.mounted) return;
    if (recording == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo importar el archivo'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Concierto "${recording.name}" importado'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, ConcertRecording recording) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Eliminar concierto',
            style: TextStyle(color: ViewerColors.title)),
        content: Text(
          '¿Eliminar "${recording.name}"?',
          style: const TextStyle(color: ViewerColors.artist),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(concertsProvider.notifier).delete(recording.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ConcertTile extends StatelessWidget {
  final ConcertRecording recording;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  const _ConcertTile({
    required this.recording,
    required this.onTap,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final duration = _formatDuration(recording.durationMs);
    final date = _formatDate(recording.startTime);

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: ViewerColors.chord.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.mic, color: ViewerColors.chord, size: 22),
      ),
      title: Text(
        recording.name,
        style: const TextStyle(
            color: ViewerColors.title, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${recording.setlistName}  ·  $date  ·  $duration',
        style:
            const TextStyle(color: ViewerColors.artist, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<_TileAction>(
        icon: const Icon(Icons.more_vert, color: ViewerColors.separator),
        color: const Color(0xFF1E1E1E),
        onSelected: (action) {
          if (action == _TileAction.export) onExport();
          if (action == _TileAction.delete) onDelete();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _TileAction.export,
            child: Row(
              children: [
                Icon(Icons.ios_share, color: ViewerColors.artist, size: 18),
                SizedBox(width: 10),
                Text('Exportar',
                    style: TextStyle(color: ViewerColors.lyric)),
              ],
            ),
          ),
          PopupMenuItem(
            value: _TileAction.delete,
            child: Row(
              children: [
                Icon(Icons.delete_outline,
                    color: Colors.redAccent, size: 18),
                SizedBox(width: 10),
                Text('Eliminar',
                    style: TextStyle(color: Colors.redAccent)),
              ],
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  static String _formatDuration(int ms) {
    final minutes = ms ~/ 60000;
    final seconds = (ms % 60000) ~/ 1000;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

enum _TileAction { export, delete }

// ---------------------------------------------------------------------------

class _EmptyConcerts extends StatelessWidget {
  const _EmptyConcerts();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_none, size: 64, color: ViewerColors.separator),
          SizedBox(height: 16),
          Text(
            'Sin conciertos grabados',
            style: TextStyle(color: ViewerColors.artist, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Graba un concierto desde el detalle de un setlist',
            style: TextStyle(color: ViewerColors.separator, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
