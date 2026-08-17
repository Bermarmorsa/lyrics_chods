// lib/core/l10n/app_localizations.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/pedal_settings.dart';

/// Cadenas de texto localizadas para ES (por defecto) e EN.
///
/// Uso: `final l10n = AppLocalizations.of(context);`
///
/// El idioma activo lo determina MaterialApp.locale:
///   - null → idioma del sistema
///   - Locale('en') → inglés forzado
///   - Locale('es') → español forzado
class AppLocalizations {
  final String languageCode;
  const AppLocalizations._(this.languageCode);

  static AppLocalizations of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return AppLocalizations._(code);
  }

  bool get _en => languageCode == 'en';

  // ---------------------------------------------------------------------------
  // Navegación principal
  // ---------------------------------------------------------------------------
  String get library => _en ? 'Library' : 'Biblioteca';
  String get concerts => _en ? 'Concerts' : 'Conciertos';

  // ---------------------------------------------------------------------------
  // Acciones comunes
  // ---------------------------------------------------------------------------
  String get cancel => _en ? 'Cancel' : 'Cancelar';
  String get delete => _en ? 'Delete' : 'Eliminar';
  String get save => _en ? 'Save' : 'Guardar';
  String get create => _en ? 'Create' : 'Crear';
  String get rename => _en ? 'Rename' : 'Renombrar';
  String get export => _en ? 'Export' : 'Exportar';
  String get import_ => _en ? 'Import' : 'Importar';
  String get retry => _en ? 'Retry' : 'Reintentar';
  String get settings => _en ? 'Settings' : 'Ajustes';
  String get all => _en ? 'All' : 'Todas';
  String get options => _en ? 'Options' : 'Opciones';

  // ---------------------------------------------------------------------------
  // Biblioteca
  // ---------------------------------------------------------------------------
  String get searchHint => _en ? 'Search by title or artist…' : 'Buscar por título o artista…';
  String get newSong => _en ? 'New song' : 'Nueva canción';
  String get importing => _en ? 'Importing…' : 'Importando…';
  String get noSearchResults => _en ? 'No search results' : 'Sin resultados para la búsqueda';
  String get libraryEmpty => _en ? 'Your library is empty' : 'Tu biblioteca está vacía';
  String get libraryEmptyHint => _en
      ? 'Tap "Import" to add\n.cho or .chordpro files'
      : 'Toca el botón "Importar" para añadir\narchivos .cho o .chordpro';
  String importedCount(int count) => _en
      ? '$count ${count == 1 ? 'song' : 'songs'} imported'
      : '$count canción${count == 1 ? '' : 'es'} importada${count == 1 ? '' : 's'}';
  String errorImporting(String e) => _en ? 'Error importing: $e' : 'Error al importar: $e';
  String get noLocalFile => _en ? 'This song has no local file' : 'Esta canción no tiene archivo local';
  String get fileNotFound => _en
      ? 'File not found. Was it moved or deleted?'
      : 'No se encontró el archivo. ¿Fue movido o borrado?';

  // ---------------------------------------------------------------------------
  // Song tile
  // ---------------------------------------------------------------------------
  String get editSong => _en ? 'Edit song' : 'Editar canción';
  String get removeFromLibrary => _en ? 'Remove from library' : 'Eliminar de la biblioteca';
  String get deleteSong => _en ? 'Delete song' : 'Eliminar canción';
  String deleteSongConfirm(String title) => _en
      ? 'Delete "$title" from the library?\n\nThe file on your device will not be deleted.'
      : '¿Eliminar "$title" de la biblioteca?\n\nEl archivo del dispositivo no se borrará.';

  // ---------------------------------------------------------------------------
  // Viewer
  // ---------------------------------------------------------------------------
  String get prevSong => _en ? 'Previous song' : 'Canción anterior';
  String get nextSong => _en ? 'Next song' : 'Siguiente canción';
  String get immersiveMode => _en ? 'Immersive mode' : 'Modo inmersivo';
  String get semitoneDown => _en ? '−1 semitone' : '−1 semitono';
  String get semitoneUp => _en ? '+1 semitone' : '+1 semitono';
  String get flats => _en ? '♭ flats' : '♭ bemoles';
  String get sharps => _en ? '♯ sharps' : '♯ sost.';
  String get zeroSemitones => '0 semit.';
  String get sectionMode => _en ? 'Section' : 'Sección';
  String get pageMode => _en ? 'Page' : 'Página';
  String get songNotFoundInLibrary =>
      _en ? 'Song not found in library' : 'Canción no encontrada en la biblioteca';
  String get couldNotLoadFile => _en ? 'Could not load file' : 'No se pudo cargar el archivo';
  String get screensForSong => _en ? 'Screens for this song' : 'Pantallas para esta canción';
  String useGlobalSetting(int? count) {
    if (_en) return count != null ? 'Use global setting ($count screens)' : 'Use global setting (manual)';
    return count != null ? 'Usar ajuste global ($count pantallas)' : 'Usar ajuste global (manual)';
  }
  String screenCount(int n) => _en
      ? '$n ${n == 1 ? 'screen' : 'screens'}'
      : '$n ${n == 1 ? 'pantalla' : 'pantallas'}';

  // ---------------------------------------------------------------------------
  // Song header
  // ---------------------------------------------------------------------------
  String get keyLabel => _en ? 'Key' : 'Tonalidad';
  String get capoLabel => _en ? 'Capo' : 'Cejilla';
  String capoCompact(int capo) => _en ? 'Capo $capo' : 'Cejilla $capo';

  // ---------------------------------------------------------------------------
  // Ajustes — Visualización
  // ---------------------------------------------------------------------------
  String get display => _en ? 'Display' : 'Visualización';
  String get fontSize => _en ? 'Font size' : 'Tamaño de letra';
  String get manual => 'Manual';
  String get autoFit => _en ? 'Auto-fit' : 'Auto-ajuste';
  String get size => _en ? 'Size' : 'Tamaño';
  String get screensPerSong => _en ? 'Screens per song' : 'Pantallas por canción';
  String get screensPerSongHint => _en
      ? 'Font size will adjust when each song opens\nto fit in the selected number of screens.'
      : 'El tamaño de letra se ajustará al abrir cada canción\npara que quepa en el número de pantallas elegido.';

  // ---------------------------------------------------------------------------
  // Ajustes — Pedal
  // ---------------------------------------------------------------------------
  String get bluetoothPedal => _en ? 'Bluetooth Pedal' : 'Pedal Bluetooth';
  String get forwardKey => _en ? 'Forward key' : 'Tecla para avanzar';
  String get forwardKeyHint => _en ? 'Right foot / main button' : 'Pie derecho / botón principal';
  String get backwardKey => _en ? 'Backward key' : 'Tecla para retroceder';
  String get backwardKeyHint => _en ? 'Left foot (if the pedal has one)' : 'Pie izquierdo (si el pedal lo tiene)';
  String get scrollMode => _en ? 'Scroll mode' : 'Modo de desplazamiento';
  String get scrollModeSectionDesc => _en
      ? 'The pedal jumps to the next Verse, Chorus…'
      : 'El pedal salta al siguiente Verso, Estribillo…';
  String get scrollModePageDesc => _en
      ? 'The pedal scrolls a percentage of the screen'
      : 'El pedal avanza un porcentaje de la pantalla';
  String get byPage => _en ? 'By page' : 'Por página';
  String get bySection => _en ? 'By section' : 'Por sección';
  String get advancePerPress => _en ? 'Advance per press' : 'Avance por pulsación';
  String get advancePerPressHint => _en
      ? 'Percentage of screen scrolled per pedal press'
      : 'Porcentaje de pantalla que avanza al pisar el pedal';
  String get fullPage => _en ? 'Full page' : 'Página completa';
  String get pedalTestHint => _en
      ? 'To test without a pedal: open a song and press keys on a keyboard connected via OTG cable, or use the Android emulator.'
      : 'Para probar sin pedal: abre la pantalla de la canción y pulsa las teclas del teclado del ordenador conectado por cable OTG, o usa el emulador de Android.';

  // ---------------------------------------------------------------------------
  // Ajustes — Idioma
  // ---------------------------------------------------------------------------
  String get language => _en ? 'Language' : 'Idioma';
  String get languageAuto => _en ? 'Automatic' : 'Automático';
  String get languageAutoHint => _en ? 'Uses the system language' : 'Se usa el idioma del sistema';

  // ---------------------------------------------------------------------------
  // Ajustes — Acerca de
  // ---------------------------------------------------------------------------
  String get about => _en ? 'About' : 'Acerca de';
  String get version => _en ? 'Version 1.0.0' : 'Versión 1.0.0';
  String get formatInfo => 'Format: ChordPro (.cho, .chordpro)';
  String get pedalInfo => _en ? 'Pedal: any Bluetooth HID device' : 'Pedal: cualquier dispositivo HID Bluetooth';
  String get syncInfo => _en ? 'Sync: Google Drive' : 'Sincronización: Google Drive';

  // ---------------------------------------------------------------------------
  // Teclas del pedal
  // ---------------------------------------------------------------------------
  String pedalKeyLabel(LogicalKeyboardKey key) {
    if (_en) {
      const labels = {
        'pageDown':   'Page Down',
        'pageUp':     'Page Up',
        'arrowDown':  '↓ Down',
        'arrowUp':    '↑ Up',
        'arrowRight': '→ Right',
        'arrowLeft':  '← Left',
        'space':      'Space',
        'enter':      'Enter',
      };
      final name = PedalSettings.keyToString(key);
      return labels[name] ?? key.keyLabel;
    }
    return PedalSettings.keyLabel(key);
  }

  // ---------------------------------------------------------------------------
  // Setlists
  // ---------------------------------------------------------------------------
  String get importSetlist => _en ? 'Import setlist' : 'Importar setlist';
  String get newSetlist => _en ? 'New setlist' : 'Nuevo setlist';
  String get newSetlistHint => _en ? 'Madrid Concert, Tuesday Rehearsal…' : 'Concierto Madrid, Ensayo martes…';
  String get noSetlistsYet => _en ? 'No setlists yet' : 'Sin setlists aún';
  String get noSetlistsHint => _en
      ? 'Create your first setlist to\norganize a concert repertoire'
      : 'Crea tu primer setlist para\norganizar el repertorio de un concierto';
  String get createSetlist => _en ? 'Create setlist' : 'Crear setlist';
  String get renameSetlist => _en ? 'Rename setlist' : 'Renombrar setlist';
  String get setlistName => _en ? 'Setlist name' : 'Nombre del setlist';
  String get deleteSetlist => _en ? 'Delete setlist' : 'Eliminar setlist';
  String deleteSetlistConfirm(String name) => _en
      ? 'Delete "$name"?\n\nSongs in your library will not be deleted.'
      : '¿Eliminar "$name"?\n\nLas canciones de tu biblioteca no se borrarán.';
  String setlistImportedMsg(String name, int added, int skipped) {
    if (_en) {
      final extra = skipped > 0 ? ', $skipped already existed' : '';
      return '"$name" imported · $added new$extra';
    }
    final extra = skipped > 0 ? ', $skipped ya existía${skipped == 1 ? '' : 'n'}' : '';
    return '"$name" importado · $added nueva${added == 1 ? '' : 's'}$extra';
  }
  String songCount(int count) => _en
      ? '$count ${count == 1 ? 'song' : 'songs'}'
      : '$count canción${count == 1 ? '' : 'es'}';

  // ---------------------------------------------------------------------------
  // Detalle de setlist
  // ---------------------------------------------------------------------------
  String get setlistNoLongerExists => _en ? 'This setlist no longer exists' : 'Este setlist ya no existe';
  String get exportSetlist => _en ? 'Export setlist' : 'Exportar setlist';
  String get startFromBeginning => _en ? 'Start from beginning' : 'Empezar desde el principio';
  String get recordConcert => _en ? 'Record concert' : 'Grabar concierto';
  String get pauseRecording => _en ? 'Pause recording' : 'Pausar grabación';
  String get resumeRecording => _en ? 'Resume recording' : 'Reanudar grabación';
  String get stopAndSave => _en ? 'Stop and save' : 'Detener y guardar';
  String selectedCount(int count) => _en
      ? '$count selected'
      : '$count seleccionada${count == 1 ? '' : 's'}';
  String get removeSelected => _en ? 'Remove' : 'Quitar';
  String removeSelectedCount(int count) => _en
      ? 'Remove $count ${count == 1 ? 'song' : 'songs'}'
      : 'Quitar $count canción${count == 1 ? '' : 'es'}';
  String get addSong => _en ? 'Add song' : 'Añadir canción';
  String get saveConcert => _en ? 'Save concert' : 'Guardar concierto';
  String get concertName => _en ? 'Concert name' : 'Nombre del concierto';
  String concertSavedMsg(String name) => _en ? 'Concert "$name" saved' : 'Concierto "$name" guardado';
  String errorExportingMsg(String e) => _en ? 'Error exporting: $e' : 'Error al exportar: $e';
  String get removeSongs => _en ? 'Remove songs' : 'Quitar canciones';
  String removeSongsConfirm(int count) => _en
      ? 'Remove $count ${count == 1 ? 'song' : 'songs'} from the setlist?\n\nSongs will not be deleted from the library.'
      : '¿Quitar $count canción${count == 1 ? '' : 'es'} del setlist?\n\nLas canciones no se eliminarán de la biblioteca.';
  String get addToSetlist => _en ? 'Add to setlist' : 'Añadir al setlist';
  String get allSongsInSetlist => _en
      ? 'All songs are already in this setlist'
      : 'Todas las canciones ya están en este setlist';
  String addSongCount(int count) => _en
      ? 'Add $count ${count == 1 ? 'song' : 'songs'}'
      : 'Añadir $count canción${count == 1 ? '' : 'es'}';
  String get songNotAvailable => _en ? '(song not available)' : '(canción no disponible)';
  String get removeFromSetlist => _en ? 'Remove from setlist' : 'Quitar del setlist';
  String get emptySetlist => _en ? 'Empty setlist' : 'Setlist vacío';
  String get addSongs => _en ? 'Add songs' : 'Añadir canciones';
  String get noLocalFileSong => _en ? 'This song has no local file' : 'Esta canción no tiene archivo local';
  String get noSongInLibrary => _en ? 'Song not found in library' : 'Canción no encontrada en la biblioteca';
  String get noSongInLibraryFile => _en ? 'Could not load file' : 'No se pudo cargar el archivo';
  String get noTitle => _en ? '(no title)' : '(sin título)';

  // ---------------------------------------------------------------------------
  // Conciertos
  // ---------------------------------------------------------------------------
  String get importConcert => _en ? 'Import concert' : 'Importar concierto';
  String get couldNotImportFile => _en ? 'Could not import file' : 'No se pudo importar el archivo';
  String concertImportedMsg(String name) =>
      _en ? 'Concert "$name" imported' : 'Concierto "$name" importado';
  String get deleteConcert => _en ? 'Delete concert' : 'Eliminar concierto';
  String deleteConcertConfirm(String name) => _en ? 'Delete "$name"?' : '¿Eliminar "$name"?';
  String get noConcertsRecorded => _en ? 'No recorded concerts' : 'Sin conciertos grabados';
  String get noConcertsHint => _en
      ? 'Record a concert from a setlist detail'
      : 'Graba un concierto desde el detalle de un setlist';
  String concertSongsCount(int count) => _en
      ? '$count ${count == 1 ? 'song' : 'songs'}'
      : '$count canciones';

  // ---------------------------------------------------------------------------
  // Detalle de concierto
  // ---------------------------------------------------------------------------
  String get noRecordingData => _en ? 'No recording data' : 'Sin datos de grabación';
  String get setlistProgress => _en ? 'setlist progress' : 'avance setlist';
  String songAtIndex(int index) => _en ? 'song $index' : 'canción $index';

  // ---------------------------------------------------------------------------
  // Google Drive
  // ---------------------------------------------------------------------------
  String get refreshList => _en ? 'Refresh list' : 'Actualizar lista';
  String get connectToGoogleDrive => _en ? 'Connect to Google Drive' : 'Conecta con Google Drive';
  String get driveConnectHint => _en
      ? 'Import your .cho and .chordpro files\ndirectly from your Drive.\n\nThe app only reads files — it never\nmodifies your Drive.'
      : 'Importa tus archivos .cho y .chordpro\ndirectamente desde tu Drive.\n\nLa app solo lee archivos — nunca\nmodifica tu Drive.';
  String get connectWithGoogle => _en ? 'Connect with Google' : 'Conectar con Google';
  String get searchingInDrive => _en ? 'Searching files in Drive…' : 'Buscando archivos en Drive…';
  String fileCountInDrive(int count) => _en
      ? '$count ${count == 1 ? 'file' : 'files'} in Drive'
      : '$count archivo${count == 1 ? '' : 's'} en Drive';
  String get importAll => _en ? 'Import all' : 'Importar todos';
  String get noResults => _en ? 'No results' : 'Sin resultados';
  String importedFile(String name) => _en ? 'Imported: $name' : 'Importado: $name';
  String couldNotParseFile(String name) =>
      _en ? 'Could not parse $name' : 'No se pudo parsear $name';
  String errorImportingFile(String name, String e) =>
      _en ? 'Error importing $name: $e' : 'Error importando $name: $e';
  String errorConnecting(String e) => _en ? 'Error connecting: $e' : 'Error al conectar: $e';
  String get disconnect => _en ? 'Disconnect' : 'Desconectar';
  String get noChordProFiles => _en
      ? 'No .cho or .chordpro files found'
      : 'No se encontraron archivos .cho o .chordpro';
  String get uploadToGoogleDriveHint => _en
      ? 'Upload your ChordPro files to Google Drive\nand try again.'
      : 'Sube tus archivos ChordPro a Google Drive\ny vuelve a intentarlo.';
  String get searchAgain => _en ? 'Search again' : 'Buscar de nuevo';
  String get importToLibrary => _en ? 'Import to library' : 'Importar a la biblioteca';
  String get searchInDrive => _en ? 'Search in Drive…' : 'Buscar en Drive…';

  // ---------------------------------------------------------------------------
  // Editor
  // ---------------------------------------------------------------------------
  String get newSongTitle => _en ? 'New song' : 'Nueva canción';
  String get editSongTitle => _en ? 'Edit song' : 'Editar canción';
  String get chordProSyntax => _en ? 'ChordPro syntax' : 'Sintaxis ChordPro';
  String get chordProEditorHint => _en ? 'Write ChordPro content…' : 'Escribe el contenido ChordPro…';
  String get savedSuccessfully => _en ? 'Saved successfully' : 'Guardado correctamente';
  String errorSaving(String e) => _en ? 'Error saving: $e' : 'Error al guardar: $e';

  // Hoja de ayuda
  String get metadata => _en ? 'Metadata' : 'Metadatos';
  String get songTitleLabel => _en ? 'Song title' : 'Título de la canción';
  String get artistOrBand => _en ? 'Artist or band' : 'Artista o banda';
  String get originalKey => _en ? 'Original key' : 'Tonalidad original';
  String get capoOnFret => _en ? 'Capo on fret 2' : 'Cejilla en traste 2';
  String get tempoInBpm => _en ? 'Tempo in BPM' : 'Tempo en BPM';
  String get chords => _en ? 'Chords' : 'Acordes';
  String get chordAboveSyllable => _en ? 'Chord above the syllable' : 'Acorde encima de la sílaba';
  String get chordWithSuffix => _en ? 'Chord with suffix' : 'Acorde con sufijo';
  String get chordWithBass => _en ? 'Chord with specific bass' : 'Acorde con bajo específico';
  String get chordWithSharpFlat => _en ? 'Chord with sharp or flat' : 'Acorde con sostenido o bemol';
  String get sections => _en ? 'Sections' : 'Secciones';
  String get sectionWithName => _en ? 'Section with custom name' : 'Sección con nombre personalizado';
  String get standardVerse => _en ? 'Standard verse' : 'Verso estándar';
  String get standardChorus => _en ? 'Standard chorus' : 'Estribillo estándar';
  String get bridge => _en ? 'Bridge' : 'Puente';
  String get introduction => _en ? 'Introduction' : 'Introducción';
  String get other => _en ? 'Other' : 'Otros';
  String get commentLine => _en ? 'Comment line' : 'Línea de comentario';
  String get commentIgnored => _en ? 'Comment (ignored when parsing)' : 'Comentario (ignorado al parsear)';
  String get fullExample => _en ? 'Full example' : 'Ejemplo completo';
}
