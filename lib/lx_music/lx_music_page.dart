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
import 'package:namida/core/utils.dart';
import 'package:namida/ui/pages/main_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

import 'lx_bridge_service.dart';
import 'lx_download_manager.dart';
import 'lx_models.dart';
import 'lx_preview_player.dart';
import 'lx_search_controller.dart';
import 'lx_settings_page.dart';
import 'lx_songlist_detail_page.dart';
import 'widgets/lx_download_actions.dart';
import 'widgets/lx_download_task_card.dart';
import 'widgets/lx_lyrics_sheet.dart';
import 'widgets/lx_songlist_card.dart';
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
  final _searchScroll = NamidaScrollController.create(keepScrollOffset: false);
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

class _SearchSection extends StatefulWidget {
  const _SearchSection({required this.controller, required this.onShowDownloads});

  final ScrollController controller;
  final VoidCallback onShowDownloads;

  @override
  State<_SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends State<_SearchSection> with AutomaticKeepAliveClientMixin<_SearchSection> {
  final _search = LxSearchController.inst;
  final _downloads = LxDownloadManager.inst;
  final _preview = LxPreviewPlayer.inst;
  final _focusNode = FocusNode();
  final _selected = <String>{};
  late final TextEditingController _keyword;
  late final _trackChanges = Listenable.merge([_downloads.tasksNotifier, _downloads.existingFilesVersion]);
  late (LxSearchMode, LxSearchSource, String) _scrollKey;
  double? _pendingOffset;
  bool _retryLoadMore = false;
  bool _multiSelect = false;
  bool _downloadingSelected = false;

  (LxSearchMode, LxSearchSource, String) get _searchContext => (_search.mode, _search.source, _search.submittedKeyword);
  bool get _showSongs => _search.mode == LxSearchMode.songs;
  LxPagedState<Object> get _result => _showSongs ? _search.songState : _search.songlistState;
  double get _savedOffset => _showSongs ? _search.songsScrollOffset : _search.songlistsScrollOffset;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _keyword = TextEditingController(text: _search.inputText);
    _scrollKey = _searchContext;
    _pendingOffset = _savedOffset;
    _search.addListener(_onSearchChanged);
    _focusNode.addListener(_onFocusChanged);
    _restoreScroll();
    _runHistoryAction(_search.ensureHistoryLoaded);
  }

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _focusNode.dispose();
    _keyword.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final input = _search.inputText;
    if (_keyword.text != input) {
      _keyword.value = TextEditingValue(text: input, selection: TextSelection.collapsed(offset: input.length));
    }
    final searchContext = _searchContext;
    final result = _result;
    setState(() {
      if (_scrollKey != searchContext) {
        _scrollKey = searchContext;
        _pendingOffset = _savedOffset;
        _multiSelect = false;
        _selected.clear();
        _retryLoadMore = false;
      }
      if (result.loading || result.loadingMore) _retryLoadMore = result.loadingMore;
      if (_selected.isNotEmpty && !result.loading) _selected.retainAll(_search.songState.items.map((track) => track.uniqueKey));
    });
    _restoreScroll();
  }

  void _restoreScroll() {
    final offset = _pendingOffset;
    if (offset == null || (_result.loading && _result.items.isEmpty)) return;
    final key = _scrollKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scrollKey != key || _pendingOffset == null) return;
      final controller = widget.controller;
      if (!controller.hasClients) return;
      if (offset > 0) controller.jumpTo(offset.clamp(0.0, controller.position.maxScrollExtent).toDouble());
      _pendingOffset = null;
    });
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      setState(() {});
    } else {
      _search.setTipsVisible(false);
    }
  }

  void _dismissTips() {
    _focusNode.unfocus();
    _search.setTipsVisible(false);
  }

  Future<void> _runHistoryAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) snackyy(icon: Broken.info_circle, message: '搜索历史读写失败：$error', isError: true);
    }
  }

  void _submit(String keyword) {
    _dismissTips();
    _runHistoryAction(() => _search.submitSearch(keyword));
  }

  void _setSource(LxSearchSource source) {
    _dismissTips();
    if (source == _search.source) return;
    _search.songsScrollOffset = 0;
    _search.songlistsScrollOffset = 0;
    _search.setSource(source);
  }

  void _toggleMultiSelect() => setState(() {
    _multiSelect = !_multiSelect;
    if (!_multiSelect) _selected.clear();
  });

  Future<void> _downloadSelected() async {
    final key = _scrollKey;
    final tracks = _search.songState.items.where((track) => _selected.contains(track.uniqueKey)).toList();
    setState(() => _downloadingSelected = true);
    final added = await LxDownloadActions.downloadTracks(tracks, onOpenDownloads: widget.onShowDownloads);
    if (!mounted) return;
    setState(() {
      _downloadingSelected = false;
      if (added && key == _scrollKey) _selected.removeAll(tracks.map((track) => track.uniqueKey));
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = NColorsData.of(context);
    final result = _result;
    return Column(
      children: [
        _buildSearchBar(colors),
        _buildModeBar(result),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: [
                _buildResults(result, constraints.maxWidth >= 600 ? 4 : 3),
                if (_focusNode.hasFocus && _search.tipsVisible && _search.tips.isNotEmpty) ...[
                  ModalBarrier(
                    color: colors.onSurface.withOpacityExt(0.08),
                    dismissible: true,
                    onDismiss: _dismissTips,
                    semanticsLabel: '关闭搜索建议',
                  ),
                  PositionedDirectional(
                    top: 0,
                    start: 12,
                    end: 12,
                    child: TextFieldTapRegion(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: (constraints.maxHeight - MediaQuery.viewInsetsOf(context).bottom).clamp(0.0, 280.0).toDouble(),
                        ),
                        child: _TipList(tips: _search.tips, onTap: _submit),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(NColorsData colors) => NContainer(
    margin: const EdgeInsets.symmetric(horizontal: 12),
    clipBehavior: Clip.antiAlias,
    decoration: (_) => BoxDecoration(
      color: colors.cardTheme,
      borderRadius: BorderRadius.circular(14.0.multipliedRadius),
    ),
    child: Row(
      children: [
        NamidaPopupWrapper(
          childrenDefault: () => [
            for (final source in LxSearchSource.values)
              NamidaPopupItem(
                icon: _search.source == source ? Broken.tick_circle : Broken.musicnote,
                title: source.label,
                onTap: () => _setSource(source),
              ),
          ],
          childBuilder: (openMenu) => Semantics(
            label: '选择搜索来源',
            button: true,
            child: NamidaInkWell(
              onTap: openMenu,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NamidaText(_search.source.label, style: NText.small),
                  const SizedBox(width: 4),
                  const NIcon(Broken.arrow_down_2, size: 14),
                ],
              ),
            ),
          ),
        ),
        Container(width: 1, height: 18, color: colors.onSurface.withOpacityExt(0.14)),
        Expanded(
          child: TextField(
            focusNode: _focusNode,
            controller: _keyword,
            textInputAction: TextInputAction.search,
            onChanged: _search.onInputChanged,
            onSubmitted: _submit,
            onTap: () => _search.setTipsVisible(true),
            style: NText.medium.of(context),
            decoration: InputDecoration(
              hintText: _showSongs ? '搜索歌曲、歌手或专辑' : '搜索歌单',
              hintMaxLines: 1,
              filled: false,
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
          ),
        ),
        if (_keyword.text.isNotEmpty)
          NamidaIconButton(
            icon: Broken.close_circle,
            iconSize: 17,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            tooltip: () => '清空关键词',
            onPressed: () {
              _keyword.clear();
              _search.onInputChanged('');
            },
          ),
        NamidaIconButton(
          icon: Broken.search_normal_1,
          iconSize: 19,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          tooltip: () => '搜索',
          onPressed: () => _submit(_keyword.text),
        ),
      ],
    ),
  );

  Widget _buildModeBar(LxPagedState<Object> result) {
    final tracks = _search.songState.items;
    final allSelected = tracks.isNotEmpty && tracks.every((track) => _selected.contains(track.uniqueKey));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _PillGroup(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in LxSearchMode.values)
                  _Pill(
                    label: mode.label,
                    selected: _search.mode == mode,
                    onTap: () {
                      _dismissTips();
                      _search.setMode(mode);
                    },
                  ),
              ],
            ),
          ),
          if (_multiSelect)
            Flexible(
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                runSpacing: 4,
                children: [
                  NamidaButton(
                    text: allSelected ? '取消全选' : '全选',
                    dense: true,
                    enabled: tracks.isNotEmpty,
                    onTap: () => setState(() {
                      if (allSelected) {
                        _selected.clear();
                      } else {
                        _selected.addAll(tracks.map((track) => track.uniqueKey));
                      }
                    }),
                  ),
                  NamidaButton(
                    text: '下载(${_selected.length})',
                    dense: true,
                    enabled: _selected.isNotEmpty && !_downloadingSelected,
                    onTap: _downloadSelected,
                  ),
                  NamidaButton(text: '取消', dense: true, onTap: _toggleMultiSelect),
                ],
              ),
            )
          else if (result.items.isNotEmpty)
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: NamidaText(
                      '共 ${result.total} ${_showSongs ? '首' : '张'}',
                      style: NText.small,
                      color: const NColors(.onSurface, opacity: 0.64),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_showSongs)
                    NamidaIconButton(
                      icon: Broken.tick_square,
                      iconSize: 18,
                      padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 4, 8),
                      tooltip: () => '多选批量下载',
                      onPressed: _toggleMultiSelect,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults(LxPagedState<Object> result, int columns) {
    final key = _scrollKey;
    final hasQuery = _search.submittedKeyword.isNotEmpty;
    final showSongs = _showSongs;
    final tracks = _search.songState.items;
    final songlists = _search.songlistState.items;
    final showSourceBadge = _search.source == LxSearchSource.all;
    return RefreshIndicator(
      onRefresh: _search.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth != 0 || key != _scrollKey) return false;
          if (notification is ScrollStartNotification && notification.dragDetails != null) _dismissTips();
          if (hasQuery && _pendingOffset == null) {
            final metrics = notification.metrics;
            if (notification is ScrollUpdateNotification) {
              final offset = metrics.pixels.clamp(0.0, metrics.maxScrollExtent).toDouble();
              if (showSongs) {
                _search.songsScrollOffset = offset;
              } else {
                _search.songlistsScrollOffset = offset;
              }
            }
            final scrollingTowardEnd = switch (notification) {
              ScrollUpdateNotification(:final scrollDelta) => (scrollDelta ?? 0) > 0,
              OverscrollNotification(:final overscroll) => overscroll > 0,
              _ => false,
            };
            if (scrollingTowardEnd && metrics.extentAfter <= 280 && result.error == null) {
              _search.loadMore();
            }
          }
          return false;
        },
        child: CustomScrollView(
          key: ValueKey(key),
          controller: widget.controller,
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            if (!hasQuery)
              SliverPadding(
                padding: _listPadding,
                sliver: SliverToBoxAdapter(child: _buildHistory()),
              )
            else ...[
              if (showSongs)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  sliver: SliverList.builder(
                    itemCount: tracks.length,
                    itemBuilder: (context, index) => _buildTrack(tracks[index], index + 1, showSourceBadge: showSourceBadge),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  sliver: SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: songlists.length,
                    itemBuilder: (context, index) {
                      final songlist = songlists[index];
                      return LxSonglistCard(
                        key: ValueKey(songlist.uniqueKey),
                        songlist: songlist,
                        showSourceBadge: showSourceBadge,
                        onTap: () => LxSonglistDetailPage(songlist: songlist, onOpenDownloads: widget.onShowDownloads).navigate(),
                      );
                    },
                  ),
                ),
              SliverPadding(
                padding: _listPadding,
                sliver: SliverToBoxAdapter(child: _buildFooter(result)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    final history = _search.history;
    if (history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NIcon(Broken.search_normal_1, size: 16, color: NColors.disabled),
            SizedBox(width: 6),
            Flexible(child: NamidaText('输入关键词搜索歌曲或歌单', style: NText.small, color: NColors.disabled)),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: NamidaText('最近搜索', style: NText.medium)),
            NamidaButton(text: '清空', dense: true, onTap: () => _runHistoryAction(_search.clearHistory)),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final keyword in history)
              InputChip(
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 224),
                  child: NamidaText(keyword, style: NText.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                onPressed: () => _submit(keyword),
                deleteButtonTooltipMessage: '移除搜索记录',
                onDeleted: () => _runHistoryAction(() => _search.removeHistory(keyword)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrack(LxTrack track, int index, {required bool showSourceBadge}) {
    void download() => LxDownloadActions.downloadTracks([track], onOpenDownloads: widget.onShowDownloads);
    void chooseQuality() => LxDownloadActions.downloadTracks([track], forceDialog: true, onOpenDownloads: widget.onShowDownloads);
    return AnimatedBuilder(
      key: ValueKey(track.uniqueKey),
      animation: _trackChanges,
      builder: (context, _) => Obx((context) {
        final item = Player.inst.currentItem.valueR;
        final task = _downloads.latestTaskForTrack(track);
        return LxTrackTile(
          track: track,
          index: index,
          task: task,
          existsOnDisk: _downloads.cachedExistingAudioPath(track) != null,
          showSourceBadge: showSourceBadge,
          isPlaying: item is Selectable && item.track.path == LxPreviewPlayer.previewPathFor(track),
          multiSelect: _multiSelect,
          selected: _selected.contains(track.uniqueKey),
          onPreviewPlay: () => _preview.playTrack(track),
          onPlayNext: () => _preview.playNext(track),
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
          onToggleSelected: () => setState(() {
            final key = track.uniqueKey;
            if (!_selected.add(key)) _selected.remove(key);
          }),
          onLongPressSelect: () => setState(() {
            _multiSelect = true;
            _selected.add(track.uniqueKey);
          }),
          onOpenDownloads: widget.onShowDownloads,
        );
      }),
    );
  }

  Widget _buildFooter(LxPagedState<Object> result) {
    final error = result.error;
    final Widget content;
    if (result.loading || result.loadingMore) {
      content = const CircularProgressIndicator(semanticsLabel: '正在搜索');
    } else if (error != null) {
      content = Column(
        children: [
          NamidaText('搜索失败：$error', style: NText.small, color: NColors.error, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          NamidaButton(text: '重试', icon: Broken.refresh, dense: true, onTap: _retryLoadMore ? _search.loadMore : _search.refresh),
        ],
      );
    } else if (result.hasMore) {
      content = NamidaButton(text: '加载更多', dense: true, onTap: _search.loadMore);
    } else {
      content = NamidaText(
        result.items.isEmpty ? (_showSongs ? '未找到歌曲' : '未找到歌单') : '已加载全部',
        style: NText.small,
        color: const NColors(.onSurface, opacity: 0.62),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(child: content),
    );
  }
}

class _TipList extends StatelessWidget {
  const _TipList({required this.tips, required this.onTap});

  final List<String> tips;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => NContainer(
    clipBehavior: Clip.antiAlias,
    decoration: (colors) => BoxDecoration(
      color: Color.alphaBlend(colors.cardTheme, colors.scaffold),
      border: Border.all(color: colors.onSurface.withOpacityExt(0.10)),
      borderRadius: BorderRadius.circular(14.0.multipliedRadius),
      boxShadow: [BoxShadow(color: colors.shadow.withOpacityExt(0.18), blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: ListView.builder(
      primary: false,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 3),
      itemCount: tips.length,
      itemBuilder: (context, index) {
        final tip = tips[index];
        return NamidaInkWell(
          onTap: () => onTap(tip),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              const NIcon(Broken.search_normal_1, size: 16),
              const SizedBox(width: 9),
              Expanded(child: NamidaText(tip, style: NText.medium, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
        );
      },
    ),
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
  const _Notice({required this.icon, required this.title, this.subtitle, this.isError = false});

  final IconData icon;
  final String title;
  final String? subtitle;
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
        ],
      ),
    );
  }
}
