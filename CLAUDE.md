# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter Android app for musicians. Displays ChordPro song files (`.cho` / `.chordpro`) with chords above lyrics, designed for live performance on a music stand controlled by a Bluetooth foot pedal.

- **Target:** Android mobile (portrait) + tablet (landscape)
- **Language:** Spanish — all UI labels and code comments are in Spanish
- **State management:** Riverpod 2.x (`NotifierProvider` / `AsyncNotifierProvider`) — no code generation
- **Local storage:** Hive — serialized as raw `Map`, no `TypeAdapter` code generation

## Setup

`pubspec.yaml` exists. To get started:

```bash
cd chord_viewer
flutter pub get
flutter run
```

For Android storage permissions (needed on Android ≤ 9), add to `android/app/src/main/AndroidManifest.xml` inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
```

For Google Drive to work, register the app in Google Cloud Console (see `lib/services/drive_service.dart` header for full instructions).

## Commands

```bash
flutter run                                   # Run on connected device/emulator
flutter test                                  # All tests (no device needed)
flutter test test/chord_utils_test.dart       # Single test file
flutter analyze                               # Static analysis
flutter pub get                               # After pubspec.yaml changes
```

## File inventory

```
lib/
├── main.dart                    Entry point: init Hive boxes → ProviderScope → HomeScreen
│
├── core/
│   ├── theme/app_theme.dart     ViewerColors (const) + ViewerTextStyles (fontSize-param methods)
│   └── utils/chord_utils.dart   Pure transposition logic: transposeChord, transposeSong, keyPrefersFlats
│
├── models/                      Plain Dart, no Flutter, all immutable
│   ├── song.dart                Full parsed song (lines + rawContent + metadata)
│   ├── song_line.dart           SongLine (lyric|section|empty) + ChordSegment
│   ├── song_summary.dart        Lightweight metadata for library list; toMap/fromMap for Hive
│   ├── setlist.dart             Setlist (ordered songIds) + SetlistContext (index in setlist)
│   ├── pedal_settings.dart      PedalSettings + PedalScrollMode; keyToString/keyFromString for Hive
│   └── drive_file.dart          DriveFile (id, name, sizeBytes) from Drive API
│
├── services/                    Business logic; no Flutter widgets
│   ├── chordpro_parser.dart     ChordProParser.parse() — static, pure: String → Song
│   ├── file_service.dart        pickAndImportSongs() copies files to documents/songs/
│   ├── storage_service.dart     Hive CRUD for songs, setlists, settings (3 boxes)
│   └── drive_service.dart       Google Sign-In + Drive API; _GoogleAuthClient bridges auth
│
├── providers/                   Riverpod state — all use NotifierProvider except drive
│   ├── library_provider.dart    List<SongSummary>; importSongs(), addSong(), removeSong()
│   ├── setlists_provider.dart   List<Setlist>; full CRUD + addSong/removeSong/reorderSongs
│   ├── settings_provider.dart   AppSettings (pedal + fontSizeMultiplier); persists to Hive
│   └── drive_provider.dart      AsyncNotifier<DriveState>; signIn, loadFiles, importFile
│
└── screens/
    ├── home_screen.dart         IndexedStack of LibraryScreen + SetlistsScreen + NavigationBar
    ├── viewer/
    │   ├── viewer_screen.dart   Main display; ConsumerStatefulWidget with local transpose state
    │   └── widgets/
    │       ├── chord_line.dart  Wrap of IntrinsicWidth columns (chord above text)
    │       └── song_header.dart Title, artist, key/capo/tempo chips
    ├── library/
    │   ├── library_screen.dart  Filterable list; AppBar has Drive (☁) + Settings (⚙) icons
    │   └── widgets/song_tile.dart
    ├── setlists/
    │   ├── setlists_screen.dart  CRUD setlists; long-press → rename/delete
    │   └── setlist_detail_screen.dart  ReorderableListView + add-from-library sheet
    ├── drive/
    │   └── drive_screen.dart    Auth flow + file list + per-file import
    └── settings/
        └── settings_screen.dart  Font slider (live preview) + key picker sheet + scroll mode
```

## Architecture

Strict layered dependency: `screens → providers → services → models`. Lower layers never import upper ones.

```
screens      UI only; read providers with ref.watch / ref.read
providers    Riverpod Notifiers; call services, own state
services     Business logic + I/O; return models
models       Pure Dart data classes; no external dependencies
core/        Cross-cutting: theme constants, pure utility functions
```

## Key data flows

### Importing a local file
```
FilePicker → FileService.pickAndImportSongs()
           → copies file to documents/songs/<name>.cho
           → ChordProParser.parse(content, filePath)  → Song
           → SongSummary.fromSong(song)
           → StorageService.saveSong(summary)          → Hive box 'songs_metadata'
           → LibraryNotifier.state = getAllSongs()     → UI rebuilds
```

### Opening a song to view
```
LibraryScreen tap → FileService.loadSong(summary.filePath)
                  → ChordProParser.parse(content)  → Song
                  → Navigator.push(ViewerScreen(song: song))
```

### Transposing in the viewer
```
_transpose++ (local state)
→ build() calls ChordUtils.transposeSong(widget.song, _transpose, useFlats: _useFlats)
→ returns new Song with transposed chords (original file untouched)
→ displaySong passed to SongHeader + ListView — UI updates immediately
```

### Importing from Google Drive
```
DriveService.signIn()         → GoogleSignInAccount
DriveService.listChordProFiles() → DriveAPI.files.list() → List<DriveFile>
DriveService.downloadSong(file)  → streams bytes → utf8.decode
                                 → writes to documents/songs/
                                 → ChordProParser.parse()  → Song
