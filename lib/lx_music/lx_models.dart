import 'package:eclogae/class/track.dart';

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

enum LxSearchMode {
  songs('歌曲'),
  songlists('歌单');

  const LxSearchMode(this.label);

  final String label;
}

enum LxSearchSource {
  all('聚合'),
  kw('酷我'),
  kg('酷狗'),
  tx('QQ'),
  wy('网易云'),
  mg('咪咕');

  const LxSearchSource(this.label);

  final String label;

  LxPlatform? get platform => switch (this) {
    LxSearchSource.all => null,
    LxSearchSource.kw => LxPlatform.kw,
    LxSearchSource.kg => LxPlatform.kg,
    LxSearchSource.tx => LxPlatform.tx,
    LxSearchSource.wy => LxPlatform.wy,
    LxSearchSource.mg => LxPlatform.mg,
  };
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

  String get uniqueKey => '${source.code}:$id';

  int get durationMs {
    final parts = interval.trim().split(':');
    if (parts.length < 2 || parts.length > 3) return 0;
    var seconds = 0;
    for (var i = 0; i < parts.length; i++) {
      final part = int.tryParse(parts[i], radix: 10);
      if (part == null || part < 0 || (i > 0 && part >= 60)) return 0;
      seconds = seconds * 60 + part;
    }
    return seconds * 1000;
  }

  String? get highestQuality => LxDownloadSettings.qualityOptions.where(qualities.contains).firstOrNull ?? qualities.firstOrNull;

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

class LxSonglist {
  const LxSonglist({
    required this.id,
    required this.name,
    required this.source,
    this.author = '',
    this.img,
    this.playCount = '',
    this.total,
    this.desc = '',
    this.time = '',
  });

  factory LxSonglist.fromJson(Map<String, dynamic> json, LxPlatform platform) => LxSonglist._fromJson(json, platform, null);

  factory LxSonglist._fromJson(Map<String, dynamic> json, LxPlatform platform, LxSonglist? fallback) {
    String? readText(String key) {
      return switch (json[key]) {
        String text when text.trim().isNotEmpty => text,
        num count => count.toString(),
        _ => null,
      };
    }

    final total = json['total'];
    return LxSonglist(
      id: readText('id') ?? fallback?.id ?? '',
      name: readText('name') ?? fallback?.name ?? '',
      source: platform,
      author: readText('author') ?? fallback?.author ?? '',
      img: readText('img') ?? fallback?.img,
      playCount: readText('play_count') ?? fallback?.playCount ?? '',
      total: (total is int ? total : int.tryParse(total is String ? total.trim() : '')) ?? fallback?.total,
      desc: readText('desc') ?? fallback?.desc ?? '',
      time: readText('time') ?? fallback?.time ?? '',
    );
  }

  final String id;
  final String name;
  final String author;
  final String? img;
  final String playCount;
  final int? total;
  final String desc;
  final String time;
  final LxPlatform source;

  String get uniqueKey => '${source.code}:$id';
}

class LxSonglistSearchResult {
  LxSonglistSearchResult.fromJson(Map<String, dynamic> json, LxPlatform platform)
    : list = List.unmodifiable((json['list'] as List<dynamic>).map((item) => LxSonglist.fromJson(item as Map<String, dynamic>, platform))),
      total = json['total'] as int,
      page = json['page'] as int,
      limit = json['limit'] as int;

  final List<LxSonglist> list;
  final int total;
  final int page;
  final int limit;

  bool get hasMore => list.isNotEmpty && page * limit < total;
}

class LxSonglistDetail {
  LxSonglistDetail.fromJson(Map<String, dynamic> json, LxPlatform platform, {LxSonglist? fallbackInfo})
    : info = LxSonglist._fromJson(json['info'] as Map<String, dynamic>? ?? const {}, platform, fallbackInfo),
      tracks = List.unmodifiable((json['list'] as List<dynamic>).map((item) => LxTrack.fromMusicInfo(platform, item as Map<String, dynamic>))),
      total = json['total'] as int,
      page = json['page'] as int,
      limit = json['limit'] as int;

  final LxSonglist info;
  final List<LxTrack> tracks;
  final int total;
  final int page;
  final int limit;

  bool get hasMore => tracks.isNotEmpty && (limit > 0 ? page * limit < total : tracks.length < total);
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

class LxUpdateAlert {
  const LxUpdateAlert({required this.sourceName, required this.log, this.updateUrl});

  final String sourceName;
  final String log;
  final String? updateUrl;
}

class LxDownloadSettings {
  const LxDownloadSettings({
    this.downloadDir,
    this.archiveSonglistToSubfolder = true,
    this.preferredQuality = 'flac',
    this.previewQuality = '320k',
    this.autoSwitchSource = true,
    this.exportLrc = true,
    this.embedCover = true,
    this.rememberLastQuality = false,
    this.lastSelectedQuality,
    this.includeTranslationLyric = true,
    this.includeRomanizationLyric = true,
    this.maxConcurrent = 1,
  });

  static const qualityOptions = ['flac24bit', 'flac', '320k', '128k'];
  static const concurrentOptions = [1, 2, 3];
  static const _unchanged = Object();

  final String? downloadDir;
  final bool archiveSonglistToSubfolder;
  final String preferredQuality;
  final String previewQuality;
  final bool autoSwitchSource;
  final bool exportLrc;
  final bool embedCover;
  final bool rememberLastQuality;
  final String? lastSelectedQuality;
  final bool includeTranslationLyric;
  final bool includeRomanizationLyric;
  final int maxConcurrent;

