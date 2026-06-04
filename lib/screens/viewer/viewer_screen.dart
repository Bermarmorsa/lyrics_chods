// lib/screens/viewer/viewer_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song.dart';
import '../../models/song_line.dart';
import '../../models/song_summary.dart';
import '../../models/setlist.dart';
import '../../models/pedal_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/chord_utils.dart';
import '../../providers/settings_provider.dart';
import '../../providers/library_provider.dart';
import '../../services/file_service.dart';
import 'widgets/chord_line.dart';
import 'widgets/song_header.dart';

/// Pantalla de visualización de una canción con soporte para:
///   - Transposición en tiempo real (no modifica el archivo)
///   - Navegación por pedal Bluetooth (PageUp/PageDown)
///   - Contexto de setlist (posición y botones prev/next)
///   - Modo inmersivo (tap para ocultar/mostrar la UI)
class ViewerScreen extends ConsumerStatefulWidget {
  final Song song;
  final SongSummary? summary;
  final SetlistContext? setlistContext;
  final bool scrollToEnd;

  /// Estado inicial de la UI (AppBar + barra de transposición).
  /// Se pasa al navegar entre canciones del setlist para mantener el modo inmersivo.
  final bool initialShowUi;

  const ViewerScreen({
    super.key,
    required this.song,
    this.summary,
    this.setlistContext,
    this.scrollToEnd = false,
    this.initialShowUi = true,
  });

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  final _scrollController = ScrollController();
  late bool _showUi;
  bool _isNavigating = false;

  // --- Transposición ---
  int _transpose = 0;
  bool _useFlats = false;

  // --- Auto-ajuste de fuente ---
  double? _autoFitMultiplier;
  bool _autoFitDone = false;

  // --- Botones de scroll táctiles ---
  bool _scrollButtonsVisible = false;
  Timer? _hideButtonsTimer;

  // --- Marcadores de avance (posiciones documento donde se hizo page-down) ---
  final List<double> _advanceMarkers = [];

  static const double _baseFontSize = 22.0;
  List<_SectionTarget> _sectionTargets = [];

  @override
  void initState() {
    super.initState();
    _showUi = widget.initialShowUi;
    _useFlats = ChordUtils.keyPrefersFlats(widget.song.key);
    if (!_showUi) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    if (widget.scrollToEnd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _hideButtonsTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;

    // El override de la canción tiene prioridad sobre el ajuste global
    final effectiveAutoFit = widget.summary?.autoFitScreens ?? settings.autoFitScreens;
    final effectiveMultiplier = (effectiveAutoFit != null && _autoFitMultiplier != null)
        ? _autoFitMultiplier!
        : settings.fontSizeMultiplier;
    final fontSize = (isTablet ? _baseFontSize * 1.3 : _baseFontSize) * effectiveMultiplier;

    // Programar auto-fit tras el primer frame si está activo y no se ha calculado
    if (effectiveAutoFit != null && !_autoFitDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _doAutoFit(effectiveAutoFit, settings.fontSizeMultiplier, isTablet);
      });
    }
    final hPadding = isTablet ? 48.0 : 20.0;

    // Aplicar transposición — si es 0 devuelve el mismo objeto sin clonar
    final displaySong = ChordUtils.transposeSong(
      widget.song,
      _transpose,
      useFlats: _useFlats,
    );

    // Los offsets de sección se calculan sobre la estructura (no cambia con transposición)
    _sectionTargets = _computeSectionTargets(
      widget.song,
      fontSize: fontSize,
      topPadding: 24.0,
    );

