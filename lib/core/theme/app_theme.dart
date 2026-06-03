// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';

/// Paleta de colores para la pantalla de visualización.
/// Diseñada para alto contraste y lectura a distancia en escenario oscuro.
class ViewerColors {
  ViewerColors._(); // clase no instanciable

  static const background = Color(0xFF121212); // negro suave
  static const lyric = Color(0xFFEEEEEE);      // blanco cálido
  static const chord = Color(0xFFFFB300);       // ámbar dorado — fácil de distinguir
  static const section = Color(0xFF64B5F6);     // azul claro — etiquetas de sección
  static const title = Color(0xFFFFFFFF);
  static const artist = Color(0xFF9E9E9E);      // gris medio
  static const separator = Color(0xFF2A2A2A);
}

/// Estilos de texto para la pantalla de visualización.
///
/// Todos reciben [fontSize] como parámetro para que el usuario pueda
/// ajustar el tamaño desde los ajustes (Paso 9) sin duplicar código.
class ViewerTextStyles {
  ViewerTextStyles._();

  /// Texto de la letra de la canción.
  static TextStyle lyric(double fontSize) => TextStyle(
        color: ViewerColors.lyric,
        fontSize: fontSize,
        height: 1.25,
        letterSpacing: 0.2,
      );

  /// Texto del acorde — negrita, más pequeño, color distinto.
  static TextStyle chord(double fontSize) => TextStyle(
        color: ViewerColors.chord,
        fontSize: fontSize * 0.70,
        fontWeight: FontWeight.bold,
        // monospace para que la anchura de los acordes sea predecible
        fontFamily: 'monospace',
        height: 1.0,
        letterSpacing: 0.5,
      );

  /// Etiqueta de sección (VERSO, ESTRIBILLO…).
  static TextStyle section(double fontSize) => TextStyle(
        color: ViewerColors.section,
        fontSize: fontSize * 0.72,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      );

  /// Título de la canción.
  static TextStyle songTitle(double fontSize) => TextStyle(
        color: ViewerColors.title,
        fontSize: fontSize * 1.2,
        fontWeight: FontWeight.bold,
        height: 1.2,
      );

  /// Nombre del artista — más pequeño y atenuado.
  static TextStyle songArtist(double fontSize) => TextStyle(
        color: ViewerColors.artist,
        fontSize: fontSize * 0.85,
        height: 1.4,
      );
}
