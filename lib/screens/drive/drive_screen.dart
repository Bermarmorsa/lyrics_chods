// lib/screens/drive/drive_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/drive_file.dart';
import '../../providers/drive_provider.dart';

/// Pantalla para conectarse a Google Drive e importar archivos ChordPro.
///
/// Estados posibles:
///   - Cargando (comprobando sesión guardada)
///   - Desconectado → botón "Conectar con Google"
///   - Conectado → lista de archivos con búsqueda e importación
class DriveScreen extends ConsumerStatefulWidget {
  const DriveScreen({super.key});

  @override
  ConsumerState<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends ConsumerState<DriveScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  // IDs de archivos en proceso de descarga
  final _importingIds = <String>{};
  // IDs de archivos ya importados en esta sesión (para mostrar ✓)
  final _importedIds = <String>{};

  @override
  void initState() {
    super.initState();
    // Si ya estamos conectados pero no tenemos archivos, cargarlos automáticamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final driveState = ref.read(driveProvider).valueOrNull;
      if (driveState?.isConnected == true && driveState?.files.isEmpty == true) {
        ref.read(driveProvider.notifier).loadFiles();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driveAsync = ref.watch(driveProvider);

    return Scaffold(
      backgroundColor: ViewerColors.background,
      appBar: AppBar(
        backgroundColor: ViewerColors.background,
        foregroundColor: ViewerColors.title,
        elevation: 0,
        title: const Text('Google Drive',
            style: TextStyle(
                color: ViewerColors.title, fontWeight: FontWeight.bold)),
        actions: [
          // Recargar lista — solo si conectado
          if (driveAsync.valueOrNull?.isConnected == true)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar lista',
              onPressed: () =>
                  ref.read(driveProvider.notifier).loadFiles(),
            ),
        ],
      ),
      body: driveAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          message: e.toString(),
          onRetry: () => ref.invalidate(driveProvider),
        ),
        data: (state) => state.isConnected
            ? _buildConnectedBody(state)
            : _buildDisconnectedBody(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cuerpos según el estado de conexión
  // ---------------------------------------------------------------------------

  Widget _buildDisconnectedBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off,
                size: 72, color: ViewerColors.separator),
            const SizedBox(height: 20),
            const Text(
              'Conecta con Google Drive',
              style: TextStyle(
                  color: ViewerColors.title,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Importa tus archivos .cho y .chordpro\ndirectamente desde tu Drive.\n\n'
              'La app solo lee archivos — nunca\nmodifica tu Drive.',
              style:
                  TextStyle(color: ViewerColors.artist, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _signIn,
              icon: const Icon(Icons.login),
              label: const Text('Conectar con Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ViewerColors.chord,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedBody(DriveState state) {
    // Filtrar por búsqueda
    final filtered = _query.isEmpty
        ? state.files
        : state.files
            .where((f) =>
                f.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Column(
      children: [
        // Cabecera de cuenta
        _AccountHeader(
          account: state.account!.displayName ?? state.account!.email,
          email: state.account!.email,
          photoUrl: state.account!.photoUrl,
          onSignOut: _signOut,
        ),

        // Barra de búsqueda
        _SearchBar(
          controller: _searchCtrl,
          onChanged: (q) => setState(() => _query = q),
        ),

        // Fila de estadísticas + "Importar todos"
        if (!state.isLoadingFiles && state.files.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
            child: Row(
              children: [
                Text(
                  '${filtered.length} archivo${filtered.length == 1 ? '' : 's'} en Drive',
                  style: const TextStyle(
                      color: ViewerColors.artist, fontSize: 12),
                ),
                const Spacer(),
                if (filtered.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _importAll(filtered),
                    icon: const Icon(Icons.download_for_offline,
                        size: 16, color: ViewerColors.chord),
                    label: const Text('Importar todos',
                        style: TextStyle(
                            color: ViewerColors.chord, fontSize: 13)),
                  ),
              ],
            ),
          ),

        Divider(height: 1, color: ViewerColors.separator),

        // Lista de archivos
        Expanded(
          child: state.isLoadingFiles
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Buscando archivos en Drive…',
                          style:
                              TextStyle(color: ViewerColors.artist)),
                    ],
                  ),
                )
              : state.files.isEmpty
                  ? _EmptyDriveBody(
                      onRefresh: () =>
                          ref.read(driveProvider.notifier).loadFiles(),
                    )
                  : filtered.isEmpty
                      ? const Center(
                          child: Text('Sin resultados',
                              style: TextStyle(
                                  color: ViewerColors.artist)),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => Divider(
                              height: 1, color: ViewerColors.separator),
                          itemBuilder: (_, i) => _DriveFileTile(
                            file: filtered[i],
                            isImporting:
                                _importingIds.contains(filtered[i].id),
                            isImported:
                                _importedIds.contains(filtered[i].id),
                            onImport: () => _importFile(filtered[i]),
                          ),
                        ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------

  Future<void> _signIn() async {
    try {
      await ref.read(driveProvider.notifier).signIn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al conectar: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _signOut() async {
    await ref.read(driveProvider.notifier).signOut();
    setState(() {
      _importingIds.clear();
      _importedIds.clear();
    });
  }

  Future<void> _importFile(DriveFile file) async {
    if (_importingIds.contains(file.id)) return; // evitar doble tap

    setState(() => _importingIds.add(file.id));
    try {
      final ok =
          await ref.read(driveProvider.notifier).importFile(file);
      if (!mounted) return;

      setState(() {
        _importingIds.remove(file.id);
        if (ok) _importedIds.add(file.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Importado: ${file.name}'
            : 'No se pudo parsear ${file.name}'),
        backgroundColor:
            ok ? ViewerColors.chord : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _importingIds.remove(file.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error importando ${file.name}: $e'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _importAll(List<DriveFile> files) async {
    for (final file in files) {
      if (!_importedIds.contains(file.id)) {
        await _importFile(file);
      }
    }
  }
}

// =============================================================================
// Widgets privados
// =============================================================================

class _AccountHeader extends StatelessWidget {
  final String account;
  final String email;
  final String? photoUrl;
  final VoidCallback onSignOut;

  const _AccountHeader({
    required this.account,
    required this.email,
    required this.photoUrl,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl!) : null,
            backgroundColor: ViewerColors.chord.withValues(alpha: 0.3),
            child: photoUrl == null
                ? const Icon(Icons.person,
                    color: ViewerColors.chord, size: 18)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account,
                    style: const TextStyle(
                        color: ViewerColors.title,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(email,
                    style: const TextStyle(
                        color: ViewerColors.artist, fontSize: 11)),
              ],
            ),
          ),
          TextButton(
            onPressed: onSignOut,
            style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Desconectar', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: ViewerColors.lyric),
        decoration: InputDecoration(
          hintText: 'Buscar en Drive…',
          hintStyle: const TextStyle(color: ViewerColors.artist),
          prefixIcon:
              const Icon(Icons.search, color: ViewerColors.artist),
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding: EdgeInsets.zero,
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear,
                      color: ViewerColors.artist, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
        ),
      ),
    );
  }
}

class _DriveFileTile extends StatelessWidget {
  final DriveFile file;
  final bool isImporting;
  final bool isImported;
  final VoidCallback onImport;

  const _DriveFileTile({
    required this.file,
    required this.isImporting,
    required this.isImported,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: const Icon(Icons.music_note, color: ViewerColors.chord),
      title: Text(
        file.name,
        style: const TextStyle(color: ViewerColors.lyric, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: file.formattedSize.isNotEmpty
          ? Text(file.formattedSize,
              style: const TextStyle(
                  color: ViewerColors.separator, fontSize: 12))
          : null,
      trailing: isImported
          ? const Icon(Icons.check_circle, color: Colors.green, size: 22)
          : isImporting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: ViewerColors.chord),
                )
              : IconButton(
                  icon: const Icon(Icons.download,
                      color: ViewerColors.chord),
                  tooltip: 'Importar a la biblioteca',
                  onPressed: onImport,
                ),
    );
  }
}

class _EmptyDriveBody extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyDriveBody({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_done,
              size: 64, color: ViewerColors.separator),
          const SizedBox(height: 16),
          const Text('No se encontraron archivos .cho o .chordpro',
              style: TextStyle(
                  color: ViewerColors.artist, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
              'Sube tus archivos ChordPro a Google Drive\ny vuelve a intentarlo.',
              style: TextStyle(
                  color: ViewerColors.separator, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Buscar de nuevo'),
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

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(
                    color: ViewerColors.artist, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                  foregroundColor: ViewerColors.chord,
                  side: const BorderSide(color: ViewerColors.chord)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
