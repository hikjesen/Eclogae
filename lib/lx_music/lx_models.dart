enum LxPlatform {
  kw('酷我'),
  kg('酷狗'),
  tx('QQ'),
  wy('网易云'),
  mg('咪咕');

  const LxPlatform(this.label);

  String get code => name;
  final String label;
}

class LxTrack {
  LxTrack.fromMusicInfo(this.source, this.rawMusicInfo)
    : id = (rawMusicInfo['id'] ?? rawMusicInfo['songmid']).toString(),
      name = rawMusicInfo['name'] as String,
      singer = rawMusicInfo['singer'] as String? ?? '',
      albumName = rawMusicInfo['albumName'] as String? ?? '',
      interval = rawMusicInfo['interval']?.toString() ?? '',
      picUrl = (rawMusicInfo['picUrl'] ?? rawMusicInfo['img']) as String?,
      qualities = _readQualities(rawMusicInfo);

  final String id;
  final String name;
  final String singer;
  final String albumName;
  final String interval;
  final LxPlatform source;
  final String? picUrl;
  final List<String> qualities;
  final Map<String, dynamic> rawMusicInfo;

  static List<String> _readQualities(Map<String, dynamic> info) {
    final types = info['types'] as List<dynamic>?;
    final indexed = info['_types'] as Map<String, dynamic>?;
    return List.unmodifiable({
      if (types != null)
        for (final entry in types) (entry as Map<String, dynamic>)['type'] as String,
      ...?indexed?.keys,
    });
  }
}

class LxSearchResult {
  LxSearchResult.fromJson(Map<String, dynamic> json, LxPlatform platform)
    : tracks = List.unmodifiable(
        (json['list'] as List<dynamic>).map((item) => LxTrack.fromMusicInfo(platform, item as Map<String, dynamic>)),
      ),
      total = json['total'] as int,
      page = json['page'] as int,
      limit = json['limit'] as int,
      allPage = json['allPage'] as int;

  final List<LxTrack> tracks;
  final int total;
  final int page;
  final int limit;
  final int allPage;
}

class LxLyricResult {
  LxLyricResult.fromJson(Map<String, dynamic> json)
    : lyric = json['lyric'] as String? ?? '',
      tlyric = json['tlyric'] as String?,
      rlyric = json['rlyric'] as String?,
      lxlyric = json['lxlyric'] as String?;

  final String lyric;
  final String? tlyric;
  final String? rlyric;
  final String? lxlyric;
}

class LxUserApiMeta {
  const LxUserApiMeta({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.author,
    required this.homepage,
    required this.fileName,
    required this.importedAt,
  });

  factory LxUserApiMeta.fromJson(Map<String, dynamic> json) => LxUserApiMeta(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    version: json['version'] as String,
    author: json['author'] as String,
    homepage: json['homepage'] as String,
    fileName: json['fileName'] as String,
    importedAt: DateTime.parse(json['importedAt'] as String),
  );

  final String id;
  final String name;
  final String description;
  final String version;
  final String author;
  final String homepage;
  final String fileName;
  final DateTime importedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'version': version,
    'author': author,
    'homepage': homepage,
    'fileName': fileName,
    'importedAt': importedAt.toIso8601String(),
  };
}

enum LxUserApiStatus { idle, loading, ready, error }

class LxUserApiState {
  const LxUserApiState({
    this.status = LxUserApiStatus.idle,
    this.meta,
    this.supportedQualities = const {},
    this.supportedActions = const {},
    this.errorMessage,
  });

  final LxUserApiStatus status;
  final LxUserApiMeta? meta;
  final Map<String, List<String>> supportedQualities;
  final Map<String, List<String>> supportedActions;
  final String? errorMessage;
}

class LxLogEntry {
  const LxLogEntry({required this.timestamp, required this.engine, required this.level, required this.message});

  final DateTime timestamp;
  final String engine;
  final String level;
  final String message;

  @override
  String toString() => '${timestamp.toIso8601String()} [$engine/$level] $message';
}
