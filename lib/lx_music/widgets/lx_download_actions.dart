import 'package:flutter/foundation.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';

import '../lx_download_manager.dart';
import '../lx_models.dart';
import 'lx_download_quality_dialog.dart';
import 'lx_source_dialogs.dart';

class LxDownloadActions {
  static Future<bool> downloadTracks(List<LxTrack> tracks, {bool forceDialog = false, VoidCallback? onOpenDownloads, String? subfolderName}) async {
    final downloads = LxDownloadManager.inst;
    final single = tracks.length == 1;
    final queuedMessage = single ? '已在下载队列中' : '所选歌曲均已在下载队列中';
    try {
      await downloads.ensureLoaded();
      await downloads.refreshExistingFiles();
      final (:fresh, :onDisk, :inQueue) = downloads.classifyDuplicates(tracks);
      if (fresh.isEmpty && onDisk.isEmpty) {
        snackyy(icon: Broken.info_circle, message: queuedMessage);
        return false;
      }

      var targets = [...fresh, ...onDisk];
      if (onDisk.isNotEmpty && (!forceDialog || !single)) {
        final action = await LxDuplicateConfirmDialog.show(
          freshCount: fresh.length,
          onDiskCount: onDisk.length,
          inQueueCount: inQueue.length,
          singleTrackName: single ? tracks.single.name : null,
        );
        if (action == LxDuplicateAction.cancel) return false;
        if (action == LxDuplicateAction.onlyFresh) targets = fresh;
      }
      if (targets.isEmpty) return false;

      final options = downloads.settingsNotifier.value;
      final quality = !forceDialog && options.rememberLastQuality
          ? options.effectiveQuickQuality
          : await LxDownloadQualityDialog.show(
              trackCount: targets.length,
              singleTrack: targets.length == 1 ? targets.single : null,
              initialSettings: options,
              effectiveDir: downloads.resolveTargetDir(subfolderName: subfolderName),
              onSettingsChanged: downloads.updateSettings,
            );
      if (quality == null) return false;

      final finalTargets = targets.where((track) => downloads.latestTaskForTrack(track)?.isActive != true).toList();
      if (finalTargets.isEmpty) {
        snackyy(icon: Broken.info_circle, message: queuedMessage);
        return false;
      }

      final added = downloads.enqueueBatch(finalTargets, quality: quality, subfolderName: subfolderName);
      snackyy(
        icon: Broken.document_download,
        message: '已将 ${added.length} 首歌曲加入下载队列',
        button: onOpenDownloads == null ? null : SnackbarButton(text: '查看下载', function: onOpenDownloads),
      );
      return added.isNotEmpty;
    } catch (error) {
      snackyy(icon: Broken.info_circle, message: '加入下载队列失败：$error', isError: true);
      return false;
    }
  }
}
