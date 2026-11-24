import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_storage/namida_storage.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';

import 'lx_bridge_service.dart';
import 'lx_models.dart';

class LxPrototypePage extends StatefulWidget with NamidaRouteWidget {
  const LxPrototypePage({super.key});

  static const title = 'LX Music 原型诊断';
  static const subtitle = '导入自定义 .js 音源、多平台搜索与直链/歌词桥接验证';

  @override
  RouteType get route => RouteType.SETTINGS_subpage;

  @override
  String? get name => title;

  @override
  State<LxPrototypePage> createState() => _LxPrototypePageState();
}

class _LxPrototypePageState extends State<LxPrototypePage> {
  final _bridge = LxBridgeService.inst;
  final _keyword = TextEditingController();
  late final _sourceChanges = Listenable.merge([_bridge.scriptsNotifier, _bridge.userApiStateNotifier]);

  LxPlatform _platform = LxPlatform.kw;
  bool _editingSources = false;
  bool _searching = false;
  String? _sourceError;
  String? _searchError;
  String _lastQuery = '';
  LxSearchResult? _searchResult;
  LxTrack? _selectedTrack;

  @override
  void initState() {
    super.initState();
    _editSources('读取音源', _bridge.ensureInitialized);
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _editSources(String stage, Future<void> Function() edit) async {
    setState(() {
      _editingSources = true;
      _sourceError = null;
    });
    try {
      await edit();
    } catch (error) {
      if (mounted) setState(() => _sourceError = '[$stage] ${_displayError(error)}');
    } finally {
      if (mounted) setState(() => _editingSources = false);
    }
  }

  Future<void> _importScript() => _editSources('导入音源', () async {
    final file = await NamidaFileBrowser.pickFile(note: '选择 LX .js 音源', memeType: NamidaStorageFileMemeType.any);
    if (file != null) await _bridge.importScript(file);
  });

  Future<void> _search(String query, {int page = 1}) async {
    if (_searching || !LxBridgeService.isSupported) return;
    setState(() {
      _searching = true;
      _searchError = null;
      _selectedTrack = null;
      if (page == 1) _searchResult = null;
    });
    try {
      final result = await _bridge.search(platform: _platform, keyword: query, page: page);
      if (!mounted) return;
      setState(() {
        _lastQuery = query;
        _searchResult = result;
      });
    } catch (error) {
      if (mounted) setState(() => _searchError = _displayError(error));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usesNamidaAppBar = identical(Navigator.maybeOf(context), NamidaNavigator.inst.navKey.currentState);
    return Scaffold(
      appBar: usesNamidaAppBar ? null : AppBar(title: const Text(LxPrototypePage.title)),
      body: SafeArea(
        top: usesNamidaAppBar,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSources(),
                const SizedBox(height: 24),
                _buildSearch(context),
                const SizedBox(height: 16),
                for (final track in _searchResult?.tracks ?? const <LxTrack>[]) _buildTrack(track),
                const SizedBox(height: 16),
                _buildLogs(),
                kBottomPaddingWidget,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSources() => AnimatedBuilder(
    animation: _sourceChanges,
    builder: (context, _) {
      final state = _bridge.userApiStateNotifier.value;
      final scripts = _bridge.scriptsNotifier.value;
      final active = state.meta;
      final canEdit = LxBridgeService.isSupported && !_editingSources && state.status != LxUserApiStatus.loading;
      final status = switch (state.status) {
        LxUserApiStatus.idle => 'Idle',
        LxUserApiStatus.loading => 'Loading',
        LxUserApiStatus.ready => 'Ready',
        LxUserApiStatus.error => 'Error',
      };
      return Card.filled(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [Text('自定义音源', style: Theme.of(context).textTheme.titleLarge), Chip(label: Text(status))],
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                value: active != null && scripts.any((script) => script.id == active.id) ? active.id : null,
                hint: Text(scripts.isEmpty ? '暂无已导入音源' : '选择音源'),
                items: [
                  for (final script in scripts)
                    DropdownMenuItem(value: script.id, child: Text('${script.name} (${script.fileName})', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: canEdit
                    ? (id) {
                        if (id != null) _editSources('切换音源', () => _bridge.activateScript(id));
                      }
                    : null,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(onPressed: canEdit ? _importScript : null, icon: const Icon(Icons.file_upload_outlined), label: const Text('导入 .js')),
                  OutlinedButton(onPressed: canEdit && active != null ? () => _editSources('重载音源', _bridge.reloadActiveScript) : null, child: const Text('重载')),
                  TextButton(
                    onPressed: canEdit && active != null ? () => _editSources('删除音源', () => _bridge.deleteScript(active.id)) : null,
                    child: const Text('删除当前音源'),
                  ),
                ],
              ),
              if (_editingSources || state.status == LxUserApiStatus.loading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_sourceError case final error?) _ErrorText(error),
              if (state.errorMessage case final error?) _ErrorText(error),
              if (state.status == LxUserApiStatus.ready) ...[
                const SizedBox(height: 12),
                if (state.supportedActions.isEmpty) const Text('音源未声明支持的音乐平台'),
                for (final platform in LxPlatform.values)
                  if (state.supportedActions.containsKey(platform.code))
                    Text('${platform.label}  ${(state.supportedQualities[platform.code] ?? const []).join(' / ')}'),
              ],
            ],
          ),
        ),
      );
    },
  );

  Widget _buildSearch(BuildContext context) {
    final result = _searchResult;
    final canSearch = LxBridgeService.isSupported && !_searching;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('多平台搜索', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final platform in LxPlatform.values)
              ChoiceChip(
                label: Text(platform.label),
                selected: platform == _platform,
                onSelected: canSearch
                    ? (selected) {
                        if (!selected) return;
                        setState(() {
                          _platform = platform;
                          _searchResult = null;
                          _searchError = null;
                          _selectedTrack = null;
                        });
                      }
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _keyword,
                enabled: canSearch,
                decoration: const InputDecoration(labelText: '关键词', border: OutlineInputBorder()),
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(onPressed: canSearch ? () => _search(_keyword.text) : null, icon: const Icon(Icons.search), label: const Text('搜索')),
          ],
        ),
        if (_searching) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
        if (_searchError case final error?) _ErrorText(error),
        if (result != null) ...[
          const SizedBox(height: 12),
          Text(result.total == 0 ? '未找到歌曲' : '共 ${result.total} 首歌曲'),
          if (result.allPage > 1)
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(onPressed: canSearch && result.page > 1 ? () => _search(_lastQuery, page: result.page - 1) : null, child: const Text('上一页')),
                Text('${result.page} / ${result.allPage}'),
                TextButton(onPressed: canSearch && result.page < result.allPage ? () => _search(_lastQuery, page: result.page + 1) : null, child: const Text('下一页')),
              ],
            ),
        ],
      ],
    );
  }

  Widget _buildTrack(LxTrack track) {
    final selected = identical(_selectedTrack, track);
    final details = [track.singer, track.albumName, track.interval].where((value) => value.isNotEmpty).join(' / ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          selected: selected,
          title: Text(track.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (details.isNotEmpty) Text(details),
              if (track.qualities.isNotEmpty)
                Wrap(spacing: 6, children: [for (final quality in track.qualities) Chip(label: Text(quality), visualDensity: VisualDensity.compact)]),
            ],
          ),
          trailing: Icon(selected ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() => _selectedTrack = selected ? null : track),
        ),
        if (selected) _TrackVerificationPanel(key: ObjectKey(track), track: track),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildLogs() => ValueListenableBuilder<List<LxLogEntry>>(
    valueListenable: _bridge.logsNotifier,
    builder: (context, logs, _) => Card.outlined(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        title: const Text('诊断日志'),
        subtitle: Text('${logs.length} 条'),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: logs.isEmpty ? null : () => _copy(context, logs.join('\n')),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('复制日志'),
              ),
              TextButton(onPressed: logs.isEmpty ? null : _bridge.clearLogs, child: const Text('清空')),
            ],
          ),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(logs.reversed.join('\n'), style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    ),
  );
}

