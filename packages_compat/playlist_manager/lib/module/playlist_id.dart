class PlaylistID {
  final String id;

  const PlaylistID({required this.id});

  factory PlaylistID.fromJson(Object? json) {
    if (json is String) return PlaylistID(id: json);
    if (json is Map && json['id'] is String) return PlaylistID(id: json['id'] as String);
    throw const FormatException('Invalid playlist ID');
  }

  Map<String, dynamic> toJson() => {'id': id};

  @override
  bool operator ==(Object other) => other is PlaylistID && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}
