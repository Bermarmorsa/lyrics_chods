// lib/providers/drive_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/drive_file.dart';
import '../models/song_summary.dart';
import '../services/drive_service.dart';
import 'library_provider.dart';

// ---------------------------------------------------------------------------
// Estado
// ---------------------------------------------------------------------------

/// Estado completo del módulo de Google Drive.
class DriveState {
  final bool isConnected;
  final GoogleSignInAccount? account;
  final List<DriveFile> files;
  final bool isLoadingFiles;

  const DriveState({
    this.isConnected = false,
    this.account,
    this.files = const [],
    this.isLoadingFiles = false,
  });

  DriveState copyWith({
    bool? isConnected,
    GoogleSignInAccount? account,
    List<DriveFile>? files,
    bool? isLoadingFiles,
  }) =>
      DriveState(
        isConnected: isConnected ?? this.isConnected,
        account: account ?? this.account,
        files: files ?? this.files,
        isLoadingFiles: isLoadingFiles ?? this.isLoadingFiles,
      );
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Usamos AsyncNotifier porque build() es asíncrono:
/// necesitamos comprobar si hay una sesión de Google guardada antes
/// de dar el estado inicial.
///
/// En la UI se consume con:
///   ref.watch(driveProvider).when(loading: ..., error: ..., data: ...)
final driveProvider =
    AsyncNotifierProvider<DriveNotifier, DriveState>(DriveNotifier.new);

class DriveNotifier extends AsyncNotifier<DriveState> {
  @override
  Future<DriveState> build() async {
    // Al crear el provider, intentamos restaurar la sesión en silencio.
    // Si el usuario ya había iniciado sesión antes, no necesita volver a hacerlo.
    final account = await DriveService.signInSilently();
    return DriveState(
      isConnected: account != null,
      account: account,
    );
  }

  // ---------------------------------------------------------------------------
  // Autenticación
  // ---------------------------------------------------------------------------

  /// Muestra el selector de cuenta de Google.
  /// Después de autenticar, carga automáticamente la lista de archivos.
  Future<void> signIn() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final account = await DriveService.signIn();
      if (account == null) return const DriveState(); // usuario canceló
      return DriveState(isConnected: true, account: account);
    });

    // Si el sign-in fue exitoso, cargar los archivos automáticamente
    if (state.valueOrNull?.isConnected == true) {
      await loadFiles();
    }
  }

  /// Cierra la sesión y limpia el estado.
  Future<void> signOut() async {
    await DriveService.signOut();
    state = const AsyncValue.data(DriveState());
  }

  // ---------------------------------------------------------------------------
  // Operaciones de archivos
  // ---------------------------------------------------------------------------

  /// Consulta Drive para listar los archivos .cho y .chordpro del usuario.
  Future<void> loadFiles() async {
    final current = state.valueOrNull;
    if (current == null || !current.isConnected) return;

    state = AsyncValue.data(current.copyWith(isLoadingFiles: true));

    try {
      final files = await DriveService.listChordProFiles();
      state = AsyncValue.data(current.copyWith(
        files: files,
        isLoadingFiles: false,
      ));
    } catch (e, st) {
      debugPrint('[Drive] Error al listar archivos: $e');
      // Restaurar estado sin loading, pero reportar el error al caller
      state = AsyncValue.data(current.copyWith(isLoadingFiles: false));
      Error.throwWithStackTrace(e, st);
    }
  }

  /// Descarga [file] desde Drive, lo guarda localmente y lo añade a la biblioteca.
  ///
  /// Devuelve true si la importación fue exitosa.
  /// Lanza una excepción si falla la descarga o el parseo.
  Future<bool> importFile(DriveFile file) async {
    final song = await DriveService.downloadSong(file);
    if (song == null) return false;

    final summary = SongSummary.fromSong(song);

    // Notificar al LibraryProvider para que la biblioteca se actualice
    // ref.read accede al provider de biblioteca sin suscribirse a él
    await ref.read(libraryProvider.notifier).addSong(summary);

    return true;
  }
}
