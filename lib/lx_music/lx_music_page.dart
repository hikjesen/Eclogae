import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/ui/pages/main_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

import 'lx_bridge_service.dart';
import 'lx_download_manager.dart';
import 'lx_models.dart';
import 'lx_settings_page.dart';
import 'lx_user_api_store.dart';
import 'widgets/lx_download_quality_dialog.dart';
import 'widgets/lx_download_task_card.dart';
import 'widgets/lx_lyrics_sheet.dart';
import 'widgets/lx_source_dialogs.dart';
import 'widgets/lx_track_tile.dart';

class LxMusicPage extends StatefulWidget with NamidaRouteWidget {
  const LxMusicPage({super.key});

  static const title = '在线曲库';
  static final _requestedSection = ValueNotifier<int?>(null);

  static void openSection(int index) {
    _requestedSection.value = index;
    if (NamidaNavigator.inst.currentRoute?.route != RouteType.YOUTUBE_HOME) {
      ScrollSearchController.inst.animatePageController(LibraryTab.youtube, jumpToTopIfSamePage: false);
    }
  }

  @override
  RouteType get route => RouteType.YOUTUBE_HOME;

  @override
  String? get name => title;

  @override
  State<LxMusicPage> createState() => _LxMusicPageState();
}

const _listPadding = EdgeInsets.fromLTRB(12, 4, 12, Dimensions.globalBottomPaddingTotal);

Future<void> _playTrack(Track track) async {
  try {
    await Player.inst.playKeepingQueue([track], QueueSource.others(LxMusicPage.title));
  } catch (error) {
    snackyy(icon: Broken.info_circle, message: '播放失败：$error', isError: true);
  }
}

BoxDecoration _pillDecoration(NColorsData colors) => BoxDecoration(
  color: colors.cardTheme,
  borderRadius: BorderRadius.circular(12.0.multipliedRadius),
);

class _LxMusicPageState extends State<LxMusicPage> with SingleTickerProviderStateMixin {
  final _bridge = LxBridgeService.inst;
  final _downloads = LxDownloadManager.inst;
  final _searchScroll = NamidaScrollController.create();
  final _downloadsScroll = NamidaScrollController.create();
  late final TabController _tabs;
  late int _section;

