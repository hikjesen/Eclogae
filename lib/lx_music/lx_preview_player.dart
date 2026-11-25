import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:crypto/crypto.dart' show sha256;
import 'package:just_audio/just_audio.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

import 'lx_bridge_service.dart';
import 'lx_download_manager.dart';
import 'lx_download_resolver.dart';
import 'lx_models.dart';
import 'lx_settings_page.dart';
import 'widgets/lx_download_actions.dart';
import 'widgets/lx_lyrics_sheet.dart';

class LxPreviewPlayer {
  LxPreviewPlayer._();

  static final inst = LxPreviewPlayer._();
  static const pathPrefix = 'http://lx.preview.namida.invalid/track?d=';
  static const _streamUa = 'Mozilla/5.0 (Linux; Android 10; Pixel 3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.79 Mobile Safari/537.36';
  static const _queueTitle = '在线试听';
  static const _maxTracks = 250;
  static const _maxCovers = 40;
  static const _maxAudioCacheBytes = 200 * 1024 * 1024;
  static const _audioExts = ['flac', 'mp3', 'm4a', 'ogg', 'wav', 'aac', 'opus'];

  static String get _audioCacheDir => FileParts.joinPath(AppDirs.APP_CACHE, 'preview_audio');
  static String get _artworkCacheDir => FileParts.joinPath(AppDirs.APP_CACHE, 'preview_artwork');

  static bool isPreviewPath(String path) => path.startsWith(pathPrefix);
  static String previewPathFor(LxTrack track) => '$pathPrefix${Uri.encodeQueryComponent('${track.source.code}_${track.id}')}';

  final _tracks = <String, LxTrack>{};
  final _trackExts = <String, TrackExtended>{};
  final _lyricsCache = <String, String>{};
  final _artBytesCache = <String, Uint8List>{};
  final _completedCachePaths = <String, String>{};
  final _pendingQueues = <List<Track>>{};
  final _downloads = LxDownloadManager.inst;
  final _bridge = LxBridgeService.inst;
  String? _activeCacheFilePath;

  LxTrack? trackForPath(String path) => _tracks[path];
  TrackExtended? trackExtForPath(String path) => _trackExts[path];

  Track? get _currentPreviewTrack {
    final item = Player.inst.currentItem.value;
    return item is Selectable && isPreviewPath(item.track.path) ? item.track : null;
  }

  LxTrack? get currentPreviewTrack {
    final track = _currentPreviewTrack;
    return track == null ? null : trackForPath(track.path);
  }

  Track registerTrack(LxTrack lxTrack) {
    final track = _registerTrack(lxTrack);
    _trimTracks(keepPath: track.path);
    return track;
  }

  void trimTracks() => _trimTracks();

  Track _registerTrack(LxTrack lxTrack) {
    final path = previewPathFor(lxTrack);
    final quality = lxTrack.highestQuality;
    _tracks.remove(path);
    _tracks[path] = lxTrack;
    _trackExts[path] ??= kDummyExtendedTrack.copyWith(
      title: lxTrack.name,
      originalArtist: lxTrack.singer,
      artistsList: lxTrack.singer.isEmpty ? const [] : [lxTrack.singer],
      originalAlbum: lxTrack.albumName,
      albumsList: lxTrack.albumName.isEmpty ? const [] : [lxTrack.albumName],
      durationMS: lxTrack.durationMs,
      path: path,
      format: _formatLabel(quality),
      bitrate: _bitrateForQuality(quality),
      isLossless: _isLossless(quality),
      generatePathHash: false,
    );
    return Track.explicit(path);
  }

  void _trimTracks({String? keepPath}) {
    if (_tracks.length <= _maxTracks) return;
    final protected = {
      keepPath,
      for (final item in Player.inst.currentQueue.value.whereType<Selectable>()) item.track.path,
      for (final queue in _pendingQueues)
        for (final track in queue) track.path,
    };
    for (final path in _tracks.keys.where((path) => !protected.contains(path)).take(_tracks.length - _maxTracks).toList()) {
      _tracks.remove(path);
      _trackExts.remove(path);
      _lyricsCache.remove(path);
      _artBytesCache.remove(path);
      _completedCachePaths.remove(path);
    }
  }

