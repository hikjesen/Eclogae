import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'lx_http_proxy.dart';
import 'lx_models.dart';
import 'lx_user_api_store.dart';

enum _Engine {
  userApi('user_api', 'sendUserApiAction'),
  musicSdk('music_sdk', 'sendMusicSdkAction');

  const _Engine(this.code, this.sendMethod);

  final String code;
  final String sendMethod;
}

class LxBridgeService {
  LxBridgeService._();

  static final inst = LxBridgeService._();
  static bool get isSupported => Platform.isAndroid;

  static const _bridge = MethodChannel('namida/lx_bridge');
  static const _events = EventChannel('namida/lx_events');
  static const _timeout = Duration(seconds: 20);
  static const _maxScriptBytes = 2 * 1024 * 1024;
  static const _unsupported = '在线曲库桥接仅支持 Android';

  final scriptsNotifier = ValueNotifier<List<LxUserApiMeta>>(const []);
  final userApiStateNotifier = ValueNotifier<LxUserApiState>(const LxUserApiState());
  final musicSdkReadyNotifier = ValueNotifier<bool>(false);
  final logsNotifier = ValueNotifier<List<LxLogEntry>>(const []);
  final updateAlertNotifier = ValueNotifier<LxUpdateAlert?>(null);

  final _store = LxUserApiStore();
  late final _httpProxy = LxHttpProxy();
  final _logs = Queue<LxLogEntry>();
  final _pending = <(_Engine, String), Completer<Map<String, dynamic>>>{};
  final _httpRequests = <(_Engine, String), String>{};

  Future<void>? _initialization;
  Future<void>? _sdkInitialization;
  Future<void> _scriptChanges = Future.value();
  Completer<Map<String, dynamic>>? _userApiInit;
  bool _userEngineStarted = false;
  int _nextId = 0;

  Future<void> ensureInitialized() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (!isSupported) {
      userApiStateNotifier.value = const LxUserApiState(status: LxUserApiStatus.error, errorMessage: _unsupported);
      _log('bridge', 'info', _unsupported);
      return;
    }

    try {
      final saved = await _store.loadAll();
      scriptsNotifier.value = List.unmodifiable(saved.scripts);
      _events.receiveBroadcastStream().listen(_onEvent, onError: (Object error) => _log('bridge', 'error', '[事件通道] ${_describe(error)}'));
      final active = saved.scripts.where((script) => script.id == saved.activeId).firstOrNull;
      if (active != null) await _activate(active);
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> ensureMusicSdkReady() async {
    _requireAndroid();
    await ensureInitialized();
    await (_sdkInitialization ??= _initializeMusicSdk());
  }

  Future<void> _initializeMusicSdk() async {
    try {
      final bundle = await rootBundle.loadString('assets/lx/music-sdk-bundle.js');
      await _invokeAccepted('initMusicSdk', {'bundleScript': bundle}).timeout(_timeout, onTimeout: () => throw TimeoutException('Music SDK 初始化超时'));
      musicSdkReadyNotifier.value = true;
      _log(_Engine.musicSdk.code, 'info', 'Music SDK 已就绪');
    } catch (error) {
      _sdkInitialization = null;
      throw Exception('[初始化 Music SDK] ${_describe(error)}');
    }
  }

  Future<void> importScript(File file) => _changeScripts(() async {
    final meta = await _store.importFromFile(file);
    await _activateImportedScript(meta);
  });

  Future<Uint8List> fetchBinary(String url, {Map<String, String>? headers}) async => _fetchBinary(_httpUri(url), headers: headers);

  Future<int?> probeContentLength(String url, {Map<String, String>? headers}) async {
    try {
      final response = await _httpProxy.execute(
        requestKey: 'http_${_nextId++}',
        url: _httpUri(url).toString(),
        options: {'method': 'HEAD', 'timeout': 5000, 'headers': headers},
      );
      final status = response['statusCode'] as int;
      if (status < 200 || status >= 400) return null;
      final responseHeaders = response['headers'] as Map<String, String>;
      for (final entry in responseHeaders.entries) {
        if (entry.key.toLowerCase() != 'content-length') continue;
        final length = int.tryParse(entry.value.trim());
        return length != null && length > 0 ? length : null;
      }
      return null;
    } catch (_) {
      // A download can proceed when the server does not support probing its size.
      return null;
    }
  }

  Future<void> importScriptFromUrl(String url) async {
    final uri = _httpUri(url);
    await _changeScripts(() async {
      final bytes = await _fetchBinary(uri, maxBytes: _maxScriptBytes);
      final script = _decodeScript(bytes);
      final name = (uri.pathSegments.lastOrNull ?? '').replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
      final fileName = name.isEmpty ? 'source.js' : (name.toLowerCase().endsWith('.js') ? name : '$name.js');
      final meta = await _store.importFromScriptContent(script, fileName: fileName);
      await _activateImportedScript(meta, host: uri.host);
    });
  }

  Future<Uint8List> _fetchBinary(Uri uri, {Map<String, String>? headers, int? maxBytes}) async {
    final response = await _httpProxy.execute(
      requestKey: 'http_${_nextId++}',
      url: uri.toString(),
      options: {'binary': true, 'timeout': _timeout.inMilliseconds, 'headers': headers ?? const {'Accept': '*/*'}},
    );
    final status = response['statusCode'] as int;
    if (status != 200) throw HttpException('HTTP 请求失败（$status）');
    final body = response['body'] as String;
    if (maxBytes != null && body.length > ((maxBytes + 2) ~/ 3) * 4) throw const FormatException('在线音源文件超过 2 MB');
    final bytes = base64Decode(body);
    if (maxBytes != null && bytes.length > maxBytes) throw const FormatException('在线音源文件超过 2 MB');
    return bytes;
  }

  static Uri _httpUri(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      throw const FormatException('请输入有效的 HTTP 或 HTTPS 地址');
    }
    return uri;
  }