  bool _showingUpdate = false;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    _section = LxMusicPage._requestedSection.value ?? 0;
    LxMusicPage._requestedSection.value = null;
    _tabs = TabController(length: 2, initialIndex: _section, vsync: this)..addListener(_onTabChanged);
    ScrollSearchController.inst.registerPageScrollController(LibraryTab.youtube, _scrollFor(_section));
    LxMusicPage._requestedSection.addListener(_onSectionRequested);
    _bridge.updateAlertNotifier.addListener(_scheduleUpdateAlert);
    NamidaNavigator.inst.currentWidgetStack.addListener(_scheduleUpdateAlert);
    _scheduleUpdateAlert();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait([_bridge.ensureInitialized(), _downloads.ensureLoaded()]);
    } catch (error) {
      if (mounted) setState(() => _initializationError = '初始化在线曲库失败：$error');
    }
  }

  ScrollController _scrollFor(int index) => index == 0 ? _searchScroll : _downloadsScroll;

  void _onTabChanged() {
    final index = _tabs.index;
    if (index == _section) return;
    final scrollSearch = ScrollSearchController.inst;
    scrollSearch.unregisterPageScrollController(LibraryTab.youtube, _scrollFor(_section));
    scrollSearch.registerPageScrollController(LibraryTab.youtube, _scrollFor(index));
    FocusScope.of(context).unfocus();
    setState(() => _section = index);
  }

  void _onSectionRequested() {
    final index = LxMusicPage._requestedSection.value;
    if (index == null || NamidaNavigator.inst.currentRoute?.route != RouteType.YOUTUBE_HOME) return;
    LxMusicPage._requestedSection.value = null;
    _tabs.animateTo(index);
  }

  void _scheduleUpdateAlert() {
    if (_showingUpdate || _bridge.updateAlertNotifier.value == null || NamidaNavigator.inst.currentRoute?.route != RouteType.YOUTUBE_HOME) return;
    _showingUpdate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final alert = _bridge.updateAlertNotifier.value;
      if (alert != null && NamidaNavigator.inst.currentRoute?.route == RouteType.YOUTUBE_HOME) {
        final dialog = LxUpdateAlertDialog.show(alert);
        _bridge.dismissUpdateAlert();
        await dialog;
      }
      if (!mounted) return;
      _showingUpdate = false;
      _scheduleUpdateAlert();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    NamidaNavigator.inst.currentWidgetStack.removeListener(_scheduleUpdateAlert);
    _bridge.updateAlertNotifier.removeListener(_scheduleUpdateAlert);
    LxMusicPage._requestedSection.removeListener(_onSectionRequested);
    ScrollSearchController.inst.unregisterPageScrollController(LibraryTab.youtube, _scrollFor(_section));
    _tabs.dispose();
    _searchScroll.dispose();
    _downloadsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: NDecoratedBox(
        decoration: (colors) => BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [(colors.accent ?? colors.primary).withOpacityExt(0.10), Colors.transparent],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: _PillGroup(
                      child: Row(
                        children: [
                          Expanded(
                            child: _Pill(
                              label: '搜索',
                              icon: Broken.search_normal_1,
                              selected: _section == 0,
                              onTap: () => _tabs.animateTo(0),
                            ),
                          ),
                          Expanded(
                            child: ValueListenableBuilder<int>(
                              valueListenable: _downloads.activeCountNotifier,
                              builder: (context, count, _) => _Pill(
                                label: '下载管理',
                                icon: Broken.document_download,
                                selected: _section == 1,
                                count: count,
                                onTap: () => _tabs.animateTo(1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  NDecoratedBox(
                    decoration: _pillDecoration,
                    child: NamidaIconButton(
                      icon: Broken.setting_2,
                      padding: const EdgeInsets.all(11),
                      tooltip: () => LxSettingsPage.title,
                      onPressed: () => const LxSettingsPage().navigate(),
                    ),
                  ),
                ],
              ),
            ),
            if (_initializationError case final error?)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _Notice(icon: Broken.info_circle, title: error, isError: true),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _SearchSection(controller: _searchScroll, onShowDownloads: () => LxMusicPage.openSection(1)),
                  _DownloadsSection(controller: _downloadsScroll),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SearchMode {
  songs('歌曲'),
  playlists('歌单');

  const _SearchMode(this.label);
  final String label;
}

class _SearchSection extends StatefulWidget {
  const _SearchSection({required this.controller, required this.onShowDownloads});

  final ScrollController controller;
  final VoidCallback onShowDownloads;

  @override
  State<_SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends State<_SearchSection> with AutomaticKeepAliveClientMixin<_SearchSection> {
  final _bridge = LxBridgeService.inst;
  final _downloads = LxDownloadManager.inst;
  final _store = LxUserApiStore();
  final _keyword = TextEditingController();
  final _selection = <String, LxTrack>{};
  late final _trackChanges = Listenable.merge([_downloads.tasksNotifier, _downloads.existingFilesVersion]);
  late final Future<void> _historyLoaded;

  LxPlatform _platform = LxPlatform.kw;
  _SearchMode _mode = _SearchMode.songs;
  List<String> _history = const [];
  bool _savingHistory = false;
  bool _searching = false;
  bool _startingDownload = false;
  bool _multiSelect = false;
  String _lastQuery = '';
  String? _searchError;
  LxSearchResult? _result;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _historyLoaded = _loadHistory();
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _store.loadSearchHistory();
      if (mounted) setState(() => _history = history);
    } catch (error) {
      _bridge.logDiagnostic('search', 'warning', '读取搜索历史失败：$error');
    }
  }

  Future<void> _saveHistory(List<String> history) async {
    setState(() => _savingHistory = true);
    try {
      await _store.saveSearchHistory(history);
      if (mounted) setState(() => _history = history);
    } catch (error) {
      if (mounted) snackyy(icon: Broken.info_circle, message: '保存搜索历史失败：$error', isError: true);
    } finally {
      if (mounted) setState(() => _savingHistory = false);
    }
  }

  Future<void> _search(String input, {int? page}) async {
    final query = input.trim();
    if (query.isEmpty || _mode != _SearchMode.songs || _searching || _savingHistory || !LxBridgeService.isSupported) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchError = null;
      if (page == null) {
        _selection.clear();
        _result = null;
      }
    });
    try {
      if (page == null) {
        await _historyLoaded;
        if (!mounted) return;
        await _saveHistory([query, ..._history.where((item) => item != query)].take(LxUserApiStore.maxSearchHistory).toList());
      }
      final result = await _bridge.search(platform: _platform, keyword: query, page: page ?? 1);
      if (!mounted) return;
      if (widget.controller.hasClients) widget.controller.jumpTo(0);
      setState(() {
        _lastQuery = query;
        _result = result;
      });
    } catch (error) {
      if (mounted) setState(() => _searchError = '搜索失败：$error');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectPlatform(LxPlatform platform) {
    if (_platform == platform || _searching) return;
    setState(() {
      _platform = platform;
      _selection.clear();
      _result = null;
      _searchError = null;
    });
  }

  void _toggleMultiSelect() => setState(() {
    _multiSelect = !_multiSelect;
    if (!_multiSelect) _selection.clear();
  });

  void _toggleSelected(LxTrack track) => setState(() {
    final key = track.uniqueKey;
    if (_selection.remove(key) == null) _selection[key] = track;
  });

  Future<void> _startDownload(List<LxTrack> tracks, {required bool forceQualityDialog}) async {
    if (_startingDownload) return;
    setState(() => _startingDownload = true);
    try {
      await _downloads.ensureLoaded();
      if (!mounted) return;
      final (:fresh, :inQueue, :onDisk) = _downloads.classifyDuplicates(tracks);
      final single = tracks.length == 1;
      if (fresh.isEmpty && onDisk.isEmpty) {
        snackyy(icon: Broken.info_circle, message: single ? '该曲目已在下载队列中' : '所选曲目均已在下载队列中');
        return;
      }

      var target = fresh;
      if (onDisk.isNotEmpty || inQueue.isNotEmpty) {
        final action = await LxDuplicateConfirmDialog.show(
          freshCount: fresh.length,
          onDiskCount: onDisk.length,
          inQueueCount: inQueue.length,
          singleTrackName: single ? tracks.single.name : null,
        );
        if (!mounted || action == LxDuplicateAction.cancel) return;
        if (action == LxDuplicateAction.downloadAll) target = [...fresh, ...onDisk];
      }

      final options = _downloads.settingsNotifier.value;
      var quality = options.effectiveQuickQuality;
      if (forceQualityDialog || !options.rememberLastQuality) {
        final chosenQuality = await LxDownloadQualityDialog.show(
          trackCount: target.length,
          singleTrack: target.length == 1 ? target.single : null,
          initialSettings: options,
          effectiveDir: _downloads.resolveEffectiveDownloadDir(),
          onSettingsChanged: _downloads.updateSettings,
        );
        if (!mounted || chosenQuality == null) return;
        quality = chosenQuality;
      }

      final added = _downloads.enqueueBatch(target, quality: quality);
      setState(() {
        for (final track in tracks) {
          _selection.remove(track.uniqueKey);
        }
      });
      snackyy(
        icon: Broken.document_download,
        message: added.length == 1
            ? '已加入下载队列（${LxDownloadSettings.qualityLabel(quality)}）'
            : '已加入下载队列（${added.length} 首 · ${LxDownloadSettings.qualityLabel(quality)}）',
        button: SnackbarButton(text: '查看下载', function: widget.onShowDownloads),
      );
    } catch (error) {
      if (mounted) snackyy(icon: Broken.info_circle, message: '加入下载队列失败：$error', isError: true);
    } finally {
      if (mounted) setState(() => _startingDownload = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _buildSearchControls(),
        if (_searching) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: SuperSmoothListView(
            key: const PageStorageKey('lx-search'),
            controller: widget.controller,
            padding: _listPadding,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (!LxBridgeService.isSupported)
                const _Notice(icon: Broken.info_circle, title: '在线曲库桥接仅支持 Android', isError: true)
              else
                ValueListenableBuilder<LxUserApiState>(
                  valueListenable: _bridge.userApiStateNotifier,
                  builder: (context, state, _) => state.status == LxUserApiStatus.ready
                      ? const SizedBox.shrink()
                      : _Notice(
                          icon: Broken.code_circle,
                          title: '尚未就绪自定义音源，下载前请先导入并启用音源',
                          action: NamidaButton(
                            text: '前往设置',
                            icon: Broken.setting_2,
                            dense: true,
                            onTap: () => const LxSettingsPage().navigate(),
                          ),
                        ),
                ),
              if (_mode == _SearchMode.playlists)
                const _PlaylistPreview()
              else ...[
                if (_searchError case final error?) _Notice(icon: Broken.info_circle, title: error, isError: true),
                if (_result case final result?)
                  ..._buildResults(result)
                else if (!_searching) ...[
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _keyword,
                    builder: (context, value, _) {
                      final pending = value.text.trim();
                      if (pending.isEmpty || !LxBridgeService.isSupported) return const SizedBox.shrink();
                      return _Notice(
                        icon: Broken.search_normal_1,
                        title: '在 ${_platform.label} 搜索「$pending」',
                        action: NamidaButton(
                          text: '立即搜索',
                          icon: Broken.search_normal_1,
                          dense: true,
                          enabled: !_savingHistory,
                          onTap: () => _search(pending),
                        ),
                      );
                    },
                  ),
                  if (_history.isNotEmpty) _buildHistory(),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchControls() {
    final canSearch = LxBridgeService.isSupported && !_searching && !_savingHistory && _mode == _SearchMode.songs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: NContainer(
                  decoration: (colors) => BoxDecoration(
                    color: colors.cardTheme,
                    borderRadius: BorderRadius.circular(14.0.multipliedRadius),
                    border: Border.all(color: colors.onSurface.withOpacityExt(0.09)),
                  ),
                  child: Row(
                    children: [
                      NamidaIconButton(
                        icon: Broken.search_normal_1,
                        iconSize: 18,
                        padding: const EdgeInsets.all(10),
                        tooltip: () => '搜索',
                        onPressed: canSearch ? () => _search(_keyword.text) : null,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _keyword,
                          enabled: canSearch,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _search,
                          style: NText.medium.of(context),
                          decoration: InputDecoration(
                            hintText: _mode == _SearchMode.songs ? '搜索歌曲或歌手' : '搜索歌单',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _keyword,
                        builder: (context, value, _) => value.text.isEmpty
                            ? const SizedBox(width: 8)
                            : NamidaIconButton(
                                icon: Broken.close_circle,
                                iconSize: 17,
                                padding: const EdgeInsets.all(9),
                                tooltip: () => '清空关键词',
                                onPressed: canSearch
                                    ? () {
                                        _keyword.clear();
                                        setState(() {
                                          _selection.clear();
                                          _result = null;
                                          _searchError = null;
                                        });
                                      }
                                    : null,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _PillGroup(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final mode in _SearchMode.values)
                      _Pill(
                        label: mode.label,
                        selected: _mode == mode,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          if (_mode != mode && widget.controller.hasClients) widget.controller.jumpTo(0);
                          setState(() => _mode = mode);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SmoothSingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final platform in LxPlatform.values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: _Pill(
                        label: platform.label,
                        selected: _platform == platform,
                        onTap: _searching ? null : () => _selectPlatform(platform),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(child: NamidaText('最近搜索', style: NText.medium)),
          NamidaButton(
            text: '清空',
            dense: true,
            enabled: !_savingHistory,
            onTap: () => _saveHistory(const []),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final query in _history)
            _Pill(
              label: query,
              onTap: _savingHistory
                  ? null
                  : () {
                      _keyword.text = query;
                      _search(query);
                    },
            ),
        ],
      ),
    ],
  );

  List<Widget> _buildResults(LxSearchResult result) {
    final tracks = result.tracks;
    final allSelected = tracks.isNotEmpty && tracks.every((track) => _selection.containsKey(track.uniqueKey));
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            NamidaText('共 ${result.total} 首', style: NText.medium),
            if (tracks.isNotEmpty || _multiSelect)
              NamidaButton(text: _multiSelect ? '退出多选' : '多选', dense: true, onTap: _toggleMultiSelect),
            if (_multiSelect) ...[
              NamidaButton(
                text: allSelected ? '取消全选' : '全选本页',
                dense: true,
                enabled: tracks.isNotEmpty,
                onTap: () => setState(() {
                  for (final track in tracks) {
                    if (allSelected) {
                      _selection.remove(track.uniqueKey);
                    } else {
                      _selection[track.uniqueKey] = track;
                    }
                  }
                }),
              ),
              NamidaButton(
                text: '下载已选 (${_selection.length})',
                dense: true,
                enabled: _selection.isNotEmpty && !_startingDownload,
                onTap: () => _startDownload(_selection.values.toList(), forceQualityDialog: false),
              ),
            ],
          ],
        ),
      ),
      if (tracks.isEmpty) const _Notice(icon: Broken.search_normal_1, title: '未找到歌曲'),
      AnimatedBuilder(
        animation: _trackChanges,
        builder: (context, _) => Column(children: [for (final track in tracks) _buildTrack(track)]),
      ),
      if (result.allPage > 1)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            children: [
              NamidaButton(
                text: '上一页',
                dense: true,
                enabled: !_searching && result.page > 1,
                onTap: () => _search(_lastQuery, page: result.page - 1),
              ),
              NamidaText('${result.page} / ${result.allPage}', style: NText.small),
              NamidaButton(
                text: '下一页',
                dense: true,
                enabled: !_searching && result.page < result.allPage,
                onTap: () => _search(_lastQuery, page: result.page + 1),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _buildTrack(LxTrack track) {
    final task = _downloads.latestTaskForTrack(track);
    void download() => _startDownload([track], forceQualityDialog: false);
    void chooseQuality() => _startDownload([track], forceQualityDialog: true);
    return LxTrackTile(
      key: ValueKey(track.uniqueKey),
      track: track,
      task: task,
      existsOnDisk: _downloads.cachedExistingAudioPath(track) != null,
      multiSelect: _multiSelect,
      selected: _selection.containsKey(track.uniqueKey),
      onDownload: download,
      onChooseQualityDownload: chooseQuality,
      onShowDetails: () => LxLyricsSheet.show(
        track: track,
        playableTrack: task?.stage == LxDownloadStage.completed ? task?.indexedTrack : null,
        onDownload: download,
        onChooseQualityDownload: chooseQuality,
        onPlay: _playTrack,
      ),
      onToggleMultiSelect: _toggleMultiSelect,
      onToggleSelected: () => _toggleSelected(track),
      onLongPressSelect: () => setState(() {
        _multiSelect = true;
        _selection[track.uniqueKey] = track;
      }),
      onOpenDownloads: widget.onShowDownloads,
      onPlay: _playTrack,
    );
  }
}

class _PlaylistPreview extends StatelessWidget {
  const _PlaylistPreview();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const _Notice(
        icon: Broken.music_playlist,
        title: '歌单搜索即将上线',
        subtitle: 'Stage 4 将接入五平台歌单搜索、歌单详情与整张歌单批量下载。当前页面已预留布局槽位。',
      ),
      const SizedBox(height: 6),
      ExcludeSemantics(
        child: GridView.builder(
          shrinkWrap: true,
          primary: false,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.78,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: NContainer(
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: _pillDecoration,
                  child: NIcon(Broken.music_playlist, size: 28, color: NColors.disabled),
                ),
              ),
              const SizedBox(height: 7),
              const FractionallySizedBox(
                widthFactor: 0.68,
                child: NContainer(height: 6, decoration: _pillDecoration),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _DownloadsSection extends StatelessWidget {
  const _DownloadsSection({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final downloads = LxDownloadManager.inst;
    return ValueListenableBuilder<List<LxDownloadTask>>(
      valueListenable: downloads.tasksNotifier,
      builder: (context, tasks, _) => ValueListenableBuilder<LxDownloadSettings>(
        valueListenable: downloads.settingsNotifier,
        builder: (context, settings, _) => SuperSmoothListView.builder(
          key: const PageStorageKey('lx-downloads'),
          controller: controller,
          padding: _listPadding,
          itemCount: tasks.isEmpty ? 2 : tasks.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    NamidaText('下载任务 (${tasks.length})', style: NText.medium),
                    _Pill(label: '并行 ${settings.maxConcurrent}'),
                    NamidaButton(
                      text: '清理已完成',
                      dense: true,
                      enabled: tasks.any((task) => !task.isActive),
                      onTap: downloads.clearFinished,
                    ),
                  ],
                ),
              );
            }
            if (tasks.isEmpty) {
              return const _Notice(
                icon: Broken.document_download,
                title: '暂无下载任务',
                subtitle: '在搜索页选择歌曲即可加入下载队列',
              );
            }
            final task = tasks[index - 1];
            return Padding(
              key: ValueKey(task.id),
              padding: const EdgeInsets.only(bottom: 8),
              child: LxDownloadTaskCard(
                task: task,
                onPlay: _playTrack,
                onLocateInLibrary: MainPageFABResumeButton.jumpToTrackInTracksPage,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PillGroup extends StatelessWidget {
  const _PillGroup({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => NDecoratedBox(
    decoration: _pillDecoration,
    child: Padding(padding: const EdgeInsets.all(3), child: child),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.icon, this.selected = false, this.count = 0, this.onTap});

  final String label;
  final IconData? icon;
  final bool selected;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = NColorsData.of(context);
    final foreground = selected ? NColors.primary : null;
    return Semantics(
      button: onTap != null,
      selected: onTap == null ? null : selected,
      child: NamidaInkWell(
        onTap: onTap,
        borderRadius: 10,
        animationDurationMS: 160,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        bgColor: NColors.fixed(selected ? colors.primary.withOpacityExt(0.16) : colors.cardTheme),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              NIcon(icon, size: 16, color: foreground),
              const SizedBox(width: 5),
            ],
            Flexible(child: NamidaText(label, style: NText.small, color: foreground, maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (count > 0)
              NContainer(
                margin: const EdgeInsetsDirectional.only(start: 5),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: (colors) => BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                ),
                child: NamidaText('$count', style: const NText(.small, size: .s10), color: NColors.onSecondaryContainer),
              ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, this.subtitle, this.action, this.isError = false});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return NContainer(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: (colors) => BoxDecoration(
        color: isError ? colors.error.withOpacityExt(0.09) : colors.cardTheme,
        borderRadius: BorderRadius.circular(14.0.multipliedRadius),
      ),
      child: Row(
        children: [
          NIcon(icon, size: 22, color: isError ? NColors.error : NColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NamidaText(title, style: NText.medium, color: isError ? NColors.error : null),
                if (subtitle != null) NamidaText(subtitle, style: NText.small),
              ],
            ),
          ),
          if (action case final action?) ...[const SizedBox(width: 8), action],
        ],
      ),
    );
  }
}
