// lib/models/drive_file.dart

/// Representa un archivo ChordPro encontrado en Google Drive.
///
/// Es un modelo ligero — solo los metadatos necesarios para mostrarlo
/// en la lista y descargarlo. No incluye el contenido del archivo.
class DriveFile {
  final String id;           // ID único en Google Drive
  final String name;         // Nombre del archivo (con extensión)
  final int? sizeBytes;      // Tamaño en bytes (null si Drive no lo reporta)
  final DateTime? modifiedTime;

  const DriveFile({
    required this.id,
    required this.name,
    this.sizeBytes,
    this.modifiedTime,
  });

  /// Tamaño formateado para mostrar en la UI.
  String get formattedSize {
    if (sizeBytes == null) return '';
    if (sizeBytes! < 1024) return '${sizeBytes}B';
    return '${(sizeBytes! / 1024).toStringAsFixed(1)} KB';
  }
}