  static String qualityLabel(String quality) => switch (quality) {
    'flac24bit' => 'FLAC Hi-Res',
    'flac' => 'FLAC 无损',
    '320k' => 'MP3 320K',
    '128k' => 'MP3 128K',
    _ => quality,
  };

  static String qualityBadge(String quality) => switch (quality) {
    'flac24bit' => 'Hi-Res',
    'flac' => 'SQ',
    '320k' => 'HQ',
    '128k' => 'STD',
    _ => quality.toUpperCase(),
  };

  String get effectiveQuickQuality {
    final selected = lastSelectedQuality;
    return rememberLastQuality && selected != null && qualityOptions.contains(selected) ? selected : preferredQuality;
  }

  LxDownloadSettings copyWith({
    Object? downloadDir = _unchanged,
    bool? archiveSonglistToSubfolder,
    String? preferredQuality,
    String? previewQuality,
    bool? autoSwitchSource,
    bool? exportLrc,
    bool? embedCover,
    bool? rememberLastQuality,
    Object? lastSelectedQuality = _unchanged,
    bool? includeTranslationLyric,
    bool? includeRomanizationLyric,
    int? maxConcurrent,
  }) => LxDownloadSettings(
    downloadDir: identical(downloadDir, _unchanged) ? this.downloadDir : downloadDir as String?,
    archiveSonglistToSubfolder: archiveSonglistToSubfolder ?? this.archiveSonglistToSubfolder,
    preferredQuality: preferredQuality ?? this.preferredQuality,
    previewQuality: previewQuality ?? this.previewQuality,
    autoSwitchSource: autoSwitchSource ?? this.autoSwitchSource,
    exportLrc: exportLrc ?? this.exportLrc,
    embedCover: embedCover ?? this.embedCover,
    rememberLastQuality: rememberLastQuality ?? this.rememberLastQuality,
    lastSelectedQuality: identical(lastSelectedQuality, _unchanged) ? this.lastSelectedQuality : lastSelectedQuality as String?,
    includeTranslationLyric: includeTranslationLyric ?? this.includeTranslationLyric,
    includeRomanizationLyric: includeRomanizationLyric ?? this.includeRomanizationLyric,
    maxConcurrent: maxConcurrent ?? this.maxConcurrent,
  );

  factory LxDownloadSettings.fromJson(Map<String, dynamic> json) => LxDownloadSettings(
    downloadDir: json['downloadDir'] as String?,
    archiveSonglistToSubfolder: json['archiveSonglistToSubfolder'] as bool? ?? true,
    preferredQuality: json['preferredQuality'] as String? ?? 'flac',
    previewQuality: qualityOptions.contains(json['previewQuality']) ? json['previewQuality'] as String : '320k',
    autoSwitchSource: json['autoSwitchSource'] as bool? ?? true,
    exportLrc: json['exportLrc'] as bool? ?? true,
    embedCover: json['embedCover'] as bool? ?? true,
    rememberLastQuality: json['rememberLastQuality'] as bool? ?? false,
    lastSelectedQuality: json['lastSelectedQuality'] as String?,
    includeTranslationLyric: json['includeTranslationLyric'] as bool? ?? true,
    includeRomanizationLyric: json['includeRomanizationLyric'] as bool? ?? true,
    maxConcurrent: (json['maxConcurrent'] as int? ?? 1).clamp(1, 3).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'downloadDir': downloadDir,
    'archiveSonglistToSubfolder': archiveSonglistToSubfolder,
    'preferredQuality': preferredQuality,
    'previewQuality': previewQuality,
    'autoSwitchSource': autoSwitchSource,
    'exportLrc': exportLrc,
    'embedCover': embedCover,
    'rememberLastQuality': rememberLastQuality,
    'lastSelectedQuality': lastSelectedQuality,
    'includeTranslationLyric': includeTranslationLyric,
    'includeRomanizationLyric': includeRomanizationLyric,
    'maxConcurrent': maxConcurrent,
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
    this.subfolderName,
    this.stage = LxDownloadStage.queued,
    this.resolvedQuality,
    this.resolvedSource,
    this.resolveDetail,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.bytesPerSecond = 0,
    this.savedPath,
    this.lrcPath,
    this.indexedTrack,
    this.failedStage,
    this.errorMessage,
  });

  final String id;
  final LxTrack track;
  final String requestedQuality;
  final String? subfolderName;
  final LxDownloadStage stage;
  final String? resolvedQuality;
  final LxPlatform? resolvedSource;
  final String? resolveDetail;
  final int receivedBytes;
  final int totalBytes;
  final int bytesPerSecond;
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
    int? bytesPerSecond,
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
    subfolderName: subfolderName,
    stage: stage ?? this.stage,
    resolvedQuality: resolvedQuality ?? this.resolvedQuality,
    resolvedSource: resolvedSource ?? this.resolvedSource,
    resolveDetail: resolveDetail ?? this.resolveDetail,
    receivedBytes: receivedBytes ?? this.receivedBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
    savedPath: savedPath ?? this.savedPath,
    lrcPath: lrcPath ?? this.lrcPath,
    indexedTrack: indexedTrack ?? this.indexedTrack,
    failedStage: failedStage ?? this.failedStage,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}