    return Scaffold(
      backgroundColor: ViewerColors.background,
      appBar: _showUi ? _buildAppBar(settings, displaySong, effectiveAutoFit) : null,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleImmersive,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(hPadding, 24, hPadding, 80),
                    itemCount: displaySong.lines.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return SongHeader(
                          song: displaySong,
                          fontSize: fontSize * 0.5,
                          compact: !_showUi,
                        );
                      }
                      return _buildLine(displaySong.lines[index - 1], fontSize);
                    },
                  ),
                ),
                // Bandas de solape (solo cuando auto-fit está activo)
                if (effectiveAutoFit != null)
                  AnimatedBuilder(
                    animation: _scrollController,
                    builder: (_, __) {
                      final offset = _scrollController.hasClients
                          ? _scrollController.offset
                          : 0.0;
                      final maxExtent = _scrollController.hasClients
                          ? _scrollController.position.maxScrollExtent
                          : double.infinity;
                      return _OverlapBands(
                        viewportHeight: constraints.maxHeight,
                        overlapFraction: _overlapFraction,
                        advanceMarkers: List.unmodifiable(_advanceMarkers),
                        scrollOffset: offset,
                        atEnd: offset >= maxExtent - 10,
                      );
                    },
                  ),

                // Botón táctil superior-derecha: retroceder
                Positioned(
                  top: 12,
                  right: 12,
                  child: _ScrollOverlayButton(
                    icon: Icons.keyboard_arrow_up_rounded,
                    visible: _scrollButtonsVisible,
                    onPressed: () => _onScrollButtonPressed(isForward: false),
                  ),
                ),

                // Botón táctil inferior-derecha: avanzar
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: _ScrollOverlayButton(
                    icon: Icons.keyboard_arrow_down_rounded,
                    visible: _scrollButtonsVisible,
                    onPressed: () => _onScrollButtonPressed(isForward: true),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Botones táctiles de scroll (overlay)
  // ---------------------------------------------------------------------------

  void _onScrollButtonPressed({required bool isForward}) {
    if (!_scrollButtonsVisible) {
      // Primer toque: solo revelar los botones
      setState(() => _scrollButtonsVisible = true);
      _resetHideTimer();
      return;
    }
    // Botones ya visibles: ejecutar el scroll
    final pedal = ref.read(settingsProvider).pedal;
    if (isForward) {
      _scrollForward(pedal);
    } else {
      _scrollBackward(pedal);
    }
    _resetHideTimer();
  }

  void _resetHideTimer() {
    _hideButtonsTimer?.cancel();
    _hideButtonsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _scrollButtonsVisible = false);
    });
  }

  // ---------------------------------------------------------------------------
  // Auto-ajuste de tamaño de letra
  // ---------------------------------------------------------------------------

  // 10% de solape entre pantallas consecutivas
  static const double _overlapFraction = 0.10;

  void _doAutoFit(int targetScreens, double baseMultiplier, bool isTablet) {
    if (!mounted || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final viewportH = pos.viewportDimension;
    final totalH = pos.maxScrollExtent + viewportH;
    if (totalH <= 0 || viewportH <= 0) return;

    // Con 10% de solape, N pantallas cubren: viewport * (1 + (N-1) * (1 - overlap))
    final scrollStep = 1 - _overlapFraction;
    final targetH = viewportH * (1 + (targetScreens - 1) * scrollStep);

    final base = isTablet ? _baseFontSize * 1.3 : _baseFontSize;
    final currentFontSize = base * (_autoFitMultiplier ?? baseMultiplier);
    final newFontSize = currentFontSize * (targetH / totalH);
    final newMultiplier = (newFontSize / base).clamp(0.3, 3.0);

    setState(() {
      _autoFitMultiplier = newMultiplier;
      _autoFitDone = true;
    });
  }

  // ---------------------------------------------------------------------------
  // AppBar con dos filas: título/navegación + barra de transposición
  // ---------------------------------------------------------------------------

  AppBar _buildAppBar(AppSettings settings, Song displaySong, int? effectiveAutoFit) {
    final sl = widget.setlistContext;

    return AppBar(
      backgroundColor: ViewerColors.background,
      foregroundColor: ViewerColors.title,
      elevation: 0,
      // Fila 1: título de la canción (o info del setlist)
      title: sl != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(sl.setlist.name,
                    style: const TextStyle(
                        fontSize: 10, color: ViewerColors.separator)),
                Text(
                  '${widget.song.title}  ·  ${sl.positionText}',
                  style: const TextStyle(
                      fontSize: 12, color: ViewerColors.artist),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          : Text(widget.song.title,
              style: const TextStyle(fontSize: 12, color: ViewerColors.artist),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      actions: [
        if (sl != null) ...[
          IconButton(
            icon: const Icon(Icons.skip_previous),
            tooltip: 'Canción anterior',
            onPressed:
                sl.hasPrev && !_isNavigating ? _goToPrevSong : null,
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            tooltip: 'Siguiente canción',
            onPressed:
                sl.hasNext && !_isNavigating ? _goToNextSong : null,
          ),
        ],
        if (widget.summary != null)
          _AutoFitChip(
            songAutoFit: widget.summary!.autoFitScreens,
            globalAutoFit: settings.autoFitScreens,
            onChanged: (screens) => ref
                .read(libraryProvider.notifier)
                .updateSongAutoFit(widget.summary!.id, screens),
          ),
        _PedalModeChip(settings: settings.pedal),
        IconButton(
          icon: const Icon(Icons.fullscreen),
          tooltip: 'Modo inmersivo',
          onPressed: _toggleImmersive,
        ),
      ],
      // Fila 2: controles de transposición
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: _TransposeBar(
          transpose: _transpose,
          useFlats: _useFlats,
          originalKey: widget.song.key,
          transposedKey: displaySong.key,
          onDecrement: () => setState(() => _transpose--),
          onIncrement: () => setState(() => _transpose++),
          onReset: () => setState(() => _transpose = 0),
          onToggleFlats: () => setState(() => _useFlats = !_useFlats),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Construcción de líneas
  // ---------------------------------------------------------------------------

  Widget _buildLine(SongLine line, double fontSize) {
    return switch (line.type) {
      SongLineType.section => _SectionLabel(
          label: line.sectionLabel!,
          fontSize: fontSize,
        ),
      SongLineType.lyric => ChordLine(line: line, fontSize: fontSize),
      SongLineType.empty => SizedBox(height: fontSize * 0.9),
    };
  }

  // ---------------------------------------------------------------------------
  // Pedal Bluetooth
  // ---------------------------------------------------------------------------

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final pedal = ref.read(settingsProvider).pedal;
    if (event.logicalKey == pedal.nextKey) {
      _scrollForward(pedal);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == pedal.prevKey) {
      _scrollBackward(pedal);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scrollForward(PedalSettings pedal) {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    // Al llegar al final: pasar a la siguiente canción del setlist
    if (pos.pixels >= pos.maxScrollExtent - 8) {
      final sl = widget.setlistContext;
      if (sl != null && sl.hasNext && !_isNavigating) {
        _navigateToSongAt(sl.currentIndex + 1);
        return;
      }
    }

    if (pedal.scrollMode == PedalScrollMode.bySection &&
        _sectionTargets.isNotEmpty) {
      final threshold = pos.pixels + pos.viewportDimension * 0.10;
      final next = _sectionTargets.firstWhere(
        (t) => t.offset > threshold,
        orElse: () => _sectionTargets.last,
      );
      _animateTo(next.offset);
    } else {
      // Con auto-fit activo: avanzar 90% (10% de solape); si no, usar ajuste manual
      final settings = ref.read(settingsProvider);
      final effectiveAutoFit = widget.summary?.autoFitScreens ?? settings.autoFitScreens;
      final fraction = effectiveAutoFit != null
          ? (1 - _overlapFraction)
          : pedal.scrollFraction;
      final target = pos.pixels + pos.viewportDimension * fraction;
      // Registrar posición de avance para la banda deslizante
      if (effectiveAutoFit != null) {
        final clamped = target.clamp(0.0, pos.maxScrollExtent);
        if (clamped > 0 && !_advanceMarkers.contains(clamped)) {
          setState(() => _advanceMarkers.add(clamped));
        }
      }
      _animateTo(target);
    }
  }

  void _scrollBackward(PedalSettings pedal) {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    // Al estar al inicio: ir al final de la canción anterior del setlist
    if (pos.pixels <= 8) {
      final sl = widget.setlistContext;
      if (sl != null && sl.hasPrev && !_isNavigating) {
        _navigateToSongAt(sl.currentIndex - 1, scrollToEnd: true);
        return;
      }
    }

    if (pedal.scrollMode == PedalScrollMode.bySection &&
        _sectionTargets.isNotEmpty) {
      final threshold = pos.pixels - pos.viewportDimension * 0.10;
      final prev = _sectionTargets.lastWhere(
        (t) => t.offset < threshold,
        orElse: () => _sectionTargets.first,
      );
      _animateTo(prev.offset);
    } else {
      final settings = ref.read(settingsProvider);
      final effectiveAutoFit = widget.summary?.autoFitScreens ?? settings.autoFitScreens;
      final fraction = effectiveAutoFit != null
          ? (1 - _overlapFraction)
          : pedal.scrollFraction;
      _animateTo(pos.pixels - pos.viewportDimension * fraction);
    }
  }

  void _animateTo(double offset) {
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  // ---------------------------------------------------------------------------
  // Navegación de setlist
  // ---------------------------------------------------------------------------

  void _goToNextSong() =>
      _navigateToSongAt(widget.setlistContext!.currentIndex + 1);
  void _goToPrevSong() =>
      _navigateToSongAt(widget.setlistContext!.currentIndex - 1);

  Future<void> _navigateToSongAt(int newIndex, {bool scrollToEnd = false}) async {
    if (_isNavigating) return;
    final sl = widget.setlistContext!;
    final songId = sl.setlist.songIds[newIndex];

    setState(() => _isNavigating = true);

    final library = ref.read(libraryProvider);
    final matches = library.where((s) => s.id == songId);
    if (matches.isEmpty) {
      _showError('Canción no encontrada en la biblioteca');
      setState(() => _isNavigating = false);
      return;
    }
    final summary = matches.first;

    if (summary.filePath == null) {
      _showError('Esta canción no tiene archivo local');
      setState(() => _isNavigating = false);
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final song = await FileService.loadSong(summary.filePath!);

    if (!mounted) return;
    Navigator.pop(context);

    if (song == null) {
      _showError('No se pudo cargar el archivo');
      setState(() => _isNavigating = false);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ViewerScreen(
          song: song,
          summary: summary,
          setlistContext: sl.withIndex(newIndex),
          scrollToEnd: scrollToEnd,
          initialShowUi: _showUi,
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating),
    );
  }

  // ---------------------------------------------------------------------------
  // Estimación de offsets de sección (para modo bySection del pedal)
  // ---------------------------------------------------------------------------

  static List<_SectionTarget> _computeSectionTargets(
    Song song, {
    required double fontSize,
    required double topPadding,
  }) {
    final headerH = fontSize * 1.2 * 1.2 + 4 + fontSize * 0.85 * 1.4 +
        20 + 1 + 16 + 8;
    double y = topPadding + headerH;
    final targets = <_SectionTarget>[];

    for (final line in song.lines) {
      switch (line.type) {
        case SongLineType.section:
          targets.add(_SectionTarget(offset: y, label: line.sectionLabel!));
          y += fontSize * 0.9 + fontSize * 0.72 * 1.2 + fontSize * 0.3;
        case SongLineType.lyric:
          y += line.hasChords
              ? (fontSize * 0.70 + fontSize * 1.25) * 1.05 + 2
              : fontSize * 1.25 * 1.05 + 2;
        case SongLineType.empty:
          y += fontSize * 0.9;
      }
    }
    return targets;
  }

  // ---------------------------------------------------------------------------
  // Modo inmersivo
  // ---------------------------------------------------------------------------

  void _toggleImmersive() {
    setState(() => _showUi = !_showUi);
    SystemChrome.setEnabledSystemUIMode(
      _showUi ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }
}

// =============================================================================
// Barra de transposición (segunda fila del AppBar)
// =============================================================================

/// Controles de transposición que aparecen debajo del AppBar.
///
///  [▼]  G → A (+2 semit.)  [▲]       [♭ bemoles]
///
/// - Toca el texto central para resetear a 0
/// - El botón derecho alterna entre sostenidos (♯) y bemoles (♭)
class _TransposeBar extends StatelessWidget {
  final int transpose;
  final bool useFlats;
  final String? originalKey;
  final String? transposedKey;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onReset;
  final VoidCallback onToggleFlats;

  const _TransposeBar({
    required this.transpose,
    required this.useFlats,
    required this.originalKey,
    required this.transposedKey,
    required this.onDecrement,
    required this.onIncrement,
    required this.onReset,
    required this.onToggleFlats,
  });

  @override
  Widget build(BuildContext context) {
    final isTransposed = transpose != 0;
    final sign = transpose > 0 ? '+' : '';

    return Container(
      height: 48,
      color: ViewerColors.background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botón bajar un semitono
          _BarIconButton(
            icon: Icons.remove,
            onTap: onDecrement,
            tooltip: '−1 semitono',
          ),

          // Indicador central — muestra el offset y la tonalidad resultante
          // Tap para resetear a 0
          GestureDetector(
            onTap: isTransposed ? onReset : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isTransposed
                    ? ViewerColors.chord.withValues(alpha: 0.15)
                    : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isTransposed
                      ? ViewerColors.chord
                      : ViewerColors.separator,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _buildLabel(sign),
                    style: TextStyle(
                      color: isTransposed
                          ? ViewerColors.chord
                          : ViewerColors.artist,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (isTransposed) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.close,
                        size: 12, color: ViewerColors.chord),
                  ],
                ],
              ),
            ),
          ),

          // Botón subir un semitono
          _BarIconButton(
            icon: Icons.add,
            onTap: onIncrement,
            tooltip: '+1 semitono',
          ),

          const SizedBox(width: 8),

          // Toggle sostenidos / bemoles
          GestureDetector(
            onTap: onToggleFlats,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ViewerColors.separator),
              ),
              child: Text(
                useFlats ? '♭ bemoles' : '♯ sost.',
                style: const TextStyle(
                    color: ViewerColors.artist, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildLabel(String sign) {
    if (transpose == 0) return '0 semit.';
    // Si tenemos tonalidad: mostrar "G → A (+2)"
    if (originalKey != null && transposedKey != null && transpose != 0) {
      return '$originalKey → $transposedKey ($sign$transpose)';
    }
    return '$sign$transpose semit.';
  }
}

class _BarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _BarIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: ViewerColors.artist, size: 20),
        ),
      ),
    );
  }
}

// =============================================================================
// Widgets privados de layout
// =============================================================================

class _SectionLabel extends StatelessWidget {
  final String label;
  final double fontSize;

  const _SectionLabel({required this.label, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: fontSize * 0.9, bottom: fontSize * 0.3),
      child:
          Text(label.toUpperCase(), style: ViewerTextStyles.section(fontSize)),
    );
  }
}

class _PedalModeChip extends StatelessWidget {
  final PedalSettings settings;

  const _PedalModeChip({required this.settings});

  @override
  Widget build(BuildContext context) {
    final isBySection = settings.scrollMode == PedalScrollMode.bySection;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: ViewerColors.chord.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isBySection ? Icons.playlist_play : Icons.swap_vert,
                  size: 14, color: ViewerColors.chord),
              const SizedBox(width: 4),
              Text(
                isBySection ? 'Sección' : 'Página',
                style: const TextStyle(
                    color: ViewerColors.chord,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTarget {
  final double offset;
  final String label;
  const _SectionTarget({required this.offset, required this.label});
}

// Botón semitransparente de scroll táctil
class _ScrollOverlayButton extends StatelessWidget {
  final IconData icon;
  final bool visible;
  final VoidCallback onPressed;

  const _ScrollOverlayButton({
    required this.icon,
    required this.visible,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedOpacity(
        opacity: visible ? 0.55 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

// Bandas laterales que marcan la zona de solape entre pantallas.
// La banda inferior es fija en el viewport (próximo avance).
// Las bandas históricas están ancladas al documento y se desplazan con el scroll.
class _OverlapBands extends StatelessWidget {
  final double viewportHeight;
  final double overlapFraction;
  final List<double> advanceMarkers; // posiciones documento de avances anteriores
  final double scrollOffset;
  final bool atEnd;

  const _OverlapBands({
    required this.viewportHeight,
    required this.overlapFraction,
    required this.advanceMarkers,
    required this.scrollOffset,
    required this.atEnd,
  });

  @override
  Widget build(BuildContext context) {
    final bandHeight = viewportHeight * overlapFraction;
    const bandWidth = 6.0;
    final color = atEnd
        ? const Color(0xAA1E88E5) // azul al llegar al final
        : const Color(0xAAE53935); // rojo el resto del tiempo

    return Stack(
      children: [
        // Banda fija en el fondo del viewport (próximo avance)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: bandHeight,
          child: IgnorePointer(child: _BandRow(color: color, bandWidth: bandWidth, topRounded: true)),
        ),

        // Bandas históricas: ancladas al documento, se desplazan con el scroll
        for (final markerDocY in advanceMarkers) ...[
          if (markerDocY - scrollOffset > -bandHeight &&
              markerDocY - scrollOffset < viewportHeight)
            Positioned(
              top: markerDocY - scrollOffset,
              left: 0,
              right: 0,
              height: bandHeight,
              child: IgnorePointer(
                child: _BandRow(
                  color: color,
                  bandWidth: bandWidth,
                  topRounded: (markerDocY - scrollOffset) > 0,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _BandRow extends StatelessWidget {
  final Color color;
  final double bandWidth;
  final bool topRounded;

  const _BandRow({
    required this.color,
    required this.bandWidth,
    required this.topRounded,
  });

  @override
  Widget build(BuildContext context) {
    final radius = topRounded ? const Radius.circular(3) : Radius.zero;
    return Row(
      children: [
        Container(
          width: bandWidth,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(topRight: radius),
          ),
        ),
        const Spacer(),
        Container(
          width: bandWidth,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(topLeft: radius),
          ),
        ),
      ],
    );
  }
}

// Chip en el AppBar para configurar el auto-ajuste por canción
class _AutoFitChip extends StatelessWidget {
  final int? songAutoFit;    // override de esta canción (null = usa global)
  final int? globalAutoFit;  // ajuste global
  final ValueChanged<int?> onChanged;

  const _AutoFitChip({
    required this.songAutoFit,
    required this.globalAutoFit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasOverride = songAutoFit != null;
    final label = hasOverride ? '$songAutoFit📱' : '📱≡';

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Center(
        child: GestureDetector(
          onTap: () => _showPicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: hasOverride
                  ? ViewerColors.section.withValues(alpha: 0.2)
                  : ViewerColors.chord.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasOverride
                    ? ViewerColors.section
                    : ViewerColors.chord.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: hasOverride ? ViewerColors.section : ViewerColors.chord,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
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
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: ViewerColors.separator,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Pantallas para esta canción',
                style: TextStyle(
                  color: ViewerColors.title,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            // Opción: usar ajuste global
            ListTile(
              leading: Icon(
                Icons.tune,
                color: songAutoFit == null ? ViewerColors.chord : ViewerColors.artist,
              ),
              title: Text(
                'Usar ajuste global${globalAutoFit != null ? ' ($globalAutoFit pantallas)' : ' (manual)'}',
                style: TextStyle(
                  color: songAutoFit == null ? ViewerColors.chord : ViewerColors.lyric,
                  fontWeight: songAutoFit == null ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: songAutoFit == null
                  ? const Icon(Icons.check_circle, color: ViewerColors.chord)
                  : null,
              onTap: () {
                onChanged(null);
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1, indent: 20, color: Color(0xFF2A2A2A)),
            // Opciones 1-6 pantallas
            ...List.generate(6, (i) {
              final n = i + 1;
              final selected = songAutoFit == n;
              return ListTile(
                leading: Icon(
                  Icons.fit_screen,
                  color: selected ? ViewerColors.section : ViewerColors.artist,
                ),
                title: Text(
                  '$n ${n == 1 ? 'pantalla' : 'pantallas'}',
                  style: TextStyle(
                    color: selected ? ViewerColors.section : ViewerColors.lyric,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: selected
                    ? const Icon(Icons.check_circle, color: ViewerColors.section)
                    : null,
                onTap: () {
                  onChanged(n);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
