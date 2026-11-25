import 'package:flutter/material.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

import '../lx_models.dart';
import 'lx_cover_thumb.dart';

class LxTrackTile extends StatelessWidget {
  const LxTrackTile({
    super.key,
    required this.track,
    required this.index,
    this.task,
    this.existsOnDisk = false,
    this.showSourceBadge = false,
    this.isPlaying = false,
    this.multiSelect = false,
    this.selected = false,
    required this.onPreviewPlay,
    required this.onPlayNext,
    required this.onDownload,
    required this.onChooseQualityDownload,
    required this.onShowDetails,
    required this.onToggleMultiSelect,
    required this.onToggleSelected,
    this.onLongPressSelect,
    this.onOpenDownloads,
  });

  final LxTrack track;
  final int index;
  final LxDownloadTask? task;
  final bool existsOnDisk;
  final bool showSourceBadge;
  final bool isPlaying;
  final bool multiSelect;
  final bool selected;
  final VoidCallback onPreviewPlay;
  final VoidCallback onPlayNext;
  final VoidCallback onDownload;
  final VoidCallback onChooseQualityDownload;
  final VoidCallback onShowDetails;
  final VoidCallback onToggleMultiSelect;
  final VoidCallback onToggleSelected;
  final VoidCallback? onLongPressSelect;
  final VoidCallback? onOpenDownloads;

  @override
  Widget build(BuildContext context) {
    final colors = NColorsData.of(context);
    final task = this.task;
    final activeTask = task != null && task.isActive ? task : null;
    final downloaded = task?.stage == LxDownloadStage.completed || existsOnDisk;
    final quality = track.highestQuality;
    final artistAlbum = [track.singer, track.albumName].where((part) => part.isNotEmpty).join(' · ');
    final progress = activeTask != null && activeTask.stage == LxDownloadStage.downloading ? activeTask.progress : null;
    final openDownloads = onOpenDownloads;

    return Semantics(
      selected: multiSelect ? selected : null,
      child: NamidaInkWell(
        onTap: multiSelect ? onToggleSelected : onPreviewPlay,
        onLongPress: multiSelect ? null : onLongPressSelect,
        borderRadius: 12.0,
        bgColor: NColors.fixed(
          selected ? colors.primary.withOpacityExt(0.11) : (isPlaying ? colors.primary.withOpacityExt(0.07) : null),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Center(
                child: multiSelect
                    ? Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: selected ? Colors.transparent : colors.onSurface.withOpacityExt(0.36)),
                        ),
                        child: selected ? const NIcon(Broken.tick_circle, size: 20, color: NColors.primary) : null,
                      )
                    : isPlaying
                    ? const NIcon(Broken.volume_high, size: 17, color: NColors.primary)
                    : Text(
                        '$index',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NText.small.of(context).copyWith(
                          fontSize: 12,
                          color: colors.onSurface.withOpacityExt(0.48),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NamidaText(
                    track.name,
                    style: NText.medium,
                    color: isPlaying ? NColors.primary : null,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (quality != null || showSourceBadge || artistAlbum.isNotEmpty)
                    Row(
                      children: [
                        if (quality != null) ...[
                          LxQualityBadge(quality: quality),
                          const SizedBox(width: 5),
                        ],
                        if (showSourceBadge) ...[
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.onSurface.withOpacityExt(0.05),
                              border: Border.all(color: colors.onSurface.withOpacityExt(0.10)),
                              borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              child: Text(track.source.label, style: NText.small.of(context).copyWith(fontSize: 9.5)),
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Expanded(child: NamidaText(artistAlbum, style: NText.small, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  if (activeTask != null)
                    NamidaText(
                      progress == null ? activeTask.stage.label : '${activeTask.stage.label} ${(progress * 100).round()}%',
                      style: const NText(.small, size: .s11),
                      color: NColors.primary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (track.interval.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 6),
                    child: NamidaText(track.interval, style: const NText(.small, size: .s11), color: const NColors(.onSurface, opacity: 0.64)),
                  ),
                if (!multiSelect) ...[
                  NamidaIconButton(
                    icon: activeTask != null ? null : (downloaded ? Broken.tick_circle : Broken.document_download),
                    iconSize: 20,
                    iconColor: downloaded ? NColors.primary : null,
                    padding: const EdgeInsets.all(12),
                    onPressed: onDownload,
                    onLongPress: onChooseQualityDownload,
                    tooltip: () => activeTask?.stage.label ?? (downloaded ? '已下载（长按重选音质）' : '下载（长按选音质）'),
                    child: activeTask == null
                        ? null
                        : SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(value: progress, strokeWidth: 2, color: colors.primary),
                          ),
                  ),
                  NamidaPopupWrapper(
                    childrenDefault: () => [
                      NamidaPopupItem(icon: Broken.play, title: '试听播放', onTap: onPreviewPlay),
                      NamidaPopupItem(icon: Broken.clock, title: '下一首试听', onTap: onPlayNext),
                      NamidaPopupItem(icon: Broken.document_download, title: '下载', hasDividerAbove: true, onTap: onDownload),
                      NamidaPopupItem(icon: Broken.slider_horizontal, title: '选择音质下载', onTap: onChooseQualityDownload),
                      NamidaPopupItem(icon: Broken.message_text, title: '查看歌词与详情', onTap: onShowDetails),
                      NamidaPopupItem(icon: Broken.tick_square, title: '多选批量下载', onTap: onToggleMultiSelect),
                      if (activeTask != null && openDownloads != null)
                        NamidaPopupItem(icon: Broken.document_download, title: '查看下载', onTap: openDownloads),
                    ],
                    child: Semantics(
                      label: '更多操作',
                      button: true,
                      child: const SizedBox(width: 36, height: 44, child: Center(child: MoreIcon(iconSize: 18))),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
