// lib/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/pedal_settings.dart';
import '../../providers/settings_provider.dart';

/// Pantalla de ajustes de la app.
///
/// Secciones:
///   1. Visualización — tamaño de letra con preview en tiempo real
///   2. Pedal Bluetooth — teclas y modo de desplazamiento
///   3. Acerca de — versión y formato
///
/// Todos los cambios se guardan automáticamente en Hive (sin botón "Guardar").
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: ViewerColors.background,
      appBar: AppBar(
        backgroundColor: ViewerColors.background,
        foregroundColor: ViewerColors.title,
        elevation: 0,
        title: const Text(
          'Ajustes',
          style: TextStyle(
              color: ViewerColors.title, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        children: [
          // ── VISUALIZACIÓN ──────────────────────────────────────────────
          _SectionHeader('Visualización'),
          _FontSizeTile(settings: settings, ref: ref),

          const SizedBox(height: 8),

          // ── PEDAL BLUETOOTH ────────────────────────────────────────────
          _SectionHeader('Pedal Bluetooth'),
          _KeyPickerRow(
            label: 'Tecla para avanzar',
            hint: 'Pie derecho / botón principal',
            currentKey: settings.pedal.nextKey,
            onChanged: (key) => ref
                .read(settingsProvider.notifier)
                .updatePedalSettings(settings.pedal.copyWith(nextKey: key)),
          ),
          Divider(height: 1, indent: 20, color: ViewerColors.separator),
          _KeyPickerRow(
            label: 'Tecla para retroceder',
            hint: 'Pie izquierdo (si el pedal lo tiene)',
            currentKey: settings.pedal.prevKey,
            onChanged: (key) => ref
                .read(settingsProvider.notifier)
                .updatePedalSettings(settings.pedal.copyWith(prevKey: key)),
          ),
          Divider(height: 1, indent: 20, color: ViewerColors.separator),
          _ScrollModeTile(settings: settings, ref: ref),
          if (settings.pedal.scrollMode == PedalScrollMode.byAmount)
            _ScrollFractionTile(settings: settings, ref: ref),
          _PedalInfoBanner(),

          const SizedBox(height: 8),

          // ── ACERCA DE ──────────────────────────────────────────────────
          _SectionHeader('Acerca de'),
          _AboutTile(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// =============================================================================
// SECCIÓN: Visualización
// =============================================================================

/// Sección de tamaño de fuente con dos modos: Manual y Auto-ajuste.
class _FontSizeTile extends StatelessWidget {
  final AppSettings settings;
  final WidgetRef ref;

  const _FontSizeTile({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isAuto = settings.autoFitScreens != null;
    final mult = settings.fontSizeMultiplier;
    final fontSize = 22.0 * mult;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera con toggle Manual / Auto-ajuste
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tamaño de letra',
                  style: TextStyle(color: ViewerColors.lyric, fontSize: 15)),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.tune, size: 16),
                    label: Text('Manual'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.fit_screen, size: 16),
                    label: Text('Auto-ajuste'),
                  ),
                ],
                selected: {isAuto},
                onSelectionChanged: (sel) {
                  if (sel.first) {
                    ref.read(settingsProvider.notifier).updateAutoFitScreens(2);
                  } else {
                    ref.read(settingsProvider.notifier).updateAutoFitScreens(null);
                  }
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((s) {
                    if (s.contains(WidgetState.selected)) {
                      return ViewerColors.chord.withValues(alpha: 0.18);
                    }
                    return const Color(0xFF1E1E1E);
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((s) {
                    if (s.contains(WidgetState.selected)) return ViewerColors.chord;
                    return ViewerColors.artist;
                  }),
                  side: WidgetStateProperty.all(
                      BorderSide(color: ViewerColors.separator)),
                ),
              ),
            ],
          ),
        ),

        if (!isAuto) ...[
          // Modo manual: slider + preview
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tamaño',
                    style: TextStyle(color: ViewerColors.artist, fontSize: 13)),
                _ValueBadge('${mult.toStringAsFixed(1)}×'),
              ],
            ),
          ),
          _StyledSlider(
            min: 0.7,
            max: 1.6,
            divisions: 9,
            value: mult,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).updateFontSize(v),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ViewerColors.separator),
              ),
              child: Row(
                children: [
                  _ChordPreviewCol('G', 'Cuan', fontSize),
                  _ChordPreviewCol('Am7', 'do el ', fontSize),
                  _ChordPreviewCol('D', 'sol', fontSize),
                ],
              ),
            ),
          ),
        ] else ...[
          // Modo auto-ajuste: selector de pantallas
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pantallas por canción',
                  style: TextStyle(color: ViewerColors.artist, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  'El tamaño de letra se ajustará al abrir cada canción\npara que quepa en el número de pantallas elegido.',
                  style: TextStyle(color: ViewerColors.separator, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [1, 2, 3, 4, 5, 6].map((n) {
                    final selected = settings.autoFitScreens == n;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => ref
                            .read(settingsProvider.notifier)
                            .updateAutoFitScreens(n),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: selected
                                ? ViewerColors.chord.withValues(alpha: 0.18)
                                : const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? ViewerColors.chord
                                  : ViewerColors.separator,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$n',
                              style: TextStyle(
                                color: selected
                                    ? ViewerColors.chord
                                    : ViewerColors.artist,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Mini-columna de preview: acorde encima, texto debajo.
class _ChordPreviewCol extends StatelessWidget {
  final String chord;
  final String text;
  final double fontSize;

  const _ChordPreviewCol(this.chord, this.text, this.fontSize);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(chord, style: ViewerTextStyles.chord(fontSize)),
          Text(text, style: ViewerTextStyles.lyric(fontSize)),
        ],
      ),
    );
  }
}

// =============================================================================
// SECCIÓN: Pedal Bluetooth
// =============================================================================

/// Fila que muestra la tecla actualmente asignada y abre un selector al tocar.
class _KeyPickerRow extends StatelessWidget {
  final String label;
  final String hint;
  final LogicalKeyboardKey currentKey;
  final ValueChanged<LogicalKeyboardKey> onChanged;

  const _KeyPickerRow({
    required this.label,
    required this.hint,
    required this.currentKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(label,
          style: const TextStyle(color: ViewerColors.lyric, fontSize: 15)),
      subtitle: Text(hint,
          style: const TextStyle(
              color: ViewerColors.separator, fontSize: 12)),
      trailing: GestureDetector(
        onTap: () => _showPicker(context),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ViewerColors.separator),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                PedalSettings.keyLabel(currentKey),
                style: const TextStyle(
                    color: ViewerColors.chord,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more,
                  color: ViewerColors.separator, size: 16),
            ],
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _KeyPickerSheet(
        title: label,
        currentKey: currentKey,
        onSelected: (key) {
          onChanged(key);
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// Bottom sheet con la lista de teclas soportadas.
class _KeyPickerSheet extends StatelessWidget {
  final String title;
  final LogicalKeyboardKey currentKey;
  final ValueChanged<LogicalKeyboardKey> onSelected;

  const _KeyPickerSheet({
    required this.title,
    required this.currentKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Asa visual
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: ViewerColors.separator,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              title,
              style: const TextStyle(
                  color: ViewerColors.title,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
          ...PedalSettings.supportedKeys.map(
            (key) => ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24),
              title: Text(
                PedalSettings.keyLabel(key),
                style: TextStyle(
                  color: key == currentKey
                      ? ViewerColors.chord
                      : ViewerColors.lyric,
                  fontWeight: key == currentKey
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              trailing: key == currentKey
                  ? const Icon(Icons.check_circle,
                      color: ViewerColors.chord)
                  : null,
              onTap: () => onSelected(key),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Selector del modo de scroll: Por página vs Por sección.
class _ScrollModeTile extends StatelessWidget {
  final AppSettings settings;
  final WidgetRef ref;

  const _ScrollModeTile({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isBySection =
        settings.pedal.scrollMode == PedalScrollMode.bySection;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Modo de desplazamiento',
              style:
                  TextStyle(color: ViewerColors.lyric, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            isBySection
                ? 'El pedal salta al siguiente Verso, Estribillo…'
                : 'El pedal avanza un porcentaje de la pantalla',
            style: const TextStyle(
                color: ViewerColors.separator, fontSize: 12),
          ),
          const SizedBox(height: 12),
          // SegmentedButton — Material 3
          SegmentedButton<PedalScrollMode>(
            segments: const [
              ButtonSegment(
                value: PedalScrollMode.byAmount,
                icon: Icon(Icons.swap_vert, size: 16),
                label: Text('Por página'),
              ),
              ButtonSegment(
                value: PedalScrollMode.bySection,
                icon: Icon(Icons.playlist_play, size: 16),
                label: Text('Por sección'),
              ),
            ],
            selected: {settings.pedal.scrollMode},
            onSelectionChanged: (sel) => ref
                .read(settingsProvider.notifier)
                .updatePedalSettings(
                    settings.pedal.copyWith(scrollMode: sel.first)),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((s) {
                if (s.contains(WidgetState.selected)) {
                  return ViewerColors.chord.withValues(alpha: 0.18);
                }
                return const Color(0xFF1E1E1E);
              }),
              foregroundColor: WidgetStateProperty.resolveWith((s) {
                if (s.contains(WidgetState.selected)) {
                  return ViewerColors.chord;
                }
                return ViewerColors.artist;
              }),
              side: WidgetStateProperty.all(
                BorderSide(color: ViewerColors.separator),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slider del porcentaje de avance por pulsación (solo visible en modo byAmount).
class _ScrollFractionTile extends StatelessWidget {
  final AppSettings settings;
  final WidgetRef ref;

  const _ScrollFractionTile({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    final pct = (settings.pedal.scrollFraction * 100).round();
    final label = pct >= 100 ? 'Página completa' : '$pct%';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Avance por pulsación',
                  style: TextStyle(
                      color: ViewerColors.lyric, fontSize: 15)),
              _ValueBadge(label),
            ],
          ),
          const Text(
            'Porcentaje de pantalla que avanza al pisar el pedal',
            style: TextStyle(
                color: ViewerColors.separator, fontSize: 12),
          ),
          _StyledSlider(
            min: 0.4,
            max: 1.0,
            divisions: 6,
            value: settings.pedal.scrollFraction,
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .updatePedalSettings(
                    settings.pedal.copyWith(scrollFraction: v)),
          ),
        ],
      ),
    );
  }
}

/// Banner informativo sobre cómo probar el pedal sin el hardware.
class _PedalInfoBanner extends StatelessWidget {
  const _PedalInfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ViewerColors.chord.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: ViewerColors.chord.withValues(alpha: 0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              color: ViewerColors.chord, size: 15),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Para probar sin pedal: abre la pantalla de la canción '
              'y pulsa las teclas del teclado del ordenador '
              'conectado por cable OTG, o usa el emulador de Android.',
              style: TextStyle(
                  color: ViewerColors.artist, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECCIÓN: Acerca de
// =============================================================================

class _AboutTile extends StatelessWidget {
  const _AboutTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ViewerColors.chord.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.music_note,
                    color: ViewerColors.chord, size: 26),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chord Viewer',
                      style: TextStyle(
                          color: ViewerColors.title,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text('Versión 1.0.0',
                      style: TextStyle(
                          color: ViewerColors.artist, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow(Icons.description_outlined,
              'Formato: ChordPro (.cho, .chordpro)'),
          _infoRow(Icons.bluetooth,
              'Pedal: cualquier dispositivo HID Bluetooth'),
          _infoRow(Icons.cloud_outlined, 'Sincronización: Google Drive'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: ViewerColors.separator, size: 16),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  color: ViewerColors.separator, fontSize: 13)),
        ],
      ),
    );
  }
}

// =============================================================================
// Widgets de utilidad (privados, reutilizados dentro de este archivo)
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: ViewerColors.chord,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

/// Badge redondeado para mostrar el valor actual de un ajuste.
class _ValueBadge extends StatelessWidget {
  final String value;

  const _ValueBadge(this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: ViewerColors.chord.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: ViewerColors.chord,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Slider estilizado con los colores de la app.
class _StyledSlider extends StatelessWidget {
  final double min;
  final double max;
  final int divisions;
  final double value;
  final ValueChanged<double> onChanged;

  const _StyledSlider({
    required this.min,
    required this.max,
    required this.divisions,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: ViewerColors.chord,
        inactiveTrackColor: ViewerColors.separator,
        thumbColor: ViewerColors.chord,
        overlayColor: ViewerColors.chord.withValues(alpha: 0.18),
        valueIndicatorColor: ViewerColors.chord,
        valueIndicatorTextStyle:
            const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
      child: Slider(
        min: min,
        max: max,
        divisions: divisions,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