  Future<void> _withRegisteredQueue(List<LxTrack> tracks, Future<void> Function(List<Track>) play) async {
    if (Player.inst.partyGate != null) {
      snackyy(icon: Broken.info_circle, message: '一起听期间无法在线试听');
      return;
    }
    final registered = tracks.map(_registerTrack).toList();
    _pendingQueues.add(registered);
    _trimTracks();
    try {
      await play(registered);
    } finally {
      _pendingQueues.remove(registered);
      _trimTracks();
    }
  }

  Future<void> playTrack(LxTrack track) => _withRegisteredQueue([track], (registered) async {
    final player = Player.inst;
    if (currentPreviewTrack != null) {
      await player.playKeepingQueue(registered, QueueSource.others(_queueTitle));
    } else {
      await player.playOrPause(0, registered, QueueSource.others(_queueTitle), updateQueue: false, canAskBeforeReplacing: false);
    }
  });

  Future<void> playQueue(List<LxTrack> tracks, {int initialIndex = 0, String sourceTitle = _queueTitle}) async {
    if (tracks.isEmpty) return;
    await _withRegisteredQueue(tracks, (registered) {
      final index = initialIndex.clamp(0, registered.length - 1).toInt();
      return Player.inst.playOrPause(index, registered, QueueSource.others(sourceTitle), updateQueue: false, canAskBeforeReplacing: false);
    });
  }

  Future<void> playNext(LxTrack track) async {
    final player = Player.inst;
    if (player.currentQueue.value.isEmpty || currentPreviewTrack == null) {
      await playTrack(track);
      return;
    }
    await _withRegisteredQueue([track], (registered) async {
      if (await player.addToQueue(registered, insertNext: true, showSnackBar: false)) {
        snackyy(icon: Broken.clock, message: '已添加到下一首试听：${track.name}');
      }
    });
  }

  static String _cacheKey(LxTrack track, String quality) => sha256.convert(utf8.encode('${track.source.code}_${track.id}_$quality')).toString();

  static bool _isCompleteCacheFileSync(File file) => file.existsSync() && file.lengthSync() > 0 && !File('${file.path}.part').existsSync();

  static Future<bool> _isCompleteCacheFile(File file) async => await file.exists() && await file.length() > 0 && !await File('${file.path}.part').exists();

  File? _findCachedAudioFileSync(LxTrack track, String quality) {
    if (AppDirs.APP_CACHE.isEmpty) return null;
    final hash = _cacheKey(track, quality);
    for (final ext in _audioExts) {
      final file = FileParts.join(_audioCacheDir, '$hash.$ext');
      if (_isCompleteCacheFileSync(file)) return file;
    }
    return null;
  }

  Future<File?> _findCachedAudioFile(LxTrack track, String quality) async {
    if (AppDirs.APP_CACHE.isEmpty) return null;
    final hash = _cacheKey(track, quality);
    for (final ext in _audioExts) {
      final file = FileParts.join(_audioCacheDir, '$hash.$ext');
      if (await _isCompleteCacheFile(file)) return file;
    }
    return null;
  }

  File? existingLocalAudioFileSync(String path) {
    final track = trackForPath(path);
    if (track == null) return null;
    final localPath = _downloads.cachedExistingAudioPath(track);
    if (localPath != null) {
      final file = File(localPath);
      if (file.existsSync() && file.lengthSync() > 0) return file;
    }
    final cachedPath = _completedCachePaths[path];
    if (cachedPath != null) {
      final file = File(cachedPath);
      if (_isCompleteCacheFileSync(file)) return file;
    }
    return _findCachedAudioFileSync(track, _downloads.settingsNotifier.value.previewQuality);
  }

  static String _extensionFor(Uri uri, String quality) {
    final segment = uri.path.split('/').last;
    final dot = segment.lastIndexOf('.');
    final ext = dot >= 0 ? segment.substring(dot + 1).toLowerCase() : '';
    return _audioExts.contains(ext) ? ext : (_isLossless(quality) ? 'flac' : 'mp3');
  }

