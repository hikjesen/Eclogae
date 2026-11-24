class PlaylistID {
  const PlaylistID({required this.id});
  final String id;

  factory PlaylistID.fromJson(Map<String, Object?> json) => PlaylistID(id: json['id'] as String);

  Map<String, Object?> toJson() => {'id': id};
}

abstract final class YTPlaylistIdUtils {
  static bool isUserCreated(String id) => id.startsWith('PL');
}
