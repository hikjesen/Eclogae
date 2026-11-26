import 'package:flutter/material.dart';

import 'package:eclogae/class/route.dart';
import 'package:eclogae/class/track.dart';
import 'package:eclogae/controller/navigator_controller.dart';
import 'package:eclogae/controller/player_controller.dart';
import 'package:eclogae/core/dimensions.dart';
import 'package:eclogae/core/enums.dart';
import 'package:eclogae/core/extensions.dart';
import 'package:eclogae/core/icon_fonts/broken_icons.dart';
import 'package:eclogae/core/ntheme.dart';
import 'package:eclogae/core/utils.dart';
import 'package:eclogae/ui/widgets/custom_widgets.dart';

import 'lx_bridge_service.dart';
import 'lx_download_manager.dart';
import 'lx_models.dart';
import 'lx_preview_player.dart';
import 'lx_settings_page.dart';
import 'widgets/lx_cover_thumb.dart';
import 'widgets/lx_download_actions.dart';
import 'widgets/lx_lyrics_sheet.dart';
import 'widgets/lx_track_tile.dart';

class LxSonglistDetailPage extends StatefulWidget with NamidaRouteWidget {
  const LxSonglistDetailPage({super.key, required this.songlist, this.onOpenDownloads});

  final LxSonglist songlist;
  final VoidCallback? onOpenDownloads;

  @override
  RouteType get route => RouteType.YOUTUBE_HOME_SECTION;

  @override
  String? get name => songlist.name;

  @override
  State<LxSonglistDetailPage> createState() => _LxSonglistDetailPageState();
}