class _TrackVerificationPanel extends StatefulWidget {
  const _TrackVerificationPanel({super.key, required this.track});

  final LxTrack track;

  @override
  State<_TrackVerificationPanel> createState() => _TrackVerificationPanelState();
}

class _TrackVerificationPanelState extends State<_TrackVerificationPanel> {
  final _bridge = LxBridgeService.inst;
  String? _selectedQuality;
  String? _urlError;
  String? _lyricError;
  bool _resolving = false;
  bool _fetchingLyric = false;
  ({String url, String quality, int elapsedMs})? _urlResult;
  ({LxLyricResult lyrics, int elapsedMs})? _lyricResult;

  Future<void> _resolve(String quality) async {
    setState(() {
      _resolving = true;
      _urlError = null;
      _urlResult = null;
    });
    try {
      final result = await _bridge.resolveMusicUrl(track: widget.track, quality: quality);
      if (mounted) setState(() => _urlResult = result);
    } catch (error) {
      if (mounted) setState(() => _urlError = _displayError(error));
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _fetchLyric() async {
    setState(() {
      _fetchingLyric = true;
      _lyricError = null;
      _lyricResult = null;
    });
    final elapsed = Stopwatch()..start();
    try {
      final lyrics = await _bridge.fetchLyric(track: widget.track);
      if (mounted) setState(() => _lyricResult = (lyrics: lyrics, elapsedMs: elapsed.elapsedMilliseconds));
    } catch (error) {
      if (mounted) setState(() => _lyricError = _displayError(error));
    } finally {
      if (mounted) setState(() => _fetchingLyric = false);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<LxUserApiState>(
    valueListenable: _bridge.userApiStateNotifier,
    builder: (context, state, _) {
      final track = widget.track;
      final supported = state.supportedQualities[track.source.code] ?? const <String>[];
      final intersection = track.qualities.where(supported.contains).toList();
      final choices = intersection.isNotEmpty ? intersection : (track.qualities.isNotEmpty ? track.qualities : supported);
      final quality = choices.contains(_selectedQuality) ? _selectedQuality : choices.firstOrNull;
      final url = _urlResult;
      final lyric = _lyricResult;
      final preview = lyric == null ? '' : const LineSplitter().convert(lyric.lyrics.lyric).take(10).join('\n');
      return Card.filled(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('单曲验证', style: Theme.of(context).textTheme.titleMedium),
              DropdownButton<String>(
                isExpanded: true,
                value: quality,
                hint: const Text('无可选音质'),
                items: [for (final choice in choices) DropdownMenuItem(value: choice, child: Text(choice))],
                onChanged: _resolving ? null : (value) => setState(() => _selectedQuality = value),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(onPressed: !_resolving && quality != null ? () => _resolve(quality) : null, child: const Text('测试解析直链')),
                  OutlinedButton(onPressed: _fetchingLyric ? null : _fetchLyric, child: const Text('测试拉取歌词')),
                ],
              ),
              if (_resolving || _fetchingLyric) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
              if (_urlError case final error?) _ErrorText(error),
              if (url != null) ...[
                const SizedBox(height: 12),
                Text('直链 ${url.quality}  ·  ${url.elapsedMs} ms'),
                SelectableText(url.url),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(onPressed: () => _copy(context, url.url), icon: const Icon(Icons.copy_outlined), label: const Text('复制直链')),
                ),
              ],
              if (_lyricError case final error?) _ErrorText(error),
              if (lyric != null) ...[
                const SizedBox(height: 12),
                Text('歌词预览  ·  ${lyric.elapsedMs} ms'),
                SelectableText(preview.isEmpty ? '该曲目暂无歌词' : preview),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: SelectableText(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
  );
}

String _displayError(Object error) => error is FormatException ? error.message : error.toString().replaceFirst('Exception: ', '');

Future<void> _copy(BuildContext context, String text) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) messenger.showSnackBar(const SnackBar(content: Text('已复制')));
  } catch (error) {
    if (context.mounted) messenger.showSnackBar(SnackBar(content: Text('[复制] ${_displayError(error)}')));
  }
}