  Future<UriSource> buildAudioSource(
    String path, {
    required UriSource Function({
      required Uri uri,
      Map<String, String>? headers,
      required File cacheFile,
      required void Function(File cachedFile) onFetched,
    })
    buildCacheableSource,
    required void Function(File audioFile) onAudioFileReady,
  }) async {
    final track = trackForPath(path);
    if (track == null) throw StateError('试听曲目信息已失效，请重新点播');
    await _downloads.ensureLoaded();
    final localPath = _downloads.findExistingAudioPath(track);
    if (localPath != null) {
      _setActiveCacheFile(path, null);
      onAudioFileReady(File(localPath));
      return AudioVideoSource.file(localPath);
    }

    final settings = _downloads.settingsNotifier.value;
    final cached = await _findCachedAudioFile(track, settings.previewQuality);
    if (cached != null) {
      _updateTrackQuality(path, settings.previewQuality);
      return _useCachedAudio(path, cached, onAudioFileReady);
    }

    await _bridge.ensureInitialized();
    final resolved = await LxDownloadResolver.resolve(track: track, preferredQuality: settings.previewQuality, autoSwitchSource: settings.autoSwitchSource);
    final quality = resolved.quality;
    _updateTrackQuality(path, quality);
    if (quality != settings.previewQuality) {
      final cached = await _findCachedAudioFile(track, quality);
      if (cached != null) return _useCachedAudio(path, cached, onAudioFileReady);
    }

    final uri = Uri.parse(resolved.url);
    const headers = {'User-Agent': _streamUa};
    if (AppDirs.APP_CACHE.isEmpty) {
      _setActiveCacheFile(path, null);
      return AudioVideoSource.uri(uri, headers: headers);
    }

    final cacheFile = FileParts.join(_audioCacheDir, '${_cacheKey(track, quality)}.${_extensionFor(uri, quality)}');
    await cacheFile.parent.create(recursive: true);
    _setActiveCacheFile(path, cacheFile.path);
    return buildCacheableSource(
      uri: uri,
      headers: headers,
      cacheFile: cacheFile,
      onFetched: (file) => unawaited(_onPreviewCached(path, file, onAudioFileReady)),
    );
  }

  void _updateTrackQuality(String path, String quality) {
    if (_trackExts[path] case final ext?) {
      _trackExts[path] = ext.copyWith(
        format: _formatLabel(quality),
        bitrate: _bitrateForQuality(quality),
        isLossless: _isLossless(quality),
        generatePathHash: false,
      );
    }
  }

  void _setActiveCacheFile(String previewPath, String? filePath) {
    if (_currentPreviewTrack?.path == previewPath) _activeCacheFilePath = filePath;
  }

  Future<UriSource> _useCachedAudio(String path, File file, void Function(File) onAudioFileReady) async {
    _setActiveCacheFile(path, file.path);
    _completedCachePaths[path] = file.path;
    await _touchCachedAudio(file);
    onAudioFileReady(file);
    return AudioVideoSource.file(file.path);
  }

  Future<void> _onPreviewCached(String path, File file, void Function(File) onAudioFileReady) async {
    if (!await _isCompleteCacheFile(file)) return;
    if (_tracks.containsKey(path)) _completedCachePaths[path] = file.path;
    await _touchCachedAudio(file);
    onAudioFileReady(file);
    await _trimPreviewAudioCache();
  }

  static Future<void> _touchCachedAudio(File file) async {
    try {
      await file.setLastModified(DateTime.now());
    } on FileSystemException catch (error) {
      logger.error('更新试听缓存时间失败', e: error);
    }
  }

  static Stream<File> _cacheFiles(String path) async* {
    final dir = Directory(path);
    if (!await dir.exists()) return;
    await for (final entry in dir.list(followLinks: false)) {
      if (entry is File) yield entry;
    }
  }

  bool _isActiveCacheFile(String path) {
    final active = _activeCacheFilePath;
    return active != null && (path == active || path == '$active.part' || path == '$active.metadata');
  }

  Future<void> _trimPreviewAudioCache() async {
    if (AppDirs.APP_CACHE.isEmpty) return;
    final files = <({File file, FileStat stat})>[];
    var total = 0;
    await for (final file in _cacheFiles(_audioCacheDir)) {
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file) continue;
      total += stat.size;
      files.add((file: file, stat: stat));
    }
    if (total <= _maxAudioCacheBytes) return;

