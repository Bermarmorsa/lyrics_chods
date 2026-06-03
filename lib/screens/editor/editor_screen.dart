// lib/screens/editor/editor_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/song_summary.dart';
import '../../providers/library_provider.dart';
import '../../services/file_service.dart';

/// Pantalla para crear o editar una canción en formato ChordPro.
///
/// - [summary] == null → nueva canción (se crea el archivo al guardar)
/// - [summary] != null → editar canción existente (sobreescribe el archivo)
class EditorScreen extends ConsumerStatefulWidget {
  final SongSummary? summary;

  const EditorScreen({super.key, this.summary});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late final TextEditingController _controller;
  bool _loading = true;
  bool _saving = false;

  static const _template =
      '{title: Nueva Canción}\n'
      '{artist: Artista}\n'
      '{key: C}\n'
      '{tempo: 120}\n'
      '\n'
      '{sop: Verso}\n'
      '[C]Letra con [Am]acorde encima [F]de cada [G]sílaba\n'
      '\n'
      '{sop: Estribillo}\n'
      '[C]Aquí va el [G]estribillo\n'
      '[Am]con sus [F]acordes\n';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadContent();
  }

  Future<void> _loadContent() async {
    String content = _template;
    final path = widget.summary?.filePath;
    if (path != null) {
      try {
        content = await File(path).readAsString();
      } catch (_) {}
    }
    _controller.text = content;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.summary == null;
    return Scaffold(
      backgroundColor: ViewerColors.background,
      appBar: AppBar(
        backgroundColor: ViewerColors.background,
        foregroundColor: ViewerColors.title,
        elevation: 0,
        title: Text(
          isNew ? 'Nueva canción' : 'Editar canción',
          style: const TextStyle(color: ViewerColors.title, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Sintaxis ChordPro',
            onPressed: _showHelp,
          ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: ViewerColors.chord),
                  )
                : const Icon(Icons.save_outlined),
            tooltip: 'Guardar',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ViewerColors.chord))
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  color: ViewerColors.lyric,
                  fontFamily: 'monospace',
                  fontSize: 14,
                  height: 1.5,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Escribe el contenido ChordPro…',
                  hintStyle: TextStyle(color: ViewerColors.artist),
                ),
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                autocorrect: false,
                enableSuggestions: false,
              ),
            ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final content = _controller.text;
      final song = widget.summary?.filePath != null
          ? await FileService.saveRawContent(widget.summary!.filePath!, content)
          : await FileService.createSong(content);

      final summary = SongSummary.fromSong(song);
      await ref.read(libraryProvider.notifier).addSong(summary);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardado correctamente'),
          backgroundColor: ViewerColors.chord,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (widget.summary == null) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showHelp() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _HelpSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Hoja de ayuda de sintaxis ChordPro
// ---------------------------------------------------------------------------

class _HelpSheet extends StatelessWidget {
  const _HelpSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ViewerColors.separator,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Sintaxis ChordPro',
              style: TextStyle(
                color: ViewerColors.title,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: const [
                _HelpSection('Metadatos'),
                _HelpRow('{title: Nombre}', 'Título de la canción'),
                _HelpRow('{artist: Artista}', 'Artista o banda'),
                _HelpRow('{key: Am}', 'Tonalidad original'),
                _HelpRow('{capo: 2}', 'Cejilla en traste 2'),
                _HelpRow('{tempo: 120}', 'Tempo en BPM'),
                SizedBox(height: 16),
                _HelpSection('Acordes'),
                _HelpRow('[G]', 'Acorde encima de la sílaba'),
                _HelpRow('[Am7]', 'Acorde con sufijo'),
                _HelpRow('[C/E]', 'Acorde con bajo específico'),
                _HelpRow('[F#m]', 'Acorde con sostenido o bemol'),
                SizedBox(height: 16),
                _HelpSection('Secciones'),
                _HelpRow('{sop: Verso}', 'Sección con nombre personalizado'),
                _HelpRow('{verse}', 'Verso estándar'),
                _HelpRow('{chorus}', 'Estribillo estándar'),
                _HelpRow('{bridge}', 'Puente'),
                _HelpRow('{sop: Intro}', 'Introducción'),
                SizedBox(height: 16),
                _HelpSection('Otros'),
                _HelpRow('{comment: texto}', 'Línea de comentario'),
                _HelpRow('# texto', 'Comentario (ignorado al parsear)'),
                SizedBox(height: 16),
                _HelpSection('Ejemplo completo'),
                _ExampleBox(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final String title;
  const _HelpSection(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: ViewerColors.chord,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  final String code;
  final String description;
  const _HelpRow(this.code, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              code,
              style: const TextStyle(
                color: ViewerColors.section,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                description,
                style: const TextStyle(color: ViewerColors.artist, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleBox extends StatelessWidget {
  const _ExampleBox();

  static const _example =
      '{title: La Bamba}\n'
      '{artist: Ritchie Valens}\n'
      '{key: A}\n'
      '\n'
      '{sop: Verso}\n'
      '[A]Para bailar [D]la bamba\n'
      '[A]Para bailar [D]la bamba\n'
      '\n'
      '{sop: Estribillo}\n'
      '[A]Bamba [D]bamba\n'
      '[E7]Ay [A]arriba\n';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ViewerColors.separator),
      ),
      child: Text(
        _example,
        style: const TextStyle(
          color: ViewerColors.lyric,
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.6,
        ),
      ),
    );
  }
}
