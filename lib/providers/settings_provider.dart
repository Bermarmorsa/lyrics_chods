// lib/providers/settings_provider.dart

import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pedal_settings.dart';
import '../services/storage_service.dart';

// ---------------------------------------------------------------------------
// Modelo de ajustes
// ---------------------------------------------------------------------------

/// Todos los ajustes persistibles de la app.
///
/// Se serializa a/desde [Map] para guardarse en Hive sin generación de código.
class AppSettings {
  final PedalSettings pedal;

  /// Multiplicador del tamaño de fuente base (22px × multiplier).
  /// Rango: 0.7 – 1.6. Por defecto: 1.0. Se ignora cuando [autoFitScreens] != null.
  final double fontSizeMultiplier;

  /// Número de pantallas en que debe caber cada canción (auto-ajuste).
  /// null = modo manual (usa [fontSizeMultiplier] directamente).
  final int? autoFitScreens;

  const AppSettings({
    this.pedal = const PedalSettings(),
    this.fontSizeMultiplier = 1.0,
    this.autoFitScreens,
  });

  AppSettings copyWith({
    PedalSettings? pedal,
    double? fontSizeMultiplier,
    Object? autoFitScreens = _sentinel,
  }) =>
      AppSettings(
        pedal: pedal ?? this.pedal,
        fontSizeMultiplier: fontSizeMultiplier ?? this.fontSizeMultiplier,
        autoFitScreens: autoFitScreens == _sentinel
            ? this.autoFitScreens
            : autoFitScreens as int?,
      );

  static const Object _sentinel = Object();

  // ---------------------------------------------------------------------------
  // Serialización para Hive
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toMap() => {
        'fontSizeMultiplier': fontSizeMultiplier,
        'autoFitScreens': autoFitScreens,
        'pedalNextKey': PedalSettings.keyToString(pedal.nextKey),
        'pedalPrevKey': PedalSettings.keyToString(pedal.prevKey),
        'pedalScrollMode': pedal.scrollMode.index,
        'pedalScrollFraction': pedal.scrollFraction,
      };

  factory AppSettings.fromMap(Map map) {
    return AppSettings(
      fontSizeMultiplier:
          (map['fontSizeMultiplier'] as num?)?.toDouble() ?? 1.0,
      autoFitScreens: map['autoFitScreens'] as int?,
      pedal: PedalSettings(
        nextKey: PedalSettings.keyFromString(
            map['pedalNextKey'] as String?),
        prevKey: PedalSettings.keyFromString(
            map['pedalPrevKey'] as String?, isPrev: true),
        // Finding 10: guard para evitar RangeError si el índice no existe
        scrollMode: () {
          final i = (map['pedalScrollMode'] as int?) ?? 0;
          return (i >= 0 && i < PedalScrollMode.values.length)
              ? PedalScrollMode.values[i]
              : PedalScrollMode.byAmount;
        }(),
        // Finding 9: clamp para evitar valores fuera del rango válido
        scrollFraction:
            ((map['pedalScrollFraction'] as num?)?.toDouble() ?? 0.85)
                .clamp(0.1, 1.0),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    // Cargar desde Hive al arrancar la app.
    // Si no hay datos guardados (primera ejecución) usa los valores por defecto.
    final map = StorageService.loadSettingsMap();
    if (map == null) return const AppSettings();
    return AppSettings.fromMap(map);
  }

  // ---------------------------------------------------------------------------
  // Actualizadores — cada uno guarda en Hive automáticamente
  // ---------------------------------------------------------------------------

  void updatePedalSettings(PedalSettings pedal) {
    _persist(state.copyWith(pedal: pedal));
  }

  void updateFontSize(double multiplier) {
    final rounded = double.parse(multiplier.toStringAsFixed(1));
    _persist(state.copyWith(fontSizeMultiplier: rounded));
  }

  void updateAutoFitScreens(int? screens) {
    _persist(state.copyWith(autoFitScreens: screens));
  }

  // ---------------------------------------------------------------------------
  // Helper privado
  // ---------------------------------------------------------------------------

  /// Actualiza el estado en memoria y persiste en background.
  /// Se usa [unawaited] para no bloquear la UI mientras Hive escribe.
  void _persist(AppSettings settings) {
    state = settings;
    unawaited(StorageService.saveSettingsMap(settings.toMap()));
  }
}