    files.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
    for (final entry in files) {
      if (total <= _maxAudioCacheBytes) break;
      if (_isActiveCacheFile(entry.file.path)) continue;
      try {
        await entry.file.delete();
        total -= entry.stat.size;
      } on FileSystemException catch (error) {
        logger.error('清理试听音频缓存失败', e: error);
      }
    }
  }

  Future<int> computePreviewCacheBytes() async {
    if (AppDirs.APP_CACHE.isEmpty) return 0;
    var total = 0;
    for (final dir in [_audioCacheDir, _artworkCacheDir]) {
      await for (final file in _cacheFiles(dir)) {
        try {
          total += await file.length();
        } on FileSystemException catch (error) {
          logger.error('读取试听缓存大小失败', e: error);
        }
      }
    }
    return total;
  }

  Future<void> clearPreviewCache() async {
    if (AppDirs.APP_CACHE.isNotEmpty) {
      for (final dir in [_audioCacheDir, _artworkCacheDir]) {
        await for (final file in _cacheFiles(dir)) {
          final active = _currentPreviewTrack;
          if (active != null && (_isActiveCacheFile(file.path) || file.path == active.pathToImage)) continue;
          try {
            await file.delete();
          } on FileSystemException catch (error) {
            logger.error('清除试听缓存失败', e: error);
          }
        }
      }
    }
    final activePath = _currentPreviewTrack?.path;
    _completedCachePaths.removeWhere((path, _) => path != activePath);
    _artBytesCache.removeWhere((path, _) => path != activePath);
    _lyricsCache.removeWhere((path, _) => path != activePath);
  }

  Future<Uint8List?> fetchArtworkBytes(String path) async {
    final cached = _artBytesCache[path];
    if (cached != null) return cached;
    final track = trackForPath(path);
    if (track == null) return null;

    var url = track.picUrl?.trim() ?? '';
    if (url.isEmpty) url = (await _bridge.fetchPic(track: track))?.trim() ?? '';
    if (url.isEmpty) return null;
    final bytes = await _bridge.fetchBinary(url);
    _artBytesCache[path] = bytes;
    if (_artBytesCache.length > _maxCovers) _artBytesCache.remove(_artBytesCache.keys.first);
    return bytes;
  }

  Future<String?> fetchLyrics(String path) async {
    final cached = _lyricsCache[path];
    if (cached != null) return cached;
    final track = trackForPath(path);
    if (track == null) return null;

    await _downloads.ensureLoaded();
    final options = _downloads.settingsNotifier.value;
    final result = await _bridge.fetchLyric(track: track);
    final original = result.lyric.trim();
    final merged = LxDownloadManager.mergeLyrics(original, [
      if (options.includeTranslationLyric) result.tlyric,
      if (options.includeRomanizationLyric) result.rlyric,
    ]);
    if (_tracks.containsKey(path)) _lyricsCache[path] = merged;
    return merged;
  }

  void updateDuration(String path, Duration duration) {
    final ext = _trackExts[path];
    final ms = duration.inMilliseconds;
    if (ext != null && ms > 0 && ext.durationMS != ms) {
      _trackExts[path] = ext.copyWith(durationMS: ms, generatePathHash: false);
    }
  }

  Future<void> triggerDownload(LxTrack track, {bool forceDialog = false}) async {
    await LxDownloadActions.downloadTracks([track], forceDialog: forceDialog, onOpenDownloads: LxSettingsPage.openDownloads);
  }

  Future<void> showPreviewTrackMenu(String path) async {
    final track = trackForPath(path);
    if (track == null) return;

    ListTile action(IconData icon, String title, Future<void> Function() run) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () async {
        await NamidaNavigator.inst.closeDialog();
        await run();
      },
    );

    await NamidaNavigator.inst.navigateDialog<void>(
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        title: track.name,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            action(Broken.document_download, '下载歌曲', () => triggerDownload(track)),
            action(Broken.slider_horizontal, '选择音质下载', () => triggerDownload(track, forceDialog: true)),
            action(Broken.document_text, '查看完整歌词与详情', () => _showLyrics(track)),
            action(Broken.close_circle, '退出在线试听', Player.inst.clearQueue),
          ],
        ),
      ),
    );
  }

  void openPreviewLyrics(String path) {
    final track = trackForPath(path);
    if (track != null) _showLyrics(track);
  }

  Future<void> _showLyrics(LxTrack track) => LxLyricsSheet.show(
    track: track,
    onDownload: () => triggerDownload(track),
    onChooseQualityDownload: () => triggerDownload(track, forceDialog: true),
  );

  static String _formatLabel(String? quality) => quality == null ? '' : (_isLossless(quality) ? 'FLAC' : 'MP3');
  static bool _isLossless(String? quality) => quality == 'flac' || quality == 'flac24bit';
  static int _bitrateForQuality(String? quality) => switch (quality) {
    '320k' => 320,
    '128k' => 128,
    _ => 0,
  };
}
