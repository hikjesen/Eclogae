import 'package:flutter/material.dart';

import 'package:path/path.dart' as p;

import 'package:namida/class/track.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

import '../lx_download_manager.dart';
import '../lx_models.dart';
import 'lx_cover_thumb.dart';

class LxDownloadTaskCard extends StatelessWidget {
  const LxDownloadTaskCard({super.key, required this.task, this.onPlay, this.onLocateInLibrary});

  final LxDownloadTask task;
  final void Function(Track track)? onPlay;
  final void Function(Track track)? onLocateInLibrary;

  static const _stages = [
    LxDownloadStage.resolving,
    LxDownloadStage.downloading,
    LxDownloadStage.verifying,
    LxDownloadStage.tagging,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = NColorsData.of(context);
    final manager = LxDownloadManager.inst;
    final stage = task.stage;
    final completed = stage == LxDownloadStage.completed;
    final failed = stage == LxDownloadStage.failed;
    final stageAccent = switch (stage) {
      LxDownloadStage.failed => colors.error,
      LxDownloadStage.completed => const Color(0xFF1F9D7A),
      LxDownloadStage.canceled || LxDownloadStage.queued => colors.onSurface.withOpacityExt(0.56),
      _ => colors.primary,
    };
    final savedPath = task.savedPath;
    final errorMessage = task.errorMessage;
    final indexedTrack = task.indexedTrack;
    final play = onPlay;
    final locate = onLocateInLibrary;
    final resolvedSource = task.resolvedSource;
    final sourceLabel = resolvedSource == null || resolvedSource == task.track.source
        ? task.track.source.label
        : '${task.track.source.label} → ${resolvedSource.label}';

    return NContainer(
      padding: const EdgeInsets.all(12),
      decoration: (colors) => BoxDecoration(
        color: colors.card.withOpacityExt(0.62),
        borderRadius: BorderRadius.circular(16.0.multipliedRadius),
        border: Border.all(
          color: failed
              ? colors.error.withOpacityExt(0.37)
              : task.isActive
              ? colors.primary.withOpacityExt(0.25)
              : colors.onSurface.withOpacityExt(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LxCoverThumb(url: task.track.picUrl, size: 50),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NamidaText(task.track.name, style: NText.medium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (task.track.singer.isNotEmpty)
                      NamidaText(task.track.singer, style: NText.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        NamidaText(sourceLabel, style: const NText(.small, size: .s11)),
                        LxQualityBadge(quality: task.resolvedQuality ?? task.requestedQuality),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: stageAccent.withOpacityExt(0.13),
                  borderRadius: BorderRadius.circular(10.0.multipliedRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  child: NamidaText(
                    stage.label,
                    style: const NText(.small, size: .s11, weight: FontWeight.w700),
                    color: NColors.fixed(Color.alphaBlend(stageAccent.withOpacityExt(0.54), colors.onSurface)),
                  ),
                ),
              ),
            ],
          ),
          if (task.isActive || failed) ...[
            const SizedBox(height: 12),
            _stepBar(colors, failed),
          ],
          if (task.isActive) ...[
            const SizedBox(height: 10),
            _progressBlock(colors),
          ],
          if (completed && savedPath != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: NamidaText(p.basename(savedPath), style: NText.small, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (task.lrcPath != null) ...[
                  const SizedBox(width: 6),
                  NContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: (colors) => BoxDecoration(
                      color: colors.primary.withOpacityExt(0.12),
                      borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                    ),
                    child: const NamidaText('.lrc', style: NText(.small, size: .s11, weight: FontWeight.w700), color: NColors.primary),
                  ),
                ],
              ],
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            NContainer(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: (colors) => BoxDecoration(
                color: colors.error.withOpacityExt(0.10),
                borderRadius: BorderRadius.circular(10.0.multipliedRadius),
              ),
              child: SelectableText(errorMessage, style: NText.small.of(context).copyWith(color: colors.error)),
            ),
          ],
          if (task.canCancel || !task.isActive) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (task.canCancel)
                  NamidaButton(
                    text: '取消',
                    icon: Broken.close_circle,
                    dense: true,
                    colors: NamidaButtonColors.dimmed,
                    onTap: () => manager.cancel(task.id),
                  ),
                if (task.canRetry) NamidaButton(text: '重试', icon: Broken.refresh, dense: true, onTap: () => manager.retry(task.id)),
                if (completed && indexedTrack != null && play != null)
                  NamidaButton(text: '立即播放', icon: Broken.play, dense: true, colors: NamidaButtonColors.saturated, onTap: () => play(indexedTrack)),
                if (completed && indexedTrack != null && locate != null)
                  NamidaButton(
                    text: '定位曲库',
                    icon: Broken.music_square_search,
                    dense: true,
                    colors: NamidaButtonColors.dimmed,
                    onTap: () => locate(indexedTrack),
                  ),
                if (!task.isActive)
                  NamidaButton(text: '移除', icon: Broken.trash, dense: true, colors: NamidaButtonColors.dimmed, onTap: () => manager.removeTask(task.id)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepBar(NColorsData colors, bool failed) {
    final currentIndex = _stages.indexOf(failed ? task.failedStage ?? task.stage : task.stage);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, stage) in _stages.indexed)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _step(colors, stage, index, currentIndex, failed),
            ),
          ),
      ],
    );
  }

  Widget _step(NColorsData colors, LxDownloadStage stage, int index, int currentIndex, bool failed) {
    final past = index < currentIndex;
    final current = index == currentIndex;
    final accent = current && failed ? colors.error : colors.primary;
    final status = past ? '已完成' : current ? (failed ? '失败' : '进行中') : '待处理';
    return Semantics(
      label: '${stage.label}，$status',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: current || past ? accent.withOpacityExt(current ? 1 : 0.48) : colors.onSurface.withOpacityExt(0.12),
              borderRadius: BorderRadius.circular(2.0.multipliedRadius),
            ),
          ),
          const SizedBox(height: 4),
          NamidaText(
            stage.label,
            style: NText(.small, size: .s10, weight: current ? FontWeight.w700 : null),
            color: current ? NColors.fixed(accent) : NColors.textSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _progressBlock(NColorsData colors) {
    final downloading = task.stage == LxDownloadStage.downloading;
    final progress = task.progress;
    final received = task.receivedBytes.fileSizeFormatted;
    final stats = progress == null ? received : '${(progress * 100).round()}% · $received / ${task.totalBytes.fileSizeFormatted}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: downloading ? progress : null,
          minHeight: 5,
          borderRadius: BorderRadius.circular(3.0.multipliedRadius),
          color: colors.primary,
          backgroundColor: colors.primary.withOpacityExt(0.12),
          semanticsLabel: task.stage.label,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: NamidaText(stats, style: const NText(.small, size: .s11))),
            if (downloading && task.bytesPerSecond > 0)
              NamidaText('${task.bytesPerSecond.fileSizeFormatted}/s', style: const NText(.small, size: .s11), color: NColors.primary),
          ],
        ),
      ],
    );
  }
}
