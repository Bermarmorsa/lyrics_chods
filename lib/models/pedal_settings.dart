// lib/models/pedal_settings.dart

import 'package:flutter/services.dart';

/// Los dos modos en que puede operar el pedal.
enum PedalScrollMode {
  /// Desplaza un porcentaje fijo del alto de la pantalla.
  byAmount,

  /// Salta a la siguiente/anterior sección ({verse}, {chorus}…).
  bySection,
}

/// Configuración del pedal Bluetooth: teclas y modo de desplazamiento.
///
/// Inmutable — usa [copyWith] para modificar.
/// Serializable a/desde [Map] para persistirla en Hive.
class PedalSettings {
  final LogicalKeyboardKey nextKey;
  final LogicalKeyboardKey prevKey;
  final PedalScrollMode scrollMode;

  /// Fracción del alto visible que avanza cada pulsación (modo [byAmount]).
  /// Rango: 0.4 – 1.0
  final double scrollFraction;

  const PedalSettings({
    this.nextKey = LogicalKeyboardKey.pageDown,
    this.prevKey = LogicalKeyboardKey.pageUp,
    this.scrollMode = PedalScrollMode.byAmount,
    this.scrollFraction = 0.85,
  });

  PedalSettings copyWith({
    LogicalKeyboardKey? nextKey,
    LogicalKeyboardKey? prevKey,
    PedalScrollMode? scrollMode,
    double? scrollFraction,
  }) =>
      PedalSettings(
        nextKey: nextKey ?? this.nextKey,
        prevKey: prevKey ?? this.prevKey,
        scrollMode: scrollMode ?? this.scrollMode,
        scrollFraction: scrollFraction ?? this.scrollFraction,
      );

  // ---------------------------------------------------------------------------
  // Teclas soportadas (para la UI de ajustes y la serialización)
  // ---------------------------------------------------------------------------

  /// Mapa de nombre serializable → LogicalKeyboardKey.
  /// Las claves son strings estables, independientes de la versión de Flutter.
  static const Map<String, LogicalKeyboardKey> _keyMap = {
    'pageDown':   LogicalKeyboardKey.pageDown,
    'pageUp':     LogicalKeyboardKey.pageUp,
    'arrowDown':  LogicalKeyboardKey.arrowDown,
    'arrowUp':    LogicalKeyboardKey.arrowUp,
    'arrowRight': LogicalKeyboardKey.arrowRight,
    'arrowLeft':  LogicalKeyboardKey.arrowLeft,
    'space':      LogicalKeyboardKey.space,
    'enter':      LogicalKeyboardKey.enter,
  };

  /// Lista de teclas disponibles en la pantalla de ajustes.
  static List<LogicalKeyboardKey> get supportedKeys =>
      List.unmodifiable(_keyMap.values.toList());

  /// Convierte una [LogicalKeyboardKey] a su nombre serializable.
  static String keyToString(LogicalKeyboardKey key) =>
      _keyMap.entries
          .firstWhere(
            (e) => e.value == key,
            orElse: () => _keyMap.entries.first,
          )
          .key;

  /// Reconstruye una [LogicalKeyboardKey] desde su nombre serializado.
  /// Si el nombre no existe, devuelve el default (pageDown o pageUp).
  static LogicalKeyboardKey keyFromString(String? name,
      {bool isPrev = false}) =>
      _keyMap[name] ??
      (isPrev ? LogicalKeyboardKey.pageUp : LogicalKeyboardKey.pageDown);

  /// Nombre legible de una tecla para mostrar en la UI.
  static String keyLabel(LogicalKeyboardKey key) {
    final labels = {
      LogicalKeyboardKey.pageDown:   'Page Down',
      LogicalKeyboardKey.pageUp:     'Page Up',
      LogicalKeyboardKey.arrowDown:  '↓ Abajo',
      LogicalKeyboardKey.arrowUp:    '↑ Arriba',
      LogicalKeyboardKey.arrowRight: '→ Derecha',
      LogicalKeyboardKey.arrowLeft:  '← Izquierda',
      LogicalKeyboardKey.space:      'Espacio',
      LogicalKeyboardKey.enter:      'Enter',
    };
    return labels[key] ?? key.keyLabel;
  }
}
