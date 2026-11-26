import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/files_download_manager.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/tagger_controller.dart';
import 'package:namida/core/constants.dart';

import 'lx_audio_sniffer.dart';
import 'lx_bridge_service.dart';
import 'lx_download_resolver.dart';
import 'lx_models.dart';
import 'lx_user_api_store.dart';

class LxDownloadManager {
  LxDownloadManager._();

  static final inst = LxDownloadManager._();
  static const _downloadUa = 'Mozilla/5.0 (Linux; Android 10; Pixel 3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.79 Mobile Safari/537.36';
  static final _invalidFilenameChars = RegExp(r'[\\/:*?"<>|\x00-\x1f]');
  static final _filenameEdges = RegExp(r'^[. ]+|[. ]+$');
  static final _lrcTimestamp = RegExp(r'\[(\d{1,4}):([0-5]\d)(?:[.:](\d{1,3}))?\]');

  final tasksNotifier = ValueNotifier<List<LxDownloadTask>>(const []);
  final settingsNotifier = ValueNotifier<LxDownloadSettings>(const LxDownloadSettings());
  final activeCountNotifier = ValueNotifier<int>(0);
  final existingFilesVersion = ValueNotifier<int>(0);

  final _store = LxUserApiStore();
  final _bridge = LxBridgeService.inst;
  final _useLoadedQuality = <String>{};
  final _taggingSources = <String, LxTrack>{};
  final _running = <String, _RunningTask>{};
  final _existingFiles = <String, String>{};
  final _uncommittedAudioPaths = <String>{};
  late final Future<Directory> _tempDir = getApplicationSupportDirectory().then((dir) => Directory(p.join(dir.path, 'lx_music', 'tmp')));

  Future<void>? _loading;
  bool _settingsLoaded = false;
  Future<void> _settingsWrites = Future.value();
  String? _existingFilesDirectory;
  Map<String, String>? _existingFilesScan;

  Future<void> ensureLoaded() => _loading ??= _loadSettings();