  static String _decodeScript(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw const FormatException('在线音源文件必须使用 UTF-8 编码');
    }
  }

  Future<void> _activateImportedScript(LxUserApiMeta meta, {String? host}) async {
    scriptsNotifier.value = List.unmodifiable([...scriptsNotifier.value, meta]);
    _log(_Engine.userApi.code, 'info', '已导入 ${meta.name}${host == null ? '' : '（$host）'}');
    await _store.setActiveId(meta.id);
    await _activate(meta);
  }

  Future<void> activateScript(String id) => _changeScripts(() async {
    final meta = scriptsNotifier.value.firstWhere((script) => script.id == id);
    await _store.setActiveId(id);
    await _activate(meta);
  });

  Future<void> deleteScript(String id) => _changeScripts(() async {
    final wasActive = userApiStateNotifier.value.meta?.id == id;
    try {
      await _store.remove(id);
    } finally {
      final saved = await _store.loadAll();
      scriptsNotifier.value = List.unmodifiable(saved.scripts);
      if (wasActive && saved.activeId == null) {
        userApiStateNotifier.value = const LxUserApiState();
        await _destroyUserApi();
      }
    }
    _log(_Engine.userApi.code, 'info', '已删除音源');
  });

  Future<void> reloadActiveScript() => _changeScripts(() async {
    final meta = userApiStateNotifier.value.meta;
    if (meta != null) await _activate(meta);
  });

  Future<void> _changeScripts(Future<void> Function() change) async {
    _requireAndroid();
    final previous = _scriptChanges;
    final done = Completer<void>();
    _scriptChanges = done.future;
    try {
      await previous;
      await ensureInitialized();
      await change();
    } finally {
      done.complete();
    }
  }

  Future<void> _activate(LxUserApiMeta meta) async {
    userApiStateNotifier.value = LxUserApiState(status: LxUserApiStatus.loading, meta: meta);
    try {
      await _destroyUserApi();
      final preload = await rootBundle.loadString('assets/lx/user-api-preload.js');
      final script = await _store.readScript(meta);
      final signal = _userApiInit = Completer<Map<String, dynamic>>();
      _userEngineStarted = true;
      final reply = await _awaitReply(
        _invokeAccepted('loadUserApi', {
          'preloadScript': preload,
          'id': meta.id,
          'name': meta.name,
          'description': meta.description,
          'version': meta.version,
          'author': meta.author,
          'homepage': meta.homepage,
          'script': script,
        }),
        signal,
        '等待音源初始化超时',
      );
      if (reply['status'] != true) throw StateError(reply['errorMessage'] as String? ?? '音源初始化失败');

      final info = reply['info'] as Map<String, dynamic>?;
      final sources = info?['sources'] as Map<String, dynamic>? ?? const {};
      final supportedQualities = <String, List<String>>{};
      final supportedActions = <String, List<String>>{};
      for (final entry in sources.entries) {
        final source = entry.value as Map<String, dynamic>;
        if (source['type'] != 'music') continue;
        supportedQualities[entry.key] = List.unmodifiable(source['qualitys'] as List<dynamic>? ?? const []);
        supportedActions[entry.key] = List.unmodifiable(source['actions'] as List<dynamic>? ?? const []);
      }
      userApiStateNotifier.value = LxUserApiState(
        status: LxUserApiStatus.ready,
        meta: meta,
        supportedQualities: Map.unmodifiable(supportedQualities),
        supportedActions: Map.unmodifiable(supportedActions),
      );
      _log(_Engine.userApi.code, 'info', '${meta.name} 已就绪');
    } catch (error) {
      final message = '[初始化音源] ${_describe(error)}';
      userApiStateNotifier.value = LxUserApiState(status: LxUserApiStatus.error, meta: meta, errorMessage: message);
      _log(_Engine.userApi.code, 'error', message);
    } finally {
      _userApiInit = null;
    }
  }

  void dismissUpdateAlert() => updateAlertNotifier.value = null;

  Future<void> _destroyUserApi() async {
    updateAlertNotifier.value = null;
    if (!_userEngineStarted) return;
    _userEngineStarted = false;
    for (final key in _pending.keys.where((key) => key.$1 == _Engine.userApi).toList()) {
      _pending.remove(key)!.completeError(StateError('当前音源已切换或重载'));
    }
    for (final key in _httpRequests.keys.where((key) => key.$1 == _Engine.userApi).toList()) {
      _httpProxy.cancel(_httpRequests.remove(key)!);
    }
    await _bridge.invokeMethod<void>('destroyUserApi').timeout(_timeout);
  }

  Future<LxSearchResult> search({required LxPlatform platform, required String keyword, int page = 1, int limit = 30}) =>
      _runStage(_Engine.musicSdk, '搜索', () async {
        final query = keyword.trim();
        if (query.isEmpty) throw ArgumentError('请输入搜索关键词');
        final result = await _rpc('search', {'source': platform.code, 'keyword': query, 'page': page, 'limit': limit});
        return LxSearchResult.fromJson(result, platform);
      });

  Future<List<String>> tipSearch(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) return const [];
    final result = await _rpc('tipSearch', {'keyword': query});
    return List<String>.unmodifiable((result['list'] as List<dynamic>).map((e) => e.toString()).where((s) => s.isNotEmpty));
  }

  Future<LxSonglistSearchResult> searchSonglist({required LxPlatform platform, required String keyword, int page = 1, int limit = 20}) =>
      _runStage(_Engine.musicSdk, '搜索歌单', () async {
        final query = keyword.trim();
        if (query.isEmpty) throw ArgumentError('请输入搜索关键词');
        final result = await _rpc('searchSonglist', {'source': platform.code, 'keyword': query, 'page': page, 'limit': limit});
        return LxSonglistSearchResult.fromJson(result, platform);
      });

  Future<LxSonglistDetail> getSonglistDetail({required LxPlatform platform, required String id, int page = 1, LxSonglist? fallbackInfo}) =>
      _runStage(_Engine.musicSdk, '获取歌单详情', () async {
        final result = await _rpc('getSonglistDetail', {'source': platform.code, 'id': id, 'page': page});
        result['info'] = {'id': id, ...result['info'] as Map<String, dynamic>};
        return LxSonglistDetail.fromJson(result, platform, fallbackInfo: fallbackInfo);
      });

  Future<({String url, String quality, int elapsedMs})> resolveMusicUrl({required LxTrack track, required String quality}) =>
      _runStage(_Engine.userApi, '解析直链', () async {
        _requireAndroid();
        await ensureInitialized();
        final state = userApiStateNotifier.value;
        if (state.status != LxUserApiStatus.ready) throw StateError(state.errorMessage ?? '请先启用并初始化自定义音源');
        final source = track.source.code;
        if (state.supportedActions[source]?.contains('musicUrl') != true) throw StateError('当前音源不支持 ${track.source.label} 的直链解析');
        final elapsed = Stopwatch()..start();
        final reply = await _request(_Engine.userApi, 'request', 'requestKey', {
          'data': {
            'source': source,
            'action': 'musicUrl',
            'info': {'type': quality, 'musicInfo': track.rawMusicInfo},
          },
        });
        if (reply['status'] != true) throw StateError(reply['errorMessage'] as String? ?? '音源解析失败');
        final result = reply['result'] as Map<String, dynamic>;
        final data = result['data'] as Map<String, dynamic>;
        final url = data['url'] as String;
        final uri = Uri.tryParse(url);
        if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) {
          throw const FormatException('音源返回的直链无效');
        }
        return (url: url, quality: data['type'] as String, elapsedMs: elapsed.elapsedMilliseconds);
      });

  Future<LxLyricResult> fetchLyric({required LxTrack track}) => _runStage(_Engine.musicSdk, '拉取歌词', () async {
    final result = await _rpc('getLyric', {'source': track.source.code, 'musicInfo': track.rawMusicInfo});
    return LxLyricResult.fromJson(result);
  });

  Future<String?> fetchPic({required LxTrack track}) => _runStage(_Engine.musicSdk, '拉取封面', () async {
    final result = await _rpc('getPic', {'source': track.source.code, 'musicInfo': track.rawMusicInfo});
    return result['picUrl'] as String?;
  });

  Future<Map<String, dynamic>> _rpc(String method, Map<String, dynamic> params) async {
    await ensureMusicSdkReady();
    final reply = await _request(_Engine.musicSdk, 'rpc', 'callId', {'method': method, 'params': params});
    if (reply['ok'] != true) throw StateError(reply['error']?.toString() ?? 'Music SDK 调用失败');
    return reply['result'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _request(_Engine engine, String action, String idField, Map<String, dynamic> payload) async {
    final id = 'lx_${_nextId++}';
    final key = (engine, id);
    final signal = _pending[key] = Completer<Map<String, dynamic>>();
    try {
      return await _awaitReply(_send(engine, action, {idField: id, ...payload}), signal, '等待 $action 响应超时');
    } finally {
      _pending.remove(key);
    }
  }

  Future<Map<String, dynamic>> _awaitReply(Future<void> dispatch, Completer<Map<String, dynamic>> signal, String timeoutMessage) async {
    late Map<String, dynamic> reply;
    await Future.wait<void>([
      dispatch,
      signal.future.then<void>((payload) {
        reply = payload;
      }),
    ], eagerError: true).timeout(_timeout, onTimeout: () => throw TimeoutException(timeoutMessage));
    return reply;
  }

  Future<void> _onEvent(Object? event) async {
    try {
      final envelope = event as Map<Object?, Object?>;
      final engine = _Engine.values.firstWhere((engine) => engine.code == envelope['engine']);
      final action = envelope['action'] as String;
      if (action == 'log') {
        _log(engine.code, envelope['level'] as String, envelope['message'] as String);
        return;
      }

      final raw = envelope['data'] as String?;
      switch ((engine, action)) {
        case (_Engine.userApi, 'init'):
          final signal = _userApiInit;
          if (signal != null && !signal.isCompleted) signal.complete(jsonDecode(raw!) as Map<String, dynamic>);
        case (_Engine.userApi, 'showUpdateAlert'):
          if (!_userEngineStarted) return;
          final data = jsonDecode(raw!) as Map<String, dynamic>;
          final log = (data['log'] as String?)?.trim() ?? '';
          if (log.isEmpty) return;
          final name = (data['name'] as String?)?.trim() ?? '';
          final updateUrl = (data['updateUrl'] as String?)?.trim() ?? '';
          final sourceName = name.isNotEmpty ? name : (userApiStateNotifier.value.meta?.name ?? '自定义音源');
          updateAlertNotifier.value = LxUpdateAlert(sourceName: sourceName, log: log, updateUrl: updateUrl.isEmpty ? null : updateUrl);
          _log(engine.code, 'info', '$sourceName 提供了更新提示');
        case (_Engine.userApi, 'response') || (_Engine.musicSdk, 'rpcResponse'):
          final reply = jsonDecode(raw!) as Map<String, dynamic>;
          final id = reply[engine == _Engine.userApi ? 'requestKey' : 'callId'] as String;
          _pending.remove((engine, id))?.complete(reply);
        case (_, 'request'):
          if (engine == _Engine.userApi && !_userEngineStarted) return;
          await _proxyRequest(engine, jsonDecode(raw!) as Map<String, dynamic>);
        case (_, 'cancelRequest'):
          final data = jsonDecode(raw!);
          final id = data is String ? data : (data as Map<String, dynamic>)['requestKey'] as String;
          final localId = _httpRequests[(engine, id)];
          if (localId != null) _httpProxy.cancel(localId);
      }
    } catch (error) {
      _log('bridge', 'error', '[处理事件] ${_describe(error)}');
    }
  }

  Future<void> _proxyRequest(_Engine engine, Map<String, dynamic> payload) async {
    final requestKey = payload['requestKey'] as String;
    final key = (engine, requestKey);
    if (_httpRequests.containsKey(key)) throw StateError('重复的 HTTP 请求标识');
    final localId = _httpRequests[key] = 'http_${_nextId++}';
    Map<String, dynamic>? response;
    String? error;
    try {
      response = await _httpProxy.execute(
        requestKey: localId,
        url: payload['url'] as String,
        options: payload['options'] as Map<String, dynamic>? ?? const {},
      );
    } catch (failure) {
      error = _describe(failure);
    }
    if (_httpRequests[key] != localId) return;
    _httpRequests.remove(key);
    await _send(engine, 'response', {'requestKey': requestKey, 'error': error, 'response': response});
  }

  Future<void> _send(_Engine engine, String action, Map<String, dynamic> data) =>
      _invokeAccepted(engine.sendMethod, {'action': action, 'data': jsonEncode(data)});

  Future<void> _invokeAccepted(String method, Map<String, dynamic> args) async {
    if (await _bridge.invokeMethod<bool>(method, args) != true) throw StateError('原生桥接拒绝 $method');
  }

  static void _requireAndroid() {
    if (!isSupported) throw UnsupportedError(_unsupported);
  }

  Future<T> _runStage<T>(_Engine engine, String stage, Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error) {
      final message = '[$stage] ${_describe(error)}';
      _log(engine.code, 'error', message);
      throw Exception(message);
    }
  }

  static String _describe(Object error) => switch (error) {
    FormatException(:final message) => message,
    PlatformException(:final message, :final code) => message ?? code,
    TimeoutException(:final message) => message ?? '请求超时',
    StateError(:final message) => message,
    _ => error.toString().replaceFirst('Exception: ', ''),
  };

  void logDiagnostic(String engine, String level, String message) => _log(engine, level, message);

  void _log(String engine, String level, String message) {
    if (_logs.length == 200) _logs.removeFirst();
    _logs.addLast(LxLogEntry(timestamp: DateTime.now(), engine: engine, level: level, message: message));
    logsNotifier.value = List.unmodifiable(_logs);
  }

  void clearLogs() {
    _logs.clear();
    logsNotifier.value = const [];
  }
}
