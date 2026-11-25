import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
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
    this.task,
    this.existsOnDisk = false,
    this.multiSelect = false,
    this.selected = false,
    required this.onDownload,
    required this.onChooseQualityDownload,
    required this.onShowDetails,
    required this.onToggleMultiSelect,
    required this.onToggleSelected,
    this.onLongPressSelect,
    this.onOpenDownloads,
    this.onPlay,
  });

  final LxTrack track;
  final LxDownloadTask? task;
  final bool existsOnDisk;
  final bool multiSelect;
  final bool selected;
  final VoidCallback onDownload;
  final VoidCallback onChooseQualityDownload;
  final VoidCallback onShowDetails;
  final VoidCallback onToggleMultiSelect;
  final VoidCallback onToggleSelected;
  final VoidCallback? onLongPressSelect;
  final VoidCallback? onOpenDownloads;
  final void Function(Track track)? onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = NColorsData.of(context);
    final task = this.task;
    final activeTask = task != null && task.isActive ? task : null;
    final completed = task?.stage == LxDownloadStage.completed;
    final playableTrack = completed ? task?.indexedTrack : null;
    final play = onPlay;
    final quality = track.highestQuality;
    final artistAlbum = [track.singer, track.albumName].where((part) => part.isNotEmpty).join(' · ');
    final progress = activeTask != null && activeTask.stage == LxDownloadStage.downloading ? activeTask.progress : null;

    return Semantics(
      selected: multiSelect ? selected : null,
      child: NamidaInkWell(
        onTap: multiSelect ? onToggleSelected : onShowDetails,
        onLongPress: multiSelect ? null : onLongPressSelect,
        borderRadius: 12.0,
        bgColor: NColors.fixed(selected ? colors.primary.withOpacityExt(0.11) : null),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            if (multiSelect)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? Colors.transparent : colors.onSurface.withOpacityExt(0.36)),
                  ),
                  child: selected ? const NIcon(Broken.tick_circle, size: 20, color: NColors.primary) : null,
                ),
              ),
            LxCoverThumb(url: track.picUrl),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NamidaText(track.name, style: NText.medium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (quality != null || artistAlbum.isNotEmpty)
                    Row(
                      children: [
                        if (quality != null) ...[
                          LxQualityBadge(quality: quality),
                          const SizedBox(width: 6),
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
                  if (activeTask != null)
                    NamidaIconButton(
                      icon: null,
                      padding: const EdgeInsets.all(11),
                      onPressed: onOpenDownloads,
                      tooltip: () => activeTask.stage.label,
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(value: progress, strokeWidth: 2.2, color: colors.primary),
                      ),
                    )
                  else
                    NamidaIconButton(
                      icon: completed || existsOnDisk ? Broken.tick_circle : Broken.document_download,
                      iconSize: 20,
                      iconColor: completed || existsOnDisk ? NColors.primary : null,
                      padding: const EdgeInsets.all(12),
                      onPressed: onDownload,
                      onLongPress: onChooseQualityDownload,
                      tooltip: () => completed || existsOnDisk ? '已下载（长按重选音质）' : '下载（长按选音质）',
                    ),
                  NamidaPopupWrapper(
                    child: Semantics(label: '更多操作', button: true, child: const Padding(padding: EdgeInsets.all(6), child: MoreIcon(iconSize: 18))),
                    childrenDefault: () => [
                      if (playableTrack != null && play != null)
                        NamidaPopupItem(icon: Broken.play, title: '立即播放', onTap: () => play(playableTrack)),
                      NamidaPopupItem(icon: Broken.document_download, title: '下载', onTap: onDownload),
                      NamidaPopupItem(icon: Broken.slider_horizontal, title: '选择音质下载', onTap: onChooseQualityDownload),
                      NamidaPopupItem(icon: Broken.message_text, title: '查看歌词与详情', onTap: onShowDetails),
                      NamidaPopupItem(icon: Broken.tick_square, title: '多选批量下载', onTap: onToggleMultiSelect),
                      NamidaPopupItem(icon: Broken.headphone, title: '试听播放', subtitle: '下一阶段开放', enabled: false, hasDividerAbove: true, onTap: () {}),
                      NamidaPopupItem(icon: Broken.clock, title: '稍后播放', subtitle: '下一阶段开放', enabled: false, onTap: () {}),
                    ],
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
