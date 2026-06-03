// lib/models/setlist.dart

/// Una lista de reproducción ordenada de canciones para un concierto o ensayo.
///
/// Guarda solo los IDs de las canciones (no copias de los datos), para que
/// si actualizas una canción en la biblioteca, el setlist la refleje.
class Setlist {
  final String id;
  final String name;

  /// IDs ordenados de las canciones. El orden en esta lista es el orden
  /// en que se tocarán en el concierto.
  final List<String> songIds;

  final DateTime createdAt;

  const Setlist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
  });

  int get songCount => songIds.length;

  Setlist copyWith({String? name, List<String>? songIds}) => Setlist(
        id: id,
        name: name ?? this.name,
        songIds: songIds ?? this.songIds,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'songIds': List<String>.from(songIds),
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Setlist.fromMap(Map map) => Setlist(
        id: map['id'] as String,
        name: map['name'] as String,
        songIds: List<String>.from(map['songIds'] as List),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      );

  @override
  String toString() => name;
}

// -----------------------------------------------------------------------------

/// Contexto que indica que el [ViewerScreen] fue abierto desde un setlist.
///
/// Se usa para mostrar la posición actual ("3 / 8") y los botones prev/next.
class SetlistContext {
  final Setlist setlist;

  /// Índice (base 0) de la canción actual dentro de [setlist.songIds].
  final int currentIndex;

  const SetlistContext({
    required this.setlist,
    required this.currentIndex,
  });

  bool get hasPrev => currentIndex > 0;
  bool get hasNext => currentIndex < setlist.songIds.length - 1;

  /// Texto de posición legible: "3 / 8"
  String get positionText => '${currentIndex + 1} / ${setlist.songIds.length}';

  String? get prevSongId =>
      hasPrev ? setlist.songIds[currentIndex - 1] : null;

  String? get nextSongId =>
      hasNext ? setlist.songIds[currentIndex + 1] : null;

  SetlistContext withIndex(int index) =>
      SetlistContext(setlist: setlist, currentIndex: index);
}