class _LxSonglistDetailPageState extends State<LxSonglistDetailPage> {
  final _preview = LxPreviewPlayer.inst;
  final _downloads = LxDownloadManager.inst;
  final _selected = <String>{};
  late final _trackChanges = Listenable.merge([_downloads.tasksNotifier, _downloads.existingFilesVersion]);
  late LxSonglist _info = widget.songlist;
  List<LxTrack> _tracks = const [];
  int _page = 0;
  int? _total;
  int _requestId = 0;
  int _failedPage = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _descExpanded = false;
  bool _multiSelect = false;
  bool _fetchingAll = false;
  bool _downloadingAll = false;
  bool _downloadingSelected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPage(1);
  }

  Future<void> _loadPage(int page) async {
    final first = page == 1;
    if (_fetchingAll || _loading || (!first && (_loadingMore || !_hasMore))) return;
    final request = ++_requestId;
    setState(() {
      _loading = first;
      _loadingMore = !first;
      _error = null;
    });
    try {
      final detail = await LxBridgeService.inst.getSonglistDetail(
        platform: widget.songlist.source,
        id: widget.songlist.id,
        page: page,
        fallbackInfo: _info,
      );
      if (!mounted || request != _requestId) return;
      final seen = <String>{};
      setState(() {
        _info = detail.info;
        _tracks = [
          for (final track in [if (!first) ..._tracks, ...detail.tracks])
            if (seen.add(track.uniqueKey)) track,
        ];
        if (first) _selected.retainAll(seen);
        _page = detail.page;
        _total = detail.total;
        _hasMore = detail.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _failedPage = page;
        _error = '获取歌单曲目失败：$error';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  VoidCallback get _openDownloads => widget.onOpenDownloads ?? LxSettingsPage.openDownloads;

  bool get _canDownloadAll => _tracks.isNotEmpty && !_loading && !_loadingMore && !_fetchingAll && !_downloadingAll && !_downloadingSelected;
  bool get _canDownloadSelected => _selected.isNotEmpty && !_fetchingAll && !_downloadingAll && !_downloadingSelected;

  Future<void> _downloadAll() async {
    if (!_canDownloadAll) return;
    setState(() {
      _fetchingAll = _hasMore;
      _downloadingAll = !_hasMore;
      if (_fetchingAll) _error = null;
    });
    try {
      if (_fetchingAll) {
        if (!await _fetchRemainingTracks() || !mounted) return;
        setState(() {
          _fetchingAll = false;
          _downloadingAll = true;
        });
      }
      await LxDownloadActions.downloadTracks(_tracks, subfolderName: _info.name, onOpenDownloads: _openDownloads);
    } finally {
      if (mounted) {
        setState(() {
          _fetchingAll = false;
          _downloadingAll = false;
        });
      }
    }
  }

  Future<bool> _fetchRemainingTracks() async {
    final request = ++_requestId;
    final navigator = NamidaNavigator.inst;
    final progress = ValueNotifier<({int loaded, int? total})>((loaded: _tracks.length, total: _total ?? _info.total));
    var canceled = false;
    var dialogOpen = true;

    bool isActive() => mounted && request == _requestId && !canceled;

    void closeProgressDialog({bool cancel = false}) {
      if (!dialogOpen) return;
      dialogOpen = false;
      canceled = cancel;
      navigator.closeDialog();
    }

    final dialogClosed = navigator
        .navigateDialog<void>(
          // The navigator uses the same callback for Back and barrier taps. The full-size tap detector handles barrier taps here.
          tapToDismiss: () {
            closeProgressDialog(cancel: true);
            return false;
          },
          scale: 1,
          dialog: TapDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: CustomBlurryDialog(
              normalTitleStyle: true,
              title: '正在拉取歌单曲目',
              icon: Broken.document_download,
              actions: [NamidaButton(text: '取消', dense: true, onTap: () => closeProgressDialog(cancel: true))],
              child: ValueListenableBuilder<({int loaded, int? total})>(
                valueListenable: progress,
                builder: (context, value, _) {
                  final (:loaded, :total) = value;
                  final fraction = total != null && total > 0 ? (loaded / total).clamp(0.0, 1.0).toDouble() : null;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NamidaText(fraction == null ? '已加载 $loaded 首' : '已加载 $loaded / $total 首', style: NText.small),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: fraction),
                    ],
                  );
                },
              ),
            ),
          ),
        )
        .whenComplete(() {
          if (dialogOpen) canceled = true;
          dialogOpen = false;
        });

    final seen = _tracks.map((track) => track.uniqueKey).toSet();
    Object? fetchError;
    try {
      while (_hasMore && !canceled) {
        final detail = await LxBridgeService.inst.getSonglistDetail(
          platform: widget.songlist.source,
          id: widget.songlist.id,
          page: _page + 1,
          fallbackInfo: _info,
        );
        if (!isActive()) return false;
        final added = detail.tracks.where((track) => seen.add(track.uniqueKey)).toList();
        setState(() {
          _info = detail.info;
          _tracks = [..._tracks, ...added];
          _page = detail.page;
          _total = detail.total;
          _hasMore = added.isNotEmpty && detail.hasMore;
        });
        progress.value = (loaded: _tracks.length, total: _total);
      }
    } catch (error) {
      fetchError = error;
    } finally {
      closeProgressDialog();
      await dialogClosed.whenComplete(progress.dispose);
    }
    if (!isActive()) return false;
    if (fetchError != null) {
      snackyy(icon: Broken.info_circle, message: '拉取歌单剩余曲目失败：$fetchError', isError: true);
      return false;
    }
    return true;
  }

  void _toggleMultiSelect() => setState(() {
    _multiSelect = !_multiSelect;
    if (!_multiSelect) _selected.clear();
  });

  void _toggleSelected(LxTrack track) => setState(() {
    final key = track.uniqueKey;
    if (!_selected.add(key)) _selected.remove(key);
  });

  Future<void> _downloadSelected() async {
    if (!_canDownloadSelected) return;
    final selected = _tracks.where((track) => _selected.contains(track.uniqueKey)).toList();
    setState(() => _downloadingSelected = true);
    final added = await LxDownloadActions.downloadTracks(selected, subfolderName: _info.name, onOpenDownloads: _openDownloads);
    if (!mounted) return;
    setState(() {
      _downloadingSelected = false;
      if (added) _selected.removeAll(selected.map((track) => track.uniqueKey));
    });
  }

  @override
  Widget build(BuildContext context) => BackgroundWrapper(
    child: NDecoratedBox(
      decoration: (colors) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [(colors.accent ?? colors.primary).withOpacityExt(0.10), Colors.transparent],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: () => _loadPage(1),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.depth != 0) return false;
            final scrollingTowardEnd = switch (notification) {
              ScrollUpdateNotification(:final scrollDelta) => (scrollDelta ?? 0) > 0,
              OverscrollNotification(:final overscroll) => overscroll > 0,
              _ => false,
            };
            if (scrollingTowardEnd && notification.metrics.extentAfter <= 280 && _error == null) {
              _loadPage(_page + 1);
            }
            return false;
          },
          child: CustomScrollView(
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                sliver: SliverToBoxAdapter(child: _buildHeader()),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverList.builder(itemCount: _tracks.length, itemBuilder: (context, index) => _buildTrack(index)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, Dimensions.globalBottomPaddingTotal),
                sliver: SliverToBoxAdapter(child: _buildFooter()),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildHeader() {
    final available = _tracks.isNotEmpty;
    final allSelected = available && _selected.length == _tracks.length;
    final total = _total ?? _info.total;
    final counts = [
      if (_info.playCount.isNotEmpty) '播放 ${_info.playCount}',
      if (total != null) '共 $total 首' else if (available) '已加载 ${_tracks.length} 首',
    ].join(' · ');
    return NContainer(
      padding: const EdgeInsets.all(12),
      decoration: (colors) => BoxDecoration(
        color: colors.cardTheme,
        borderRadius: BorderRadius.circular(14.0.multipliedRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LxCoverThumb(url: _info.img, size: 96, borderRadius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NamidaText(_info.name, style: NText.medium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        NContainer(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: (colors) => BoxDecoration(
                            color: colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                          ),
                          child: NamidaText(_info.source.label, style: const NText(.small, size: .s10), color: NColors.onSecondaryContainer),
                        ),
                        if (_info.author.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(child: NamidaText(_info.author, style: NText.small, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ],
                    ),
                    if (counts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      NamidaText(counts, style: NText.small, color: const NColors(.onSurface, opacity: 0.65)),
                    ],
                    if (_info.desc.isNotEmpty)
                      Semantics(
                        button: true,
                        expanded: _descExpanded,
                        child: NamidaInkWell(
                          onTap: () => setState(() => _descExpanded = !_descExpanded),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: NamidaText(
                            _info.desc,
                            style: NText.small,
                            color: const NColors(.onSurface, opacity: 0.72),
                            maxLines: _descExpanded ? null : 2,
                            overflow: _descExpanded ? null : TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              NamidaButton(
                text: '播放全部',
                icon: Broken.play,
                dense: true,
                enabled: available,
                onTap: () => _preview.playQueue(_tracks, initialIndex: 0, sourceTitle: _info.name),
              ),
              NamidaButton(
                text: '下载全部',
                icon: Broken.document_download,
                dense: true,
                enabled: _canDownloadAll,
                onTap: _downloadAll,
              ),
              NamidaButton(
                text: '多选',
                icon: Broken.tick_square,
                dense: true,
                colors: _multiSelect ? NamidaButtonColors.selected : NamidaButtonColors.dimmed,
                enabled: available || _multiSelect,
                onTap: _toggleMultiSelect,
              ),
            ],
          ),
          if (_multiSelect)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  NamidaText('已选 ${_selected.length} 首', style: NText.small),
                  NamidaButton(
                    text: allSelected ? '取消全选' : '全选',
                    dense: true,
                    enabled: available,
                    onTap: () => setState(() {
                      if (allSelected) {
                        _selected.clear();
                      } else {
                        _selected.addAll(_tracks.map((track) => track.uniqueKey));
                      }
                    }),
                  ),
                  NamidaButton(text: '下载所选', dense: true, enabled: _canDownloadSelected, onTap: _downloadSelected),
                  NamidaButton(text: '取消', dense: true, onTap: _toggleMultiSelect),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrack(int index) {
    final track = _tracks[index];
    void download() => LxDownloadActions.downloadTracks([track], subfolderName: _info.name, onOpenDownloads: _openDownloads);
    void chooseQuality() => LxDownloadActions.downloadTracks([track], forceDialog: true, subfolderName: _info.name, onOpenDownloads: _openDownloads);
    return AnimatedBuilder(
      key: ValueKey(track.uniqueKey),
      animation: _trackChanges,
      builder: (context, _) => Obx((context) {
        final item = Player.inst.currentItem.valueR;
        return LxTrackTile(
          track: track,
          index: index + 1,
          task: _downloads.latestTaskForTrack(track),
          existsOnDisk: _downloads.cachedExistingAudioPath(track) != null,
          isPlaying: item is Selectable && item.track.path == LxPreviewPlayer.previewPathFor(track),
          multiSelect: _multiSelect,
          selected: _selected.contains(track.uniqueKey),
          onPreviewPlay: () => _preview.playQueue(_tracks, initialIndex: index, sourceTitle: _info.name),
          onPlayNext: () => _preview.playNext(track),
          onDownload: download,
          onChooseQualityDownload: chooseQuality,
          onShowDetails: () => LxLyricsSheet.show(track: track, onDownload: download, onChooseQualityDownload: chooseQuality),
          onToggleMultiSelect: _toggleMultiSelect,
          onToggleSelected: () => _toggleSelected(track),
          onLongPressSelect: () => setState(() {
            _multiSelect = true;
            _selected.add(track.uniqueKey);
          }),
          onOpenDownloads: _openDownloads,
        );
      }),
    );
  }

  Widget _buildFooter() {
    final error = _error;
    final Widget content;
    if (_loading || _loadingMore) {
      content = const CircularProgressIndicator(semanticsLabel: '正在加载歌单');
    } else if (error != null) {
      content = Column(
        children: [
          NamidaText(error, style: NText.small, color: NColors.error, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          NamidaButton(text: '重试', icon: Broken.refresh, dense: true, onTap: () => _loadPage(_failedPage)),
        ],
      );
    } else if (_hasMore) {
      content = NamidaButton(text: '加载更多', dense: true, onTap: () => _loadPage(_page + 1));
    } else {
      content = NamidaText(
        _tracks.isEmpty ? '此歌单暂无歌曲' : '已加载全部',
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