  Future<void> _loadSettings() async {
    try {
      final loaded = await _store.loadSettings();
      _settingsLoaded = true;
      settingsNotifier.value = loaded;
      await refreshExistingFiles();
      _startWorkers();
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  Future<void> updateSettings(LxDownloadSettings next) async {
    _validateQuality(next.preferredQuality, 'preferredQuality');
    _validateQuality(next.previewQuality, 'previewQuality');
    final selected = next.lastSelectedQuality;
    if (selected != null) _validateQuality(selected, 'lastSelectedQuality');
    if (!LxDownloadSettings.concurrentOptions.contains(next.maxConcurrent)) {
      throw ArgumentError.value(next.maxConcurrent, 'maxConcurrent', '不支持的并行下载数量');
    }
    await _writeSettings((_) => next);
  }

  Future<void> recordSelectedQuality(String quality) async {
    _validateQuality(quality, 'lastSelectedQuality');
    await _writeSettings((current) => current.copyWith(lastSelectedQuality: quality));
  }

  static void _validateQuality(String quality, String field) {
    if (!LxDownloadSettings.qualityOptions.contains(quality)) {
      throw ArgumentError.value(quality, field, '不支持的下载音质');
    }
  }

  Future<void> _writeSettings(LxDownloadSettings Function(LxDownloadSettings) edit) async {
    final previous = _settingsWrites;
    final done = Completer<void>();
    _settingsWrites = done.future;
    try {
      await previous;
      await ensureLoaded();
      final current = settingsNotifier.value;
      final next = edit(current);
      await _store.saveSettings(next);
      final directoryChanged = next.downloadDir != current.downloadDir;
      if (directoryChanged) {
        _existingFilesDirectory = null;
        _existingFilesScan = null;
        _existingFiles.clear();
      }
      settingsNotifier.value = next;
      if (directoryChanged) await refreshExistingFiles();
      _startWorkers();
    } finally {
      done.complete();
    }
  }

  String resolveEffectiveDownloadDir() => _effectiveDownloadDir(settingsNotifier.value);

  String resolveTargetDir({String? subfolderName}) => _targetDir(settingsNotifier.value, subfolderName: subfolderName);

  String _targetDir(LxDownloadSettings options, {String? subfolderName}) {
    final root = _effectiveDownloadDir(options);
    if (!options.archiveSonglistToSubfolder) return root;
    final sub = sanitizeSubfolderName(subfolderName);
    return sub == null ? root : p.join(root, sub);
  }

  String _effectiveDownloadDir(LxDownloadSettings options) {
    final configured = options.downloadDir?.trim();
    if (configured != null && configured.isNotEmpty) return configured;
    for (final dir in settings.directoriesToScan.value.whereType<DirectoryIndexLocal>()) {
      if (dir.existsSync()) return dir.sourceRaw;
    }
    return AppDirs.YOUTUBE_DOWNLOADS_DEFAULT;
  }

  Future<void> refreshExistingFiles() async {
    final directory = p.normalize(p.absolute(resolveEffectiveDownloadDir()));
    if (directory != _existingFilesDirectory) {
      _existingFilesDirectory = directory;
      _existingFiles.clear();
    }
    final files = _existingFilesScan = <String, String>{};
    try {
      await for (final entry in Directory(directory).list(recursive: true, followLinks: false)) {
        if (entry is! File || _uncommittedAudioPaths.contains(entry.path)) continue;
        final extension = p.extension(entry.path).toLowerCase();
        if (LxAudioSniffer.audioExtensions.any((audioExtension) => extension == '.$audioExtension')) {
          files.putIfAbsent(p.basenameWithoutExtension(entry.path).toLowerCase(), () => entry.path);
        }
      }
    } on FileSystemException catch (error) {
      if (error is! PathNotFoundException) _log('warning', '读取下载目录失败：${_reason(error)}');
    }
    if (!identical(_existingFilesScan, files)) return;
    _existingFilesScan = null;
    _existingFiles
      ..clear()
      ..addAll(files);
    existingFilesVersion.value++;
  }

  String? cachedExistingAudioPath(LxTrack track) => _existingFiles[baseFilenameFor(track).toLowerCase()];

  String? findExistingAudioPath(LxTrack track) {
    final base = baseFilenameFor(track);
    final cached = _existingFiles[base.toLowerCase()];
    if (cached != null && !_uncommittedAudioPaths.contains(cached) && File(cached).existsSync()) return cached;
    final directory = p.normalize(p.absolute(resolveEffectiveDownloadDir()));
    final stem = p.join(directory, base);
    for (final extension in LxAudioSniffer.audioExtensions) {
      final path = '$stem.$extension';
      if (!_uncommittedAudioPaths.contains(path) && File(path).existsSync()) return path;
    }
    return null;
  }

  LxDownloadTask? latestTaskForTrack(LxTrack track) {
    LxDownloadTask? latest;
    for (final task in tasksNotifier.value.reversed) {
      if (task.track.source != track.source || task.track.id != track.id) continue;
      if (task.isActive) return task;
      latest ??= task;
    }
    return latest;
  }

  ({List<LxTrack> fresh, List<LxTrack> inQueue, List<LxTrack> onDisk}) classifyDuplicates(Iterable<LxTrack> tracks) {
    final queuedKeys = {for (final task in tasksNotifier.value) if (task.isActive) task.track.uniqueKey};
    final fresh = <LxTrack>[];
    final inQueue = <LxTrack>[];
    final onDisk = <LxTrack>[];
    for (final track in tracks) {
      if (queuedKeys.contains(track.uniqueKey)) {
        inQueue.add(track);
      } else if (findExistingAudioPath(track) != null) {
        onDisk.add(track);
      } else {
        fresh.add(track);
      }
    }
    return (fresh: fresh, inQueue: inQueue, onDisk: onDisk);
  }

  LxDownloadTask enqueue(LxTrack track, {String? quality, String? subfolderName}) => enqueueBatch([track], quality: quality, subfolderName: subfolderName).single;

  List<LxDownloadTask> enqueueBatch(Iterable<LxTrack> tracks, {String? quality, String? subfolderName}) {
    final requested = quality ?? settingsNotifier.value.effectiveQuickQuality;
    final normalizedSubfolder = sanitizeSubfolderName(subfolderName);
    final now = DateTime.now();
    final added = [
      for (final track in tracks) LxDownloadTask(id: const Uuid().v4(), track: track, requestedQuality: requested, createdAt: now, subfolderName: normalizedSubfolder),
    ];
    if (added.isEmpty) return added;
    if (quality == null && !_settingsLoaded) _useLoadedQuality.addAll(added.map((task) => task.id));
    _publish([...tasksNotifier.value, ...added]);
    _startWorkers();
    return added;
  }

  Future<void> cancel(String taskId) async {
    final task = _find(taskId);
    if (task == null || !task.canCancel) return;
    if (task.stage == LxDownloadStage.queued) {
      _replace(task.copyWith(stage: LxDownloadStage.canceled));
      return;
    }
    final running = _running[taskId]!;
    if (running.cancelRequested) return;
    running.cancelRequested = true;
    final file = running.downloadingFile;
    if (file != null) await (running.stopPending = _stopDownload(file));
  }

  void retry(String taskId) {
    final task = _find(taskId);
    if (task == null || !task.canRetry) return;
    final path = task.savedPath;
    final reuseAudio = path != null && File(path).existsSync();
    if (!reuseAudio) _taggingSources.remove(task.id);
    _replace(_queuedCopy(task, reuseAudio: reuseAudio));
    _startWorkers();
  }

  void removeTask(String taskId) => _removeFinished((task) => task.id == taskId);

  void clearFinished() => _removeFinished((_) => true);

  void _removeFinished(bool Function(LxDownloadTask) matches) {
    final kept = <LxDownloadTask>[];
    for (final task in tasksNotifier.value) {
      if (task.isActive || !matches(task)) {
        kept.add(task);
      } else {
        _useLoadedQuality.remove(task.id);
        _taggingSources.remove(task.id);
      }
    }
    if (kept.length != tasksNotifier.value.length) _publish(kept);
  }

  LxDownloadTask _queuedCopy(LxDownloadTask task, {required bool reuseAudio}) => LxDownloadTask(
    id: task.id,
    track: task.track,
    requestedQuality: task.requestedQuality,
    createdAt: task.createdAt,
    subfolderName: task.subfolderName,
    resolvedQuality: reuseAudio ? task.resolvedQuality : null,
    resolvedSource: reuseAudio ? task.resolvedSource : null,
    resolveDetail: reuseAudio ? task.resolveDetail : null,
    receivedBytes: reuseAudio ? task.receivedBytes : 0,
    totalBytes: reuseAudio ? task.totalBytes : 0,
    savedPath: reuseAudio ? task.savedPath : null,
    lrcPath: reuseAudio ? task.lrcPath : null,
  );

  LxDownloadTask? _find(String id) => tasksNotifier.value.where((task) => task.id == id).firstOrNull;

  void _publish(List<LxDownloadTask> tasks) {
    tasksNotifier.value = List.unmodifiable(tasks);
    activeCountNotifier.value = tasksNotifier.value.where((task) => task.isActive).length;
  }

  void _replace(LxDownloadTask next) => _publish([for (final task in tasksNotifier.value) task.id == next.id ? next : task]);

  void _startWorkers() {
    while (_running.length < settingsNotifier.value.maxConcurrent) {
      final task = tasksNotifier.value.where((task) => task.stage == LxDownloadStage.queued && !_running.containsKey(task.id)).firstOrNull;
      if (task == null) break;
      final wasIdle = _running.isEmpty;
      _running[task.id] = _RunningTask();
      if (wasIdle) unawaited(_keepRunning(true));
      unawaited(_process(task));
    }
  }

  Future<void> _process(LxDownloadTask task) async {
    final id = task.id;
    final running = _running[id]!;
    final resumed = task.savedPath != null;
    try {
      _replace(task.copyWith(stage: resumed ? LxDownloadStage.tagging : LxDownloadStage.resolving));
      await ensureLoaded();
      _checkCanceled(id);
      final options = settingsNotifier.value;
      if (resumed && !await File(task.savedPath!).exists()) {
        _taggingSources.remove(id);
        _replace(_queuedCopy(task, reuseAudio: false).copyWith(stage: LxDownloadStage.resolving));
      }
      if (_useLoadedQuality.remove(id)) {
        _replace(_find(id)!.copyWith(requestedQuality: options.effectiveQuickQuality));
      }
      if (_find(id)!.savedPath == null) await _resolveAndSave(id, options);
      final completed = await _tagAndIndex(_find(id)!, _taggingSources[id]!, options);
      _taggingSources.remove(id);
      _replace(completed);
    } catch (error) {
      final current = _find(id)!;
      if (running.cancelRequested || error is DownloadCanceledException) {
        _replace(current.copyWith(stage: LxDownloadStage.canceled, bytesPerSecond: 0));
      } else {
        final message = '[${current.stage.label}] ${_reason(error)}';
        _log('error', message);
        _replace(current.copyWith(stage: LxDownloadStage.failed, bytesPerSecond: 0, failedStage: current.stage, errorMessage: message));
      }
    } finally {
      _running.remove(id);
      if (_running.isEmpty) unawaited(_keepRunning(false));
      _startWorkers();
    }
  }

  Future<void> _resolveAndSave(String id, LxDownloadSettings options) async {
    _checkCanceled(id);
    final task = _find(id)!;
    final resolved = await LxDownloadResolver.resolve(
      track: task.track,
      preferredQuality: task.requestedQuality,
      autoSwitchSource: options.autoSwitchSource,
    );
    _checkCanceled(id);
    _log('info', '[${LxDownloadStage.resolving.label}] ${resolved.detail}');
    _replace(task.copyWith(
      stage: LxDownloadStage.downloading,
      resolvedQuality: resolved.quality,
      resolvedSource: resolved.track.source,
      resolveDetail: resolved.detail,
    ));

    _checkCanceled(id);
    final probedTotal = await _bridge.probeContentLength(resolved.url, headers: const {'User-Agent': _downloadUa});
    _checkCanceled(id);
    if (probedTotal != null) _replace(_find(id)!.copyWith(totalBytes: probedTotal));

    final part = File(p.join((await _tempDir).path, '$id.${const Uuid().v4()}.part'));
    try {
      await _download(id, resolved.url, part, totalBytes: probedTotal ?? 0);
      _checkCanceled(id);
      _replace(_find(id)!.copyWith(stage: LxDownloadStage.verifying, bytesPerSecond: 0));
      _checkCanceled(id);
      final extension = await LxAudioSniffer.verifyAndDetectExtension(part);
      final size = await part.length();
      final dir = await Directory(p.normalize(p.absolute(_targetDir(options, subfolderName: task.subfolderName)))).create(recursive: true);
      _checkCanceled(id);
      final target = _allocateFile(dir, task.track, extension, exportLrc: options.exportLrc);
      await _commitAudio(id, part, target, size, resolved.track);
    } finally {
      await _deleteTemp(part);
      if (_running[id]!.cancelRequested) FilesDownloadManager.deleteDownloadFiles(part);
    }
  }

  Future<void> _download(String id, String url, File part, {required int totalBytes}) async {
    await part.parent.create(recursive: true);
    final downloader = FilesDownloadManager.inst;
    if (!downloader.isInitialized) await downloader.initialize();
    _checkCanceled(id);

    final running = _running[id]!;
    running.downloadingFile = part;
    running.speedSampleStart = DateTime.now();
    try {
      final result = await downloader.download(
        url: Uri.parse(url),
        headers: const {'User-Agent': _downloadUa},
        file: part,
        totalBytes: totalBytes,
        threads: 1,
        downloadingStream: (bytes) => _updateProgress(id, bytes),
      );
      if (result != null) throw result;
    } finally {
      running.downloadingFile = null;
      final stop = running.stopPending;
      running.stopPending = null;
      if (stop != null) await stop;
    }
  }

  void _updateProgress(String id, int bytesDelta) {
    final task = _find(id);
    if (task == null || task.stage != LxDownloadStage.downloading) return;
    final running = _running[id]!;
    if (running.cancelRequested) return;

    final received = task.receivedBytes + bytesDelta;
    final nextBytes = received < 0 ? 0 : received;
    if (bytesDelta > 0) running.speedSampleBytes += bytesDelta;
    var bytesPerSecond = task.bytesPerSecond;
    final now = DateTime.now();
    final elapsedMs = now.difference(running.speedSampleStart).inMilliseconds;
    if (elapsedMs >= 500) {
      bytesPerSecond = running.speedSampleBytes * 1000 ~/ elapsedMs;
      running.speedSampleBytes = 0;
      running.speedSampleStart = now;
    }
    _replace(task.copyWith(
      receivedBytes: nextBytes,
      totalBytes: task.totalBytes > 0 && nextBytes > task.totalBytes ? nextBytes : task.totalBytes,
      bytesPerSecond: bytesPerSecond,
    ));
  }

  Future<void> _stopDownload(File file) async {
    try {
      await FilesDownloadManager.inst.stopDownload(file: file);
    } catch (error) {
      _log('warning', '[${LxDownloadStage.downloading.label}] 停止下载失败：${_reason(error)}');
    }
  }

  void _checkCanceled(String id) {
    if (_running[id]!.cancelRequested) throw const DownloadCanceledException();
  }

  static String baseFilenameFor(LxTrack track) {
    final label = track.singer.isEmpty ? track.name : '${track.singer} - ${track.name}';
    final name = _sanitizePathSegment(label);
    return name.isEmpty ? '在线曲库' : name;
  }

  static String? sanitizeSubfolderName(String? raw) {
    if (raw == null) return null;
    final name = _sanitizePathSegment(raw);
    return name.isEmpty ? null : name;
  }

  static String _sanitizePathSegment(String raw) {
    final clean = raw.replaceAll(_invalidFilenameChars, '_').replaceAll(_filenameEdges, '');
    var nameBytes = 0;
    final prefix = clean.runes.take(120).takeWhile((rune) {
      nameBytes += utf8.encode(String.fromCharCode(rune)).length;
      return nameBytes <= 235;
    });
    return String.fromCharCodes(prefix).replaceAll(_filenameEdges, '');
  }

  static File _allocateFile(Directory dir, LxTrack track, String extension, {required bool exportLrc}) {
    final base = baseFilenameFor(track);
    for (var n = 1; ; n++) {
      final stem = p.join(dir.path, n == 1 ? base : '$base ($n)');
      final path = '$stem.$extension';
      if (FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.notFound) continue;
      if (exportLrc &&
          (FileSystemEntity.typeSync('$stem.lrc', followLinks: false) != FileSystemEntityType.notFound ||
              LxAudioSniffer.audioExtensions.any((ext) => ext != extension && FileSystemEntity.typeSync('$stem.$ext', followLinks: false) != FileSystemEntityType.notFound))) {
        continue;
      }
      final file = File(path);
      try {
        file.createSync(exclusive: true);
        return file;
      } on PathExistsException {
        continue;
      }
    }
  }

  Future<void> _commitAudio(String id, File part, File target, int size, LxTrack source) async {
    _uncommittedAudioPaths.add(target.path);
    var committed = false;
    try {
      await _move(part, target);
      _checkCanceled(id);
      _taggingSources[id] = source;
      committed = true;
      _uncommittedAudioPaths.remove(target.path);
      final root = _existingFilesDirectory;
      final cacheTarget = root != null && (p.equals(p.dirname(target.path), root) || p.isWithin(root, target.path));
      if (cacheTarget) {
        final stem = p.basenameWithoutExtension(target.path).toLowerCase();
        _existingFiles[stem] = target.path;
        _existingFilesScan?[stem] = target.path;
      }
      _replace(_find(id)!.copyWith(stage: LxDownloadStage.tagging, receivedBytes: size, totalBytes: size, savedPath: target.path));
      if (cacheTarget) existingFilesVersion.value++;
    } finally {
      if (!committed) {
        await _deleteTemp(target);
        _uncommittedAudioPaths.remove(target.path);
      }
    }
  }

  static Future<void> _move(File part, File target) async {
    try {
      await part.rename(target.path);
    } on FileSystemException {
      await part.copy(target.path);
      await part.delete();
    }
  }

  Future<LxDownloadTask> _tagAndIndex(LxDownloadTask task, LxTrack source, LxDownloadSettings options) async {
    final path = task.savedPath!;
    final cover = options.embedCover ? await _saveCover(task, source) : null;
    try {
      final lyrics = options.exportLrc ? await _fetchLyrics(source, options) : null;
      if (lyrics != null) {
        final lrc = await _saveLyrics(path, lyrics, task.id);
        if (lrc != null) _replace(task = task.copyWith(lrcPath: lrc));
      }
      final error = await NamidaTaggerController.inst.writeTagsRaw(
        path: path,
        newTags: FTags.edit(
          path: path,
          title: task.track.name,
          artist: task.track.singer.isEmpty ? null : task.track.singer,
          album: task.track.albumName.isEmpty ? null : task.track.albumName,
          artwork: cover == null ? FArtwork.dummy() : FArtwork(file: cover),
          lyrics: lyrics,
        ),
      );
      if (error != null) _tagWarning('写入标签失败：$error');
      await NamidaChannel.inst.scanMediaFilesTry([path]);
      final indexed = await Indexer.inst.convertPathToTracksAndAddToListsSingle(path);
      if (indexed == null) _tagWarning('文件已保存，Namida 未返回入库曲目');
      return task.copyWith(stage: LxDownloadStage.completed, indexedTrack: indexed);
    } finally {
      if (cover != null) await _deleteTemp(cover);
    }
  }

  Future<File?> _saveCover(LxDownloadTask task, LxTrack source) async {
    File? cover;
    try {
      final url = [task.track.picUrl, source.picUrl].nonNulls.firstWhere((url) => url.trim().isNotEmpty, orElse: () => '');
      final resolvedUrl = url.isNotEmpty ? url : await _bridge.fetchPic(track: source);
      if (resolvedUrl == null || resolvedUrl.trim().isEmpty) return null;
      final bytes = await _bridge.fetchBinary(resolvedUrl);
      if (!LxAudioSniffer.isValidImageBytes(bytes)) throw const FormatException('无法识别封面文件头');
      final extension = switch (bytes.first) { 0xff => 'jpg', 0x89 => 'png', _ => 'webp' };
      cover = File(p.join((await _tempDir).path, '${task.id}.cover.$extension'));
      await cover.parent.create(recursive: true);
      await cover.writeAsBytes(bytes);
      return cover;
    } catch (error) {
      _tagWarning('封面获取失败：${_reason(error)}');
      if (cover != null) await _deleteTemp(cover);
      return null;
    }
  }

  Future<String?> _fetchLyrics(LxTrack source, LxDownloadSettings options) async {
    try {
      final result = await _bridge.fetchLyric(track: source);
      final original = result.lyric.trim();
      if (original.isEmpty) return null;
      return mergeLyrics(original, [
        if (options.includeTranslationLyric) result.tlyric,
        if (options.includeRomanizationLyric) result.rlyric,
      ]);
    } catch (error) {
      _tagWarning('歌词获取失败：${_reason(error)}');
      return null;
    }
  }

  Future<String?> _saveLyrics(String audioPath, String lyrics, String id) async {
    final path = '${p.withoutExtension(audioPath)}.lrc';
    final staging = File(p.join(p.dirname(path), '.lx-$id.lrc.tmp'));
    try {
      await staging.writeAsString(lyrics, flush: true);
      await staging.rename(path);
      return path;
    } on FileSystemException catch (error) {
      _tagWarning('歌词导出失败：${_reason(error)}');
      return null;
    } finally {
      await _deleteTemp(staging);
    }
  }

  static String mergeLyrics(String original, List<String?> companions) {
    final byTime = <int, Set<String>>{};
    for (final companion in companions.nonNulls) {
      for (final line in companion.split('\n')) {
        final (timestamps, text) = _timedLine(line.trim());
        if (text.isEmpty) continue;
        for (final stamp in timestamps) {
          (byTime[_milliseconds(stamp)] ??= <String>{}).add(text);
        }
      }
    }
    if (byTime.isEmpty) return original;

    final merged = <String>[];
    var matched = false;
    for (final rawLine in original.split('\n')) {
      final line = rawLine.trimRight();
      final (timestamps, text) = _timedLine(line.trimLeft());
      if (!timestamps.any((stamp) => byTime.containsKey(_milliseconds(stamp)))) {
        merged.add(line);
        continue;
      }
      matched = true;
      for (final stamp in timestamps) {
        final prefix = stamp[0]!;
        merged.add('$prefix$text');
        for (final translation in byTime[_milliseconds(stamp)] ?? const <String>{}) {
          if (translation != text) merged.add('$prefix$translation');
        }
      }
    }
    return matched ? merged.join('\n') : original;
  }

  static (List<RegExpMatch>, String) _timedLine(String line) {
    final timestamps = <RegExpMatch>[];
    var end = 0;
    for (final stamp in _lrcTimestamp.allMatches(line)) {
      if (stamp.start != end) break;
      timestamps.add(stamp);
      end = stamp.end;
    }
    return (timestamps, line.substring(end).trim());
  }

  static int _milliseconds(RegExpMatch stamp) =>
      (int.parse(stamp[1]!) * 60 + int.parse(stamp[2]!)) * 1000 + int.parse(stamp[3]?.padRight(3, '0') ?? '0');

  Future<void> _deleteTemp(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error) {
      _log('warning', '文件清理失败：${_reason(error)}');
    }
  }

  Future<void> _keepRunning(bool keepRunning) async {
    try {
      await NamidaChannel.inst.setKeepRunningInBackground(keepRunning);
    } catch (error) {
      _log('warning', '后台运行状态设置失败：${_reason(error)}');
    }
  }

  static String _reason(Object error) => switch (error) {
    FormatException(:final message) => message,
    StateError(:final message) => message,
    _ => error.toString().replaceFirst('Exception: ', ''),
  };

  void _tagWarning(String message) => _log('warning', '[${LxDownloadStage.tagging.label}] $message');
  void _log(String level, String message) => _bridge.logDiagnostic('download', level, message);
}

class _RunningTask {
  bool cancelRequested = false;
  File? downloadingFile;
  Future<void>? stopPending;
  int speedSampleBytes = 0;
  late DateTime speedSampleStart;
}
