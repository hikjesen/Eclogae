import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:just_audio/just_audio.dart';

import 'package:namida/class/track.dart';
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

  static bool isPreviewPath(String path) => path.startsWith(pathPrefix);
  static String previewPathFor(LxTrack track) => '$pathPrefix${Uri.encodeQueryComponent('${track.source.code}_${track.id}')}';

  final _tracks = <String, LxTrack>{};
  final _trackExts = <String, TrackExtended>{};
  final _lyricsCache = <String, String>{};
  final _artBytesCache = <String, Uint8List>{};
  final _pendingQueues = <List<Track>>{};
  final _downloads = LxDownloadManager.inst;
  final _bridge = LxBridgeService.inst;

  LxTrack? trackForPath(String path) => _tracks[path];
  TrackExtended? trackExtForPath(String path) => _trackExts[path];

  LxTrack? get currentPreviewTrack {
    final item = Player.inst.currentItem.value;
    return item is Selectable && isPreviewPath(item.track.path) ? trackForPath(item.track.path) : null;
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

  Future<UriSource> buildAudioSource(String path) async {
    final track = trackForPath(path);
    if (track == null) throw StateError('试听曲目信息已失效，请重新点播');
    await _downloads.ensureLoaded();
    final localPath = _downloads.findExistingAudioPath(track);
    if (localPath != null) return AudioVideoSource.file(localPath);

    await _bridge.ensureInitialized();
    final settings = _downloads.settingsNotifier.value;
    final resolved = await LxDownloadResolver.resolve(track: track, preferredQuality: settings.previewQuality, autoSwitchSource: settings.autoSwitchSource);
    final quality = resolved.quality;
    if (_trackExts[path] case final ext?) {
      _trackExts[path] = ext.copyWith(
        format: _formatLabel(quality),
        bitrate: _bitrateForQuality(quality),
        isLossless: _isLossless(quality),
        generatePathHash: false,
      );
    }
    return AudioVideoSource.uri(Uri.parse(resolved.url), headers: const {'User-Agent': _streamUa});
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
    await LxDownloadActions.downloadTracks([track], forceDialog: forceDialog);
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