DriveNotifier.importFile()    → ref.read(libraryProvider.notifier).addSong(summary)
```

## Hive storage

Three boxes opened in `StorageService.init()` before `runApp`:

| Box name | Key type | Value type | Sorted by |
|---|---|---|---|
| `songs_metadata` | `Song.id` (String) | `Map` via `SongSummary.toMap()` | title (alpha) |
| `setlists_metadata` | `Setlist.id` (String) | `Map` via `Setlist.toMap()` | createdAt desc |
| `app_settings` | `'settings'` (single key) | `Map` via `AppSettings.toMap()` | — |

No `TypeAdapter` or code generation. All objects serialize to `Map<String, dynamic>` with primitive values only (`String`, `int`, `double`, `List<String>`).

**`Song.id` generation:** `filePath.hashCode.abs().toString()` for file-based songs. Stable for the same path; changes if the file is moved.

## Riverpod providers

| Provider | Type | State | Key methods |
|---|---|---|---|
| `libraryProvider` | `NotifierProvider` | `List<SongSummary>` | `importSongs()`, `addSong()`, `removeSong()` |
| `setlistsProvider` | `NotifierProvider` | `List<Setlist>` | `createSetlist()`, `addSong()`, `reorderSongs()` |
| `settingsProvider` | `NotifierProvider` | `AppSettings` | `updatePedalSettings()`, `updateFontSize()` |
| `driveProvider` | `AsyncNotifierProvider` | `DriveState` | `signIn()`, `loadFiles()`, `importFile()` |

`driveProvider` uses `AsyncNotifier` because `build()` calls `DriveService.signInSilently()` (async). Access it with `.when(loading, error, data)` in the UI.

`DriveNotifier.importFile()` crosses provider boundaries: it calls `ref.read(libraryProvider.notifier).addSong()` to register the downloaded song in the library.

## Chord rendering

Each `ChordSegment` (chord + text) renders as an `IntrinsicWidth` column:

```
Am7          ← chord (ViewerTextStyles.chord, amber, monospace)
mundo        ← text  (ViewerTextStyles.lyric, white)
```

Multiple segments grouped in a `Wrap`. `IntrinsicWidth` ensures a wide chord (`Cmaj7`) expands the column width so it never overlaps the next chord. Lines without any chord skip the chord row entirely (no wasted vertical space).

Font size flows as a `double` parameter down the widget tree — never looked up from `Theme`. Base is `22.0 * fontSizeMultiplier * tabletFactor`, where `tabletFactor = 1.3` when screen width ≥ 600px.

## Pedal Bluetooth

The foot pedal connects as a Bluetooth HID keyboard. `ViewerScreen` wraps its `ListView` in a `Focus(autofocus: true, onKeyEvent: _onKeyEvent)`.

`_onKeyEvent` only reacts to `KeyDownEvent` (not `KeyRepeatEvent`) to prevent unintended multi-scroll when holding down.

**Two scroll modes** (configurable in Settings):

- `byAmount`: `scrollController.animateTo(offset + viewportHeight * scrollFraction)` — simple, always predictable
- `bySection`: pre-computed `_sectionTargets` list (estimated Y offsets per section). Estimates are arithmetic (not from actual layout), so ±10% accuracy — good enough for navigation.

`PedalSettings` serializes `LogicalKeyboardKey` as a string name via `_keyMap` (e.g. `'pageDown'`). Adding a new key requires adding it to that map.

## SetlistContext

`SetlistContext` is passed as a constructor parameter to `ViewerScreen` — it is **not** in a provider. This makes each viewer instance self-contained.

When navigating to next/prev song within a setlist, `ViewerScreen` uses `Navigator.pushReplacement` (not `push`) so the back stack doesn't grow unboundedly during a concert. Back always returns to `SetlistDetailScreen`.

## Navigation structure

```
HomeScreen (IndexedStack)
├── tab 0: LibraryScreen    → push → ViewerScreen
│                           → push → DriveScreen
│                           → push → SettingsScreen
└── tab 1: SetlistsScreen   → push → SetlistDetailScreen
                                    → push → ViewerScreen(song, setlistContext)
                                             → pushReplacement → ViewerScreen (next/prev song)
```

## Styling

All colors are in `ViewerColors` (static constants). All text styles are in `ViewerTextStyles` (static methods accepting `fontSize: double`). Never hardcode `Color(...)` or `TextStyle(...)` outside of these classes.

Dark theme only. Background `#121212`, lyrics `#EEEEEE`, chords `#FFB300` (amber), sections `#64B5F6` (blue), artist/subtitle `#9E9E9E`.

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| `flutter_riverpod` | ^2.5.1 | State management (no code-gen variant) |
| `hive_flutter` | ^1.1.0 | Local key-value storage (no TypeAdapters) |
| `file_picker` | ^8.0.3 | System file picker for .cho/.chordpro |
| `path_provider` | ^2.1.3 | `getApplicationDocumentsDirectory()` for persistent file copies |
| `permission_handler` | ^11.3.1 | READ_EXTERNAL_STORAGE on Android ≤ 9 |
| `google_sign_in` | ^6.2.1 | OAuth for Google Drive |
| `googleapis` | ^13.2.0 | Drive API v3 (files.list, files.get) |
| `http` | ^1.2.1 | `BaseClient` subclass to inject OAuth headers |

## Tests

```
test/
├── chordpro_parser_test.dart   16 tests: metadata extraction, lyric parsing, sections, edge cases
└── chord_utils_test.dart       22 tests: single chords, suffixes, slash chords, wrapping, flats/sharps
```

Run with `flutter test` — no device or emulator needed.
