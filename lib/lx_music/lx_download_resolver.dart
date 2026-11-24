import 'lx_bridge_service.dart';
import 'lx_models.dart';

class LxResolvedDownload {
  LxResolvedDownload({required this.url, required this.quality, required this.track, required this.detail, required List<String> attempts})
    : attempts = List.unmodifiable(attempts);

  final String url;
  final String quality;
  final LxTrack track;
  final String detail;
  final List<String> attempts;
}

abstract final class LxDownloadResolver {
  static const qualityLadder = LxDownloadSettings.qualityOptions;
  static const _sourcePriority = [LxPlatform.kw, LxPlatform.tx, LxPlatform.wy, LxPlatform.kg, LxPlatform.mg];
  static final _singerSeparators = RegExp(r'[\s,，、/&＆;+；|·]+');
  static final _intervalPattern = RegExp(r'^(\d{1,4}):([0-5]\d)$');

  static Future<LxResolvedDownload> resolve({
    required LxTrack track,
    required String preferredQuality,
    required bool autoSwitchSource,
  }) async {
    final bridge = LxBridgeService.inst;
    final api = bridge.userApiStateNotifier.value;
    if (api.status != LxUserApiStatus.ready) throw StateError(api.errorMessage ?? '请先启用并初始化自定义音源');
    final start = qualityLadder.indexOf(preferredQuality);
    if (start < 0) throw ArgumentError.value(preferredQuality, 'preferredQuality', '不支持的下载音质');
    final qualities = qualityLadder.skip(start);
    final attempts = <String>[];

    final original = await _tryTrack(track, track.source, api, qualities, attempts);
    if (original != null) return original;

    if (autoSwitchSource) {
      for (final source in _sourcePriority) {
        if (source == track.source || api.supportedActions[source.code]?.contains('musicUrl') != true) continue;
        final match = await _searchMatch(track, source, attempts);
        if (match == null) continue;
        final alternate = await _tryTrack(match, track.source, api, qualities, attempts);
        if (alternate != null) return alternate;
      }
    }

    throw StateError('所有音质与音源解析均失败：${attempts.take(6).join('；')}');
  }

  static Future<LxResolvedDownload?> _tryTrack(
    LxTrack track,
    LxPlatform originalSource,
    LxUserApiState api,
    Iterable<String> qualities,
    List<String> attempts,
  ) async {
    final source = track.source;
    if (api.supportedActions[source.code]?.contains('musicUrl') != true) {
      attempts.add('${source.label}: 当前音源不支持直链解析');
      return null;
    }
    final supported = api.supportedQualities[source.code] ?? const <String>[];
    final available = qualities.where(supported.contains).toList();
    if (available.isEmpty) attempts.add('${source.label}: 没有符合要求的音质');
    final candidates = [
      ...available.where(track.qualities.contains),
      ...available.where((quality) => !track.qualities.contains(quality)),
    ];

    for (final quality in candidates) {
      try {
        final resolved = await LxBridgeService.inst.resolveMusicUrl(track: track, quality: quality);
        final sourceDetail = source == originalSource ? '原始音源' : '自动换源';
        return LxResolvedDownload(
          url: resolved.url,
          quality: resolved.quality,
          track: track,
          detail: '$sourceDetail · ${source.label}/${resolved.quality}',
          attempts: attempts,
        );
      } catch (error) {
        attempts.add('${source.label}/$quality: ${_reason(error)}');
      }
    }
    return null;
  }

  static Future<LxTrack?> _searchMatch(LxTrack track, LxPlatform source, List<String> attempts) async {
    final LxSearchResult result;
    try {
      result = await LxBridgeService.inst.search(platform: source, keyword: '${track.name} ${track.singer}'.trim(), page: 1, limit: 5);
    } catch (error) {
      attempts.add('${source.label}/搜索: ${_reason(error)}');
      return null;
    }

    final title = track.name.trim().toLowerCase();
    final singer = track.singer.trim().toLowerCase();
    final singers = singer.split(_singerSeparators).where((token) => token.isNotEmpty).toSet();
    final duration = _seconds(track.interval);
    LxTrack? best;
    var bestScore = -1;
    for (final candidate in result.tracks) {
      final candidateTitle = candidate.name.trim().toLowerCase();
      if (title.isEmpty || candidateTitle.isEmpty || (!title.contains(candidateTitle) && !candidateTitle.contains(title))) continue;
      final candidateSinger = candidate.singer.trim().toLowerCase();
      if (!candidateSinger.split(_singerSeparators).any(singers.contains)) continue;
      final candidateDuration = _seconds(candidate.interval);
      final difference = duration != null && candidateDuration != null ? (duration - candidateDuration).abs() : null;
      if (difference != null && difference > 8) continue;

      final score = (candidateTitle == title ? 20 : 0) + (candidateSinger == singer ? 10 : 0) + (difference == null ? 0 : 9 - difference);
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    if (best == null) attempts.add('${source.label}/搜索: 未找到匹配歌曲');
    return best;
  }

  static int? _seconds(String interval) {
    final match = _intervalPattern.firstMatch(interval.trim());
    return match == null ? null : int.parse(match[1]!) * 60 + int.parse(match[2]!);
  }

  static String _reason(Object error) => error.toString().replaceFirst('Exception: ', '');
}
