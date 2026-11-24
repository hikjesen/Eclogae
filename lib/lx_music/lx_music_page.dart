import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:path/path.dart' as p;

import 'package:namida/class/route.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_storage/namida_storage.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

import 'lx_bridge_service.dart';
import 'lx_download_manager.dart';
import 'lx_models.dart';

class LxMusicPage extends StatefulWidget with NamidaRouteWidget {
  const LxMusicPage({super.key, this.initialTab = 0});

  static const title = 'LX Music';
  static const subtitle = '多平台音乐搜索、在线/本地音源管理、下载校验与自动入库';

  final int initialTab;

  @override
  RouteType get route => RouteType.SETTINGS_subpage;

  @override
  String? get name => title;

  @override
  State<LxMusicPage> createState() => _LxMusicPageState();
}

const _tabPadding = EdgeInsets.fromLTRB(16, 12, 16, 16 + Dimensions.globalBottomPaddingTotal);

class _LxMusicPageState extends State<LxMusicPage> with SingleTickerProviderStateMixin {
  final _bridge = LxBridgeService.inst;
  final _downloads = LxDownloadManager.inst;
  late final _tabs = TabController(length: 3, initialIndex: widget.initialTab, vsync: this);
  late final _sourceChanges = Listenable.merge([_bridge.scriptsNotifier, _bridge.userApiStateNotifier]);

  bool _editingSources = false;
  bool _editingDownloadSettings = false;
  String? _sourceError;
  String? _downloadSettingsError;

