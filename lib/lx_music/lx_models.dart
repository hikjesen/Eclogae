import 'package:namida/class/track.dart';

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

class LxDownloadSettings {
  const LxDownloadSettings({
    this.downloadDir,
    this.preferredQuality = 'flac',
    this.autoSwitchSource = true,
    this.exportLrc = true,
    this.embedCover = true,
  });

  static const qualityOptions = ['flac24bit', 'flac', '320k', '128k'];
  static const _unchanged = Object();

  final String? downloadDir;
  final String preferredQuality;
  final bool autoSwitchSource;
  final bool exportLrc;
  final bool embedCover;

  LxDownloadSettings copyWith({
    Object? downloadDir = _unchanged,
    String? preferredQuality,
    bool? autoSwitchSource,
    bool? exportLrc,
    bool? embedCover,
  }) => LxDownloadSettings(
    downloadDir: identical(downloadDir, _unchanged) ? this.downloadDir : downloadDir as String?,
    preferredQuality: preferredQuality ?? this.preferredQuality,
    autoSwitchSource: autoSwitchSource ?? this.autoSwitchSource,
    exportLrc: exportLrc ?? this.exportLrc,
    embedCover: embedCover ?? this.embedCover,
  );

  factory LxDownloadSettings.fromJson(Map<String, dynamic> json) => LxDownloadSettings(
    downloadDir: json['downloadDir'] as String?,
    preferredQuality: json['preferredQuality'] as String? ?? 'flac',
    autoSwitchSource: json['autoSwitchSource'] as bool? ?? true,
    exportLrc: json['exportLrc'] as bool? ?? true,
    embedCover: json['embedCover'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'downloadDir': downloadDir,
    'preferredQuality': preferredQuality,
    'autoSwitchSource': autoSwitchSource,
    'exportLrc': exportLrc,
    'embedCover': embedCover,
  };
}

enum LxDownloadStage {
  queued('排队中'),
  resolving('解析直链'),
  downloading('网络下载'),
  verifying('文件头校验'),
  tagging('标签与入库'),
  completed('已完成'),
  failed('失败'),
  canceled('已取消');

  const LxDownloadStage(this.label);

  final String label;
}

class LxDownloadTask {
  const LxDownloadTask({
    required this.id,
    required this.track,
    required this.requestedQuality,
    required this.createdAt,
    this.stage = LxDownloadStage.queued,
    this.resolvedQuality,
    this.resolvedSource,
    this.resolveDetail,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.savedPath,
    this.lrcPath,
    this.indexedTrack,
    this.failedStage,
    this.errorMessage,
  });

  final String id;
  final LxTrack track;
  final String requestedQuality;
  final LxDownloadStage stage;
  final String? resolvedQuality;
  final LxPlatform? resolvedSource;
  final String? resolveDetail;
  final int receivedBytes;
  final int totalBytes;
  final String? savedPath;
  final String? lrcPath;
  final Track? indexedTrack;
  final LxDownloadStage? failedStage;
  final String? errorMessage;
  final DateTime createdAt;

  bool get isActive => switch (stage) {
    LxDownloadStage.completed || LxDownloadStage.failed || LxDownloadStage.canceled => false,
    _ => true,
  };

  bool get canRetry => stage == LxDownloadStage.failed || stage == LxDownloadStage.canceled;
  bool get canCancel => isActive && stage != LxDownloadStage.tagging;
  double? get progress => totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0).toDouble() : null;

  LxDownloadTask copyWith({
    String? requestedQuality,
    LxDownloadStage? stage,
    String? resolvedQuality,
    LxPlatform? resolvedSource,
    String? resolveDetail,
    int? receivedBytes,
    int? totalBytes,
    String? savedPath,
    String? lrcPath,
    Track? indexedTrack,
    LxDownloadStage? failedStage,
    String? errorMessage,
  }) => LxDownloadTask(
    id: id,
    track: track,
    requestedQuality: requestedQuality ?? this.requestedQuality,
    createdAt: createdAt,
    stage: stage ?? this.stage,
    resolvedQuality: resolvedQuality ?? this.resolvedQuality,
    resolvedSource: resolvedSource ?? this.resolvedSource,
    resolveDetail: resolveDetail ?? this.resolveDetail,
    receivedBytes: receivedBytes ?? this.receivedBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    savedPath: savedPath ?? this.savedPath,
    lrcPath: lrcPath ?? this.lrcPath,
    indexedTrack: indexedTrack ?? this.indexedTrack,
    failedStage: failedStage ?? this.failedStage,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}
