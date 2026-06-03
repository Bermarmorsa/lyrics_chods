// lib/services/drive_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/drive_file.dart';
import '../models/song.dart';
import 'chordpro_parser.dart';

/// Gestiona la autenticación con Google y el acceso a archivos en Drive.
///
/// ## Flujo de autenticación
/// 1. [signInSilently] intenta restaurar la sesión anterior (sin UI).
/// 2. [signIn] muestra el diálogo de Google si no hay sesión.
/// 3. [_buildAuthClient] crea un cliente HTTP que añade el token OAuth
///    a cada petición, para que el [drive.DriveApi] pueda hacer llamadas.
///
/// ## Acceso a archivos
/// Solo se solicita el ámbito de solo lectura ([drive.DriveApi.driveReadonlyScope]).
/// La app nunca modifica ni borra nada en el Drive del usuario.
class DriveService {
  static final _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveReadonlyScope],
  );

  static GoogleSignInAccount? _currentAccount;

  // ---------------------------------------------------------------------------
  // Autenticación
  // ---------------------------------------------------------------------------

  /// Intenta restaurar la sesión sin mostrar UI al usuario.
  /// Devuelve null si no hay sesión previa o si falla.
  static Future<GoogleSignInAccount?> signInSilently() async {
    try {
      _currentAccount = await _googleSignIn.signInSilently();
      return _currentAccount;
    } catch (e) {
      debugPrint('[Drive] signInSilently falló: $e');
      return null;
    }
  }

  /// Muestra el selector de cuenta de Google al usuario.
  /// Lanza una excepción si el usuario cancela o falla la autenticación.
  static Future<GoogleSignInAccount?> signIn() async {
    _currentAccount = await _googleSignIn.signIn();
    return _currentAccount;
  }

  /// Cierra la sesión de Google.
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentAccount = null;
  }

  static GoogleSignInAccount? get currentAccount => _currentAccount;

  // ---------------------------------------------------------------------------
  // Operaciones de Drive
  // ---------------------------------------------------------------------------

  /// Busca archivos .cho y .chordpro en todo el Drive del usuario.
  ///
  /// Usa la query de Drive API para filtrar por nombre, luego aplica
  /// un filtro adicional en el cliente para mayor precisión.
  /// Devuelve los archivos ordenados alfabéticamente por nombre.
  static Future<List<DriveFile>> listChordProFiles() async {
    final client = await _buildAuthClient();
    try {
      final driveApi = drive.DriveApi(client);

      final result = await driveApi.files.list(
        // Drive API usa 'contains' (no 'ends_with'), así que filtramos en cliente también
        q: "(name contains '.cho' or name contains '.chordpro') and trashed=false",
        spaces: 'drive',
        // Solo pedimos los campos que necesitamos (reduce el tamaño de la respuesta)
        $fields: 'files(id,name,size,modifiedTime)',
        orderBy: 'name',
        pageSize: 1000,
      );

      return (result.files ?? [])
          // Filtro adicional en cliente: asegurar que el nombre TERMINA con .cho o .chordpro
          .where((f) =>
              f.name?.endsWith('.cho') == true ||
              f.name?.endsWith('.chordpro') == true)
          .map((f) => DriveFile(
                id: f.id!,
                name: f.name!,
                // Drive devuelve el tamaño como String para soportar archivos grandes
                sizeBytes: f.size != null ? int.tryParse(f.size!) : null,
                modifiedTime: f.modifiedTime,
              ))
          .toList();
    } finally {
      client.close();
    }
  }

  /// Descarga el archivo [file] desde Drive, lo guarda en el directorio
  /// de documentos de la app y lo parsea como [Song].
  ///
  /// Devuelve null si falla la descarga o el parseo.
  static Future<Song?> downloadSong(DriveFile file) async {
    final client = await _buildAuthClient();
    try {
      final driveApi = drive.DriveApi(client);

      // DownloadOptions.fullMedia → descarga el contenido binario del archivo
      final response = await driveApi.files.get(
        file.id,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      // Leer todo el stream en memoria
      final bytes = await response.stream
          .fold<List<int>>([], (buf, chunk) => buf..addAll(chunk));

      // Decodificar como UTF-8 (allowMalformed para tolerar BOM u otros)
      final content = utf8.decode(bytes, allowMalformed: true);

      // Guardar en el directorio persistente de la app
      final destPath = await _saveToDocuments(file.name, content);

      return ChordProParser.parse(content, filePath: destPath);
    } catch (e) {
      debugPrint('[Drive] Error descargando "${file.name}": $e');
      return null;
    } finally {
      client.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers privados
  // ---------------------------------------------------------------------------

  /// Crea un [http.Client] que añade automáticamente el token OAuth
  /// de Google a cada petición HTTP.
  static Future<http.Client> _buildAuthClient() async {
    final account = _currentAccount ?? await signInSilently();
    if (account == null) {
      throw Exception('No hay sesión de Google activa. Inicia sesión primero.');
    }
    // authHeaders contiene el Authorization: Bearer <token>
    final headers = await account.authHeaders;
    return _GoogleAuthClient(headers);
  }

  /// Guarda [content] como archivo de texto en `documents/songs/[fileName]`.
  /// Si el archivo ya existe, lo sobreescribe (equivale a "actualizar desde Drive").
  static Future<String> _saveToDocuments(String fileName, String content) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final songsDir = Directory('${docsDir.path}/songs');
    if (!await songsDir.exists()) {
      await songsDir.create(recursive: true);
    }
    final destPath = '${songsDir.path}/$fileName';
    await File(destPath).writeAsString(content, flush: true);
    return destPath;
  }
}

// ---------------------------------------------------------------------------
// Cliente HTTP con autenticación Google
// ---------------------------------------------------------------------------

/// [http.BaseClient] que inyecta los headers OAuth de Google en cada petición.
///
/// Se crea en [DriveService._buildAuthClient] y se descarta después de cada
/// operación. Los tokens expiran después de 1 hora; [google_sign_in] los
/// refresca automáticamente al llamar a [account.authHeaders].
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final _inner = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request..headers.addAll(_headers));

  @override
  void close() => _inner.close();
}