  @override
  void initState() {
    super.initState();
    _editSources('读取音源', _bridge.ensureInitialized);
    _editDownloadSettings(_downloads.ensureLoaded);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usesNamidaAppBar = identical(Navigator.maybeOf(context), NamidaNavigator.inst.navKey.currentState);
    return Scaffold(
      appBar: usesNamidaAppBar ? null : AppBar(title: const Text(LxMusicPage.title)),
      body: SafeArea(
        top: usesNamidaAppBar,
        child: Column(
          children: [
            ValueListenableBuilder<int>(
              valueListenable: _downloads.activeCountNotifier,
              builder: (context, count, _) => TabBar(
                controller: _tabs,
                tabs: [
                  const Tab(text: '搜索下载'),
                  Tab(text: count > 0 ? '下载管理 ($count)' : '下载管理'),
                  const Tab(text: '音源与日志'),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _SearchTab(onShowDownloads: () => _tabs.animateTo(1)),
                      _buildDownloads(),
                      ListView(
                        key: const PageStorageKey('lx-sources'),
                        padding: _tabPadding,
                        children: [_buildSources(), const SizedBox(height: 12), _buildLogs()],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editDownloadSettings(Future<void> Function() edit) async {
    if (_editingDownloadSettings) return;
    setState(() {
      _editingDownloadSettings = true;
      _downloadSettingsError = null;
    });
    try {
      await edit();
    } catch (error) {
      if (mounted) setState(() => _downloadSettingsError = '[下载设置] ${_displayError(error)}');
    } finally {
      if (mounted) setState(() => _editingDownloadSettings = false);
    }
  }

  Widget _buildDownloadSettings() => ValueListenableBuilder<LxDownloadSettings>(
    valueListenable: _downloads.settingsNotifier,
    builder: (context, options, _) {
      final directory = _downloads.resolveEffectiveDownloadDir();
      final canEdit = !_editingDownloadSettings;
      final qualities = LxDownloadSettings.qualityOptions;
      void save(LxDownloadSettings next) => _editDownloadSettings(() => _downloads.updateSettings(next));
      return Card.outlined(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          key: const PageStorageKey('lx-download-settings'),
          title: const Text('下载设置'),
          subtitle: Text(_downloadSettingsError ?? directory, maxLines: 2, overflow: TextOverflow.ellipsis),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            SelectableText(directory),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(
                  onPressed: canEdit
                      ? () => _editDownloadSettings(() async {
                          final picked = await NamidaFileBrowser.pickDirectory(note: '选择 LX 下载目录', initialDirectory: directory);
                          if (picked != null) {
                            await _downloads.updateSettings(_downloads.settingsNotifier.value.copyWith(downloadDir: picked.path));
                          }
                        })
                      : null,
                  child: const Text('选择目录'),
                ),
                TextButton(
                  onPressed: canEdit && options.downloadDir != null ? () => save(options.copyWith(downloadDir: null)) : null,
                  child: const Text('恢复默认'),
                ),
              ],
            ),
            Row(
              children: [
                const Expanded(child: Text('首选音质')),
                DropdownButton<String>(
                  value: qualities.contains(options.preferredQuality) ? options.preferredQuality : null,
                  hint: const Text('选择音质'),
                  items: [for (final quality in qualities) DropdownMenuItem(value: quality, child: Text(quality))],
                  onChanged: canEdit
                      ? (quality) {
                          if (quality != null) save(options.copyWith(preferredQuality: quality));
                        }
                      : null,
                ),
              ],
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('自动跨平台换源'),
              value: options.autoSwitchSource,
              onChanged: canEdit ? (value) => save(options.copyWith(autoSwitchSource: value)) : null,
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('导出同名 .lrc 歌词'),
              value: options.exportLrc,
              onChanged: canEdit ? (value) => save(options.copyWith(exportLrc: value)) : null,
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('内嵌专辑封面'),
              value: options.embedCover,
              onChanged: canEdit ? (value) => save(options.copyWith(embedCover: value)) : null,
            ),
            if (_editingDownloadSettings) const LinearProgressIndicator(),
            if (_downloadSettingsError case final error?) _ErrorText(error),
          ],
        ),
      );
    },
  );

  Widget _buildDownloads() => ValueListenableBuilder<List<LxDownloadTask>>(
    valueListenable: _downloads.tasksNotifier,
    child: _buildDownloadSettings(),
    builder: (context, tasks, settingsCard) => ListView.builder(
      key: const PageStorageKey('lx-downloads'),
      padding: _tabPadding,
      itemCount: tasks.isEmpty ? 3 : tasks.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return settingsCard!;
        if (index == 1) {
          return Row(
            children: [
              Expanded(child: Text('下载任务 (${tasks.length})', style: Theme.of(context).textTheme.titleMedium)),
              Tooltip(
                message: '清理已完成、失败和已取消的任务',
                child: TextButton(
                  onPressed: tasks.any((task) => !task.isActive) ? _downloads.clearFinished : null,
                  child: const Text('清理已完成'),
                ),
              ),
            ],
          );
        }
        if (tasks.isEmpty) return const Text('暂无下载任务');
        final task = tasks[index - 2];
        return _DownloadTaskCard(key: ValueKey(task.id), task: task);
      },
    ),
  );

  Future<void> _editSources(String stage, Future<void> Function() edit) async {
    if (_editingSources) return;
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

  Future<void> _importLocal() => _editSources('本地导入', () async {
    final file = await NamidaFileBrowser.pickFile(note: '选择 LX .js 音源', memeType: NamidaStorageFileMemeType.any);
    if (file != null) await _bridge.importScript(file);
  });

  Future<void> _importOnline() => _editSources('在线导入', () async {
    var input = '';
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        void submit(String value) => Navigator.of(dialogContext).pop(value);
        return AlertDialog(
          title: const Text('在线 URL 导入'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(labelText: '音源 URL', hintText: 'https://example.com/source.js'),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onChanged: (value) => input = value,
            onSubmitted: submit,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
            FilledButton(onPressed: () => submit(input), child: const Text('导入')),
          ],
        );
      },
    );
    if (url != null) await _bridge.importScriptFromUrl(url);
  });

  Widget _buildSources() => AnimatedBuilder(
    animation: _sourceChanges,
    builder: (context, _) {
      final state = _bridge.userApiStateNotifier.value;
      final scripts = _bridge.scriptsNotifier.value;
      final activeId = state.meta?.id;
      final selectedId = scripts.any((script) => script.id == activeId) ? activeId : null;
      final busy = _editingSources || state.status == LxUserApiStatus.loading;
      final canEdit = LxBridgeService.isSupported && !busy;
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
              DropdownButton<String>(
                isExpanded: true,
                value: selectedId,
                hint: Text(scripts.isEmpty ? '暂无已导入音源' : '选择音源'),
                items: [
                  for (final script in scripts)
                    DropdownMenuItem(value: script.id, child: Text('${script.name} (${script.fileName})', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: canEdit
                    ? (id) {
                        if (id != null && id != selectedId) _editSources('切换音源', () => _bridge.activateScript(id));
                      }
                    : null,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton.tonal(onPressed: canEdit ? _importLocal : null, child: const Text('本地导入 .js')),
                  OutlinedButton(onPressed: canEdit ? _importOnline : null, child: const Text('在线 URL 导入')),
                  TextButton(onPressed: canEdit && selectedId != null ? () => _editSources('重载音源', _bridge.reloadActiveScript) : null, child: const Text('重载')),
                  TextButton(
                    onPressed: canEdit && selectedId != null ? () => _editSources('删除音源', () => _bridge.deleteScript(selectedId)) : null,
                    child: const Text('删除当前音源'),
                  ),
                ],
              ),
              if (busy) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
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

  Widget _buildLogs() => ValueListenableBuilder<List<LxLogEntry>>(
    valueListenable: _bridge.logsNotifier,
    builder: (context, logs, _) => Card.outlined(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        key: const PageStorageKey('lx-diagnostic-logs'),
        title: const Text('诊断日志'),
        subtitle: Text('${logs.length} 条'),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(onPressed: logs.isEmpty ? null : () => _copy(context, logs.join('\n')), child: const Text('复制日志')),
              TextButton(onPressed: logs.isEmpty ? null : _bridge.clearLogs, child: const Text('清空')),
            ],
          ),
          if (logs.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                primary: false,
                child: SelectableText(logs.reversed.join('\n'), style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
        ],
      ),
    ),
  );
}

class _DownloadTaskCard extends StatelessWidget {
  const _DownloadTaskCard({super.key, required this.task});

  final LxDownloadTask task;

  @override
  Widget build(BuildContext context) {
    final downloads = LxDownloadManager.inst;
    final indexedTrack = task.indexedTrack;
    final resolvedSource = task.resolvedSource;
    final savedPath = task.savedPath;
    final completed = task.stage == LxDownloadStage.completed;
    return Card.filled(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(task.track.name, style: Theme.of(context).textTheme.titleMedium)),
                const SizedBox(width: 8),
                Chip(label: Text(task.stage.label), visualDensity: VisualDensity.compact),
              ],
            ),
            if (task.track.singer.isNotEmpty) Text(task.track.singer),
            Text(resolvedSource == null ? '请求音质 · ${task.requestedQuality}' : '${resolvedSource.label} · ${task.resolvedQuality}'),
            if (task.isActive) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              Text('已接收 ${task.receivedBytes.fileSizeFormatted}'),
            ],
            if (completed && savedPath != null) Text('${p.basename(savedPath)}${task.lrcPath != null ? ' · .lrc' : ''}'),
            if (task.errorMessage case final error?) _ErrorText(error),
            if (task.canCancel || !task.isActive)
              Wrap(
                spacing: 8,
                children: [
                  if (task.canCancel) TextButton(onPressed: () => downloads.cancel(task.id), child: const Text('取消')),
                  if (task.canRetry) TextButton(onPressed: () => downloads.retry(task.id), child: const Text('重试')),
                  if (completed && indexedTrack != null)
                    FilledButton.tonal(
                      onPressed: () async {
                        try {
                          await Player.inst.playKeepingQueue([indexedTrack], QueueSource.others(LxMusicPage.title));
                        } catch (error) {
                          if (context.mounted) _showMessage(context, '[播放] ${_displayError(error)}');
                        }
                      },
                      child: const Text('立即播放'),
                    ),
                  if (!task.isActive) TextButton(onPressed: () => downloads.removeTask(task.id), child: const Text('移除')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchTab extends StatefulWidget {
  const _SearchTab({required this.onShowDownloads});

  final VoidCallback onShowDownloads;

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> with AutomaticKeepAliveClientMixin<_SearchTab> {
  final _keyword = TextEditingController();
  final _selection = <String, LxTrack>{};
  LxPlatform _platform = LxPlatform.kw;
  bool _searching = false;
  bool _multiSelect = false;
  String _lastQuery = '';
  String? _searchError;
  LxSearchResult? _result;
  LxTrack? _expandedTrack;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _search(String query, {int? page}) async {
    if (_searching || !LxBridgeService.isSupported) return;
    setState(() {
      _searching = true;
      _searchError = null;
      _expandedTrack = null;
      if (page == null) {
        _selection.clear();
        _result = null;
      }
    });
    try {
      final result = await LxBridgeService.inst.search(platform: _platform, keyword: query, page: page ?? 1);
      if (!mounted) return;
      setState(() {
        _lastQuery = query;
        _result = result;
      });
    } catch (error) {
      if (mounted) setState(() => _searchError = _displayError(error));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _enqueueSelection() {
    final added = LxDownloadManager.inst.enqueueBatch(_selection.values);
    setState(_selection.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加入下载队列 (${added.length})'),
        action: SnackBarAction(
          label: '查看下载',
          onPressed: () {
            if (mounted) widget.onShowDownloads();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final result = _result;
    final canSearch = LxBridgeService.isSupported && !_searching;
    return ListView(
      key: const PageStorageKey('lx-search'),
      padding: _tabPadding,
      children: [
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
                          _selection.clear();
                          _result = null;
                          _searchError = null;
                          _expandedTrack = null;
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
                enabled: LxBridgeService.isSupported,
                decoration: const InputDecoration(labelText: '关键词', border: OutlineInputBorder()),
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(onPressed: canSearch ? () => _search(_keyword.text) : null, icon: const Icon(Icons.search), label: const Text('搜索')),
          ],
        ),
        if (!LxBridgeService.isSupported) const _ErrorText('LX 桥接仅支持 Android'),
        if (_searching) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
        if (_searchError case final error?) _ErrorText(error),
        if (result != null) ...[
          const SizedBox(height: 12),
          Text(result.tracks.isEmpty ? '未找到歌曲' : '共 ${result.total} 首歌曲'),
          if (result.tracks.isNotEmpty || _selection.isNotEmpty) _buildBatchActions(result.tracks),
          for (final track in result.tracks) _buildTrack(context, track),
          if (result.allPage > 1)
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
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

  Widget _buildBatchActions(List<LxTrack> tracks) {
    final pageSelected = tracks.every((track) => _selection.containsKey(track.id));
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: () => setState(() {
            _multiSelect = !_multiSelect;
            if (!_multiSelect) _selection.clear();
          }),
          child: Text(_multiSelect ? '退出多选' : '多选'),
        ),
        if (_multiSelect) ...[
          if (tracks.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                for (final track in tracks) {
                  if (pageSelected) {
                    _selection.remove(track.id);
                  } else {
                    _selection[track.id] = track;
                  }
                }
              }),
              child: Text(pageSelected ? '取消本页全选' : '全选本页'),
            ),
          FilledButton(
            onPressed: _selection.isEmpty ? null : _enqueueSelection,
            child: Text('下载已选 (${_selection.length})'),
          ),
        ],
      ],
    );
  }

  Widget _buildTrack(BuildContext context, LxTrack track) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selection.containsKey(track.id);
    final expanded = identical(_expandedTrack, track);
    final details = [track.singer, track.albumName, track.interval].where((value) => value.isNotEmpty).join(' · ');
    void toggleSelection() => setState(() {
      if (selected) {
        _selection.remove(track.id);
      } else {
        _selection[track.id] = track;
      }
    });
    void toggleDetails() => setState(() => _expandedTrack = expanded ? null : track);
    return Column(
      key: ObjectKey(track),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: selected || expanded ? scheme.surfaceContainerHighest : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            textColor: scheme.onSurface,
            leading: _multiSelect ? Checkbox(value: selected, onChanged: (_) => toggleSelection(), semanticLabel: '选择 ${track.name}') : null,
            title: Text(track.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (details.isNotEmpty) Text(details),
                if (track.qualities.isNotEmpty)
                  Wrap(spacing: 6, children: [for (final quality in track.qualities) Chip(label: Text(quality), visualDensity: VisualDensity.compact)]),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _enqueueTrack(context, track),
                  tooltip: '下载 ${track.name}',
                  icon: const Icon(Icons.download_outlined),
                ),
                IconButton(
                  onPressed: toggleDetails,
                  tooltip: expanded ? '收起详情' : '展开详情',
                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ),
              ],
            ),
            onTap: _multiSelect ? toggleSelection : toggleDetails,
          ),
        ),
        if (expanded) _TrackDetails(track: track),
        const Divider(height: 1),
      ],
    );
  }
}

class _TrackDetails extends StatefulWidget {
  const _TrackDetails({required this.track});

  final LxTrack track;

  @override
  State<_TrackDetails> createState() => _TrackDetailsState();
}

class _TrackDetailsState extends State<_TrackDetails> {
  final _bridge = LxBridgeService.inst;
  String? _selectedQuality;
  String? _urlError;
  String? _lyricError;
  bool _resolving = false;
  bool _fetchingLyric = false;
  String _lyricMode = '原文';
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
      _lyricMode = '原文';
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
      final listed = track.qualities.isEmpty ? supported : track.qualities;
      final matching = listed.where(supported.contains).toSet();
      final choices = matching.isEmpty ? listed.toSet() : matching;
      final downloadQualities = choices.where(LxDownloadSettings.qualityOptions.contains);
      final quality = choices.contains(_selectedQuality) ? _selectedQuality : downloadQualities.firstOrNull ?? choices.firstOrNull;
      final canDownload = downloadQualities.contains(quality);
      final link = _urlResult;
      final lyric = _lyricResult;
      return Card.outlined(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButton<String>(
                isExpanded: true,
                value: quality,
                hint: const Text('无可选音质'),
                items: [for (final choice in choices) DropdownMenuItem(value: choice, child: Text(choice))],
                onChanged: _resolving || choices.isEmpty
                    ? null
                    : (value) => setState(() {
                        _selectedQuality = value;
                        _urlError = null;
                        _urlResult = null;
                      }),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton.tonal(onPressed: canDownload ? () => _enqueueTrack(context, track, quality: quality) : null, child: const Text('按所选音质下载')),
                  OutlinedButton(onPressed: !_resolving && quality != null ? () => _resolve(quality) : null, child: const Text('测试解析直链')),
                  OutlinedButton(onPressed: _fetchingLyric ? null : _fetchLyric, child: const Text('拉取完整歌词')),
                ],
              ),
              if (_resolving || _fetchingLyric) ...[const SizedBox(height: 8), const LinearProgressIndicator()],
              if (_urlError case final error?) _ErrorText(error),
              if (link != null) ...[
                const SizedBox(height: 12),
                Text('直链 ${link.quality} · ${link.elapsedMs} ms'),
                SelectableText(link.url),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(onPressed: () => _copy(context, link.url), child: const Text('复制直链')),
                ),
              ],
              if (_lyricError case final error?) _ErrorText(error),
              if (lyric != null) ...[const SizedBox(height: 12), _buildLyrics(lyric.lyrics, lyric.elapsedMs)],
            ],
          ),
        ),
      );
    },
  );

  Widget _buildLyrics(LxLyricResult lyrics, int elapsedMs) {
    final translation = lyrics.tlyric;
    final romanization = lyrics.rlyric;
    final modes = {
      '原文': lyrics.lyric,
      if (translation != null && translation.trim().isNotEmpty) '翻译': translation,
      if (romanization != null && romanization.trim().isNotEmpty) '罗马音': romanization,
    };
    final text = modes[_lyricMode]!;
    final lines = const LineSplitter().convert(text).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('歌词共 $lines 行 · $elapsedMs ms'),
            TextButton(onPressed: text.isEmpty ? null : () => _copy(context, text), child: const Text('复制歌词')),
          ],
        ),
        if (modes.length > 1)
          Wrap(
            spacing: 8,
            children: [
              for (final mode in modes.keys)
                ChoiceChip(label: Text(mode), selected: _lyricMode == mode, onSelected: (_) => setState(() => _lyricMode = mode)),
            ],
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: SingleChildScrollView(
            key: ValueKey(_lyricMode),
            primary: false,
            child: SelectableText(text.isEmpty ? '该曲目暂无歌词' : text),
          ),
        ),
      ],
    );
  }
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

String _displayError(Object error) => switch (error) {
  FormatException(:final message) => message,
  StateError(:final message) => message,
  _ => error.toString().replaceFirst('Exception: ', ''),
};

void _enqueueTrack(BuildContext context, LxTrack track, {String? quality}) {
  LxDownloadManager.inst.enqueue(track, quality: quality);
  _showMessage(context, '已加入下载队列');
}

void _showMessage(BuildContext context, String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

Future<void> _copy(BuildContext context, String text) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) _showMessage(context, '已复制');
  } catch (error) {
    if (context.mounted) _showMessage(context, '[复制] ${_displayError(error)}');
  }
}
