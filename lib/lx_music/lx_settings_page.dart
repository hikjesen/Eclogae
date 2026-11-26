import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_storage/namida_storage.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/ui/pages/main_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/mascots/mascots.dart';
import 'package:namida/ui/widgets/settings_card.dart';

import 'lx_bridge_service.dart';
import 'lx_download_manager.dart';
import 'lx_models.dart';
import 'lx_music_page.dart';
import 'lx_preview_player.dart';
import 'widgets/lx_cover_thumb.dart';
import 'widgets/lx_download_task_card.dart';
import 'widgets/lx_source_dialogs.dart';

class LxSettingsPage extends StatefulWidget with NamidaRouteWidget {
  const LxSettingsPage({super.key, this.initialTab = 0});

  final int initialTab;

  static const title = '在线曲库设置';
  static const subtitle = '自定义音源、下载管理、试听缓存、音质与诊断日志';
  static final _requestedTab = ValueNotifier<int?>(null);

  static Future<void> openDownloads() async {
    if (NamidaNavigator.inst.currentRoute is LxSettingsPage) {
      _requestedTab.value = 1;
      return;
    }
    await const LxSettingsPage(initialTab: 1).navigate();
  }

  @override
  RouteType get route => RouteType.SETTINGS_subpage;

  @override
  String? get name => title;

  @override
  State<LxSettingsPage> createState() => _LxSettingsPageState();
}

class _LxSettingsPageState extends State<LxSettingsPage> with SingleTickerProviderStateMixin {
  final _bridge = LxBridgeService.inst;
  final _downloads = LxDownloadManager.inst;
  late final TabController _tabs;
  late final _sourceChanges = Listenable.merge([_bridge.scriptsNotifier, _bridge.userApiStateNotifier, _bridge.updateAlertNotifier]);

  bool _editingSources = false;
  bool _editingDownloads = false;
  bool _logsExpanded = false;
  bool _clearingCache = false;
  bool _previewCacheReadFailed = false;
  int? _previewCacheBytes;
  String? _sourceError;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, initialIndex: widget.initialTab.clampInt(0, 1), vsync: this);
    LxSettingsPage._requestedTab.addListener(_onTabRequested);
    _onTabRequested();
    _editSources('读取音源', _bridge.ensureInitialized);
    _editDownloads('读取下载偏好', _downloads.ensureLoaded);
    _loadPreviewCache();
  }

  @override
  void dispose() {
    LxSettingsPage._requestedTab.removeListener(_onTabRequested);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabRequested() {
    final index = LxSettingsPage._requestedTab.value;
    if (index == null || !identical(NamidaNavigator.inst.currentRoute, widget)) return;
    LxSettingsPage._requestedTab.value = null;
    _tabs.animateTo(index);
  }

  @override
  Widget build(BuildContext context) => BackgroundWrapper(
    child: Stack(
      children: [
        Positioned.fill(
          child: NDecoratedBox(
            decoration: (colors) {
              final theme = Theme.of(context);
              final isDark = theme.brightness == Brightness.dark;
              final accent = colors.accent ?? colors.primary;
              return BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.2, 1.0],
                  colors: [
                    theme.appBarTheme.backgroundColor ?? accent.withOpacityExt(isDark ? 0.0 : 0.10),
                    accent.withOpacityExt(isDark ? 0.16 : 0.24),
                  ],
                ),
              );
            },
          ),
        ),
        const Positioned.fill(child: NamidaMascotBackground.settings()),
        Column(
          children: [
            _buildTabBar(context),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  SuperSmoothListView(
                    key: const PageStorageKey('online-library-settings'),
                    padding: EdgeInsets.symmetric(horizontal: Dimensions.inst.getSettingsHorizontalMargin(context)),
                    children: [_buildSources(), _buildDownloadPreferences(), _buildLogs(), kBottomPaddingWidget],
                  ),
                  const _DownloadsSection(),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildTabBar(BuildContext context) {
    final colors = NColorsData.of(context);
    final pillRadius = BorderRadius.circular(10.0.multipliedRadius);
    return NContainer(
      margin: EdgeInsets.symmetric(horizontal: Dimensions.inst.getSettingsHorizontalMargin(context).withMinimum(12.0), vertical: 6),
      padding: const EdgeInsets.all(3),
      decoration: (colors) => BoxDecoration(color: colors.cardTheme, borderRadius: BorderRadius.circular(12.0.multipliedRadius)),
      child: TabBar(
        controller: _tabs,
        dividerHeight: 0,
        labelColor: colors.primary,
        unselectedLabelColor: colors.onSurface,
        labelStyle: NText.small.of(context),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(color: colors.primary.withOpacityExt(0.16), borderRadius: pillRadius),
        splashBorderRadius: pillRadius,
        tabs: [
          const Tab(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Icon(Broken.setting_2, size: 16), SizedBox(width: 5), Text('设置')],
            ),
          ),
          Tab(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Broken.document_download, size: 16),
                const SizedBox(width: 5),
                const Flexible(child: Text('下载管理', maxLines: 1, overflow: TextOverflow.ellipsis)),
                ValueListenableBuilder<int>(
                  valueListenable: _downloads.activeCountNotifier,
                  builder: (context, count, _) => count > 0
                      ? Padding(
                          padding: const EdgeInsetsDirectional.only(start: 5),
                          child: Badge.count(count: count, backgroundColor: colors.secondaryContainer, textColor: colors.onSecondaryContainer),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSources(String action, Future<void> Function() edit) async {
    if (_editingSources) return;
    setState(() {
      _editingSources = true;
      _sourceError = null;
    });
    try {
      await edit();
    } catch (error) {
      if (mounted) setState(() => _sourceError = '$action失败：$error');
    } finally {
      if (mounted) setState(() => _editingSources = false);
    }
  }

  Future<void> _importLocal() => _editSources('本地导入', () async {
    final file = await NamidaFileBrowser.pickFile(note: '选择自定义音源 .js 文件', memeType: NamidaStorageFileMemeType.any);
    if (file != null) await _bridge.importScript(file);
  });

  Future<void> _importOnline() => _editSources('在线导入', () async {
    final url = await LxImportUrlDialog.show();
    if (url != null) await _bridge.importScriptFromUrl(url);
  });

  Widget _buildSources() => AnimatedBuilder(
    animation: _sourceChanges,
    builder: (context, _) {
      final colors = NColorsData.of(context);
      final state = _bridge.userApiStateNotifier.value;
      final scripts = _bridge.scriptsNotifier.value;
      final activeId = state.meta?.id;
      final alert = _bridge.updateAlertNotifier.value;
      final busy = _editingSources || state.status == LxUserApiStatus.loading;
      final canEdit = LxBridgeService.isSupported && !busy;
      final error = _sourceError ?? state.errorMessage;
      final status = switch (state.status) {
        _ when error != null => '异常',
        LxUserApiStatus.idle => busy ? '初始化中' : '未启用',
        LxUserApiStatus.loading => '初始化中',
        LxUserApiStatus.ready => '已就绪 · ${state.meta!.name}',
        LxUserApiStatus.error => '异常',
      };
      return SettingsCard(
        title: '自定义音源',
        subtitle: status,
        icon: Broken.code_circle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (alert != null)
              CustomListTile(
                title: '自定义音源更新',
                subtitle: alert.sourceName,
                icon: Broken.refresh,
                bgColor: colors.primary.withOpacityExt(0.13),
                onTap: () async {
                  await LxUpdateAlertDialog.show(alert);
                  if (identical(_bridge.updateAlertNotifier.value, alert)) _bridge.dismissUpdateAlert();
                },
                trailingRaw: NamidaIconButton(
                  icon: Broken.close_circle,
                  tooltip: () => '关闭更新提示',
                  padding: const EdgeInsets.all(8),
                  onPressed: _bridge.dismissUpdateAlert,
                ),
              ),
            if (scripts.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: NamidaText('尚未导入任何自定义音源，请通过本地 .js 文件或在线链接导入', style: NText.small),
              ),
            for (final script in scripts)
              CustomListTile(
                key: ValueKey(script.id),
                title: script.name,
                subtitle: [script.version, script.author, script.fileName].where((part) => part.isNotEmpty).join(' · '),
                maxSubtitleLines: 2,
                extraDense: false,
                icon: script.id == activeId ? Broken.tick_circle : Broken.code_circle,
                bgColor: script.id == activeId ? colors.primary.withOpacityExt(0.12) : null,
                onTap: canEdit ? () => _editSources('切换音源', () => _bridge.activateScript(script.id)) : null,
                trailingRaw: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NamidaIconButton(
                      icon: Broken.info_circle,
                      iconSize: 20,
                      padding: const EdgeInsets.all(8),
                      tooltip: () => '音源详情',
                      onPressed: () => LxSourceDetailDialog.show(meta: script, state: state),
                    ),
                    NamidaIconButton(
                      icon: Broken.trash,
                      iconSize: 20,
                      padding: const EdgeInsets.all(8),
                      tooltip: () => '删除音源',
                      onPressed: canEdit ? () => _editSources('删除音源', () => _bridge.deleteScript(script.id)) : null,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  NamidaButton(text: '本地导入 .js', icon: Broken.folder_add, dense: true, enabled: canEdit, onTap: _importLocal),
                  NamidaButton(text: '在线 URL 导入', icon: Broken.global, dense: true, enabled: canEdit, onTap: _importOnline),
                  NamidaButton(
                    text: '重载',
                    icon: Broken.refresh,
                    dense: true,
                    enabled: canEdit && activeId != null,
                    onTap: () => _editSources('重载音源', _bridge.reloadActiveScript),
                  ),
                ],
              ),
            ),
            if (busy) const LinearProgressIndicator(minHeight: 2),
            if (error != null) _SettingsError(error),
          ],
        ),
      );
    },
  );

  Future<void> _editDownloads(String action, Future<void> Function() edit) async {
    if (_editingDownloads) return;
    setState(() {
      _editingDownloads = true;
      _downloadError = null;
    });
    try {
      await edit();
    } catch (error) {
      if (mounted) setState(() => _downloadError = '$action失败：$error');
    } finally {
      if (mounted) setState(() => _editingDownloads = false);
    }
  }

  Future<void> _pickDownloadDirectory(String directory) => _editDownloads('设置下载目录', () async {
    final picked = await NamidaFileBrowser.pickDirectory(note: '选择在线曲库下载目录', initialDirectory: directory);
    if (picked != null) await _downloads.updateSettings(_downloads.settingsNotifier.value.copyWith(downloadDir: picked.path));
  });

  Future<void> _loadPreviewCache() async {
    try {
      final bytes = await LxPreviewPlayer.inst.computePreviewCacheBytes();
      if (mounted) {
        setState(() {
          _previewCacheBytes = bytes;
          _previewCacheReadFailed = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _previewCacheReadFailed = true);
      snackyy(icon: Broken.info_circle, message: '读取在线试听缓存失败：$error', isError: true);
    }
  }

  Future<void> _clearPreviewCache() async {
    setState(() => _clearingCache = true);
    try {
      await LxPreviewPlayer.inst.clearPreviewCache();
      final bytes = await LxPreviewPlayer.inst.computePreviewCacheBytes();
      if (!mounted) return;
      _previewCacheBytes = bytes;
      _previewCacheReadFailed = false;
      snackyy(icon: Broken.tick_circle, message: '已清理在线试听缓存');
    } catch (error) {
      if (mounted) snackyy(icon: Broken.info_circle, message: '清理在线试听缓存失败：$error', isError: true);
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  Future<void> _pickQuality({required bool preview}) {
    final title = preview ? '试听默认音质' : '默认音质';
    return _editDownloads('设置$title', () async {
      final settings = _downloads.settingsNotifier.value;
      final current = preview ? settings.previewQuality : settings.preferredQuality;
      String? chosen;
      await NamidaNavigator.inst.navigateDialog<void>(
        dialog: CustomBlurryDialog(
          title: title,
          icon: preview ? Broken.headphone : Broken.sound,
          normalTitleStyle: true,
          actions: const [CancelButton()],
          child: Column(
            children: [
              for (final quality in LxDownloadSettings.qualityOptions.reversed)
                CustomListTile(
                  title: LxDownloadSettings.qualityLabel(quality),
                  extraDense: true,
                  trailingRaw: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LxQualityBadge(quality: quality),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 18,
                        child: quality == current ? const NIcon(Broken.tick_circle, size: 18, color: NColors.primary) : null,
                      ),
                    ],
                  ),
                  onTap: () {
                    chosen = quality;
                    NamidaNavigator.inst.closeDialog();
                  },
                ),
            ],
          ),
        ),
      );
      if (chosen == null) return;
      final latest = _downloads.settingsNotifier.value;
      await _downloads.updateSettings(preview ? latest.copyWith(previewQuality: chosen) : latest.copyWith(preferredQuality: chosen));
    });
  }

  Widget _buildDownloadPreferences() => ValueListenableBuilder<LxDownloadSettings>(
    valueListenable: _downloads.settingsNotifier,
    builder: (context, options, _) {
      final directory = _downloads.resolveEffectiveDownloadDir();
      final canEdit = !_editingDownloads;
      void save(LxDownloadSettings next) => _editDownloads('保存下载偏好', () => _downloads.updateSettings(next));
      return SettingsCard(
        title: '下载偏好',
        subtitle: directory,
        icon: Broken.document_download,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomListTile(
              title: '下载目录',
              icon: Broken.folder_open,
              subtitle: directory,
              enabled: canEdit,
              onTap: () => _pickDownloadDirectory(directory),
              trailingRaw: options.downloadDir == null
                  ? null
                  : NamidaIconButton(
                      icon: Broken.refresh,
                      tooltip: () => '恢复默认目录',
                      padding: const EdgeInsets.all(8),
                      onPressed: canEdit ? () => save(options.copyWith(downloadDir: null)) : null,
                    ),
            ),
            CustomSwitchListTile(
              title: '歌单下载按歌单名建子文件夹',
              icon: Broken.folder_add,
              subtitle: '开启后从歌单详情页下载的歌曲将归档到 <下载目录>/<歌单名>/',
              value: options.archiveSonglistToSubfolder,
              enabled: canEdit,
              onChanged: (current) {
                final next = !current;
                save(options.copyWith(archiveSonglistToSubfolder: next));
              },
            ),
            CustomListTile(
              title: '默认音质',
              icon: Broken.sound,
              subtitle: '用于首次下载与快速下载降级起点',
              enabled: canEdit,
              trailingRaw: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LxQualityBadge(quality: options.preferredQuality),
                  const SizedBox(width: 6),
                  const NIcon(Broken.arrow_right_3, size: 17),
                ],
              ),
              onTap: () => _pickQuality(preview: false),
            ),
            CustomListTile(
              title: '试听默认音质',
              icon: Broken.headphone,
              subtitle: '${LxDownloadSettings.qualityLabel(options.previewQuality)} · 在线试听优先请求，不可用时自动降级',
              enabled: canEdit,
              trailingRaw: const NIcon(Broken.arrow_right_3, size: 17),
              onTap: () => _pickQuality(preview: true),
            ),
            CustomListTile(
              title: '在线试听缓存',
              icon: Broken.archive_tick,
              subtitle: switch (_previewCacheBytes) {
                final bytes? => '${bytes.fileSizeFormatted} · 清理不影响已下载歌曲',
                null when _previewCacheReadFailed => '无法读取缓存大小',
                null => '计算中…',
              },
              trailingRaw: NamidaButton(
                text: _clearingCache ? '清理中' : '清理',
                dense: true,
                enabled: !_clearingCache && (_previewCacheBytes ?? 0) > 0,
                onTap: _clearPreviewCache,
              ),
            ),
            CustomSwitchListTile(
              title: '默认使用上次选择的音质',
              icon: Broken.flash_1,
              subtitle: '开启后点击下载按上次音质静默入队（当前：${LxDownloadSettings.qualityLabel(options.effectiveQuickQuality)}），长按下载或三点菜单仍可重选',
              value: options.rememberLastQuality,
              enabled: canEdit,
              onChanged: (current) {
                final next = !current;
                save(options.copyWith(rememberLastQuality: next));
              },
            ),
            CustomListTile(
              title: '同时下载并发数',
              icon: Broken.layer,
              subtitle: '同时进行的下载任务上限（默认 1 更稳妥）',
              enabled: canEdit,
              trailingRaw: Wrap(
                spacing: 4,
                children: [
                  for (final count in LxDownloadSettings.concurrentOptions)
                    NamidaButton(
                      text: '$count',
                      minWidth: 26,
                      minHeight: 30,
                      borderRadius: 12,
                      dense: true,
                      enabled: canEdit,
                      colors: options.maxConcurrent == count ? NamidaButtonColors.selected : NamidaButtonColors.dimmed,
                      onTap: () => save(options.copyWith(maxConcurrent: count)),
                    ),
                ],
              ),
            ),
            CustomSwitchListTile(
              title: '自动跨平台换源',
              icon: Broken.arrow_swap_horizontal,
              subtitle: '原平台不可用时自动搜索其他平台同名曲目',
              value: options.autoSwitchSource,
              enabled: canEdit,
              onChanged: (current) {
                final next = !current;
                save(options.copyWith(autoSwitchSource: next));
              },
            ),
            CustomSwitchListTile(
              title: '同时保存 LRC 歌词',
              icon: Broken.message_text,
              value: options.exportLrc,
              enabled: canEdit,
              onChanged: (current) {
                final next = !current;
                save(options.copyWith(exportLrc: next));
              },
            ),
            CustomSwitchListTile(
              title: '包含翻译歌词',
              icon: Broken.translate,
              value: options.includeTranslationLyric,
              enabled: canEdit && options.exportLrc,
              onChanged: (current) {
                final next = !current;
                save(options.copyWith(includeTranslationLyric: next));
              },
            ),
            CustomSwitchListTile(
              title: '包含罗马音',
              icon: Broken.smallcaps,
              value: options.includeRomanizationLyric,
              enabled: canEdit && options.exportLrc,
              onChanged: (current) {
                final next = !current;
                save(options.copyWith(includeRomanizationLyric: next));
              },
            ),
            CustomSwitchListTile(
              title: '嵌入专辑封面',
              icon: Broken.gallery,
              value: options.embedCover,
              enabled: canEdit,
              onChanged: (current) {
                final next = !current;
                save(options.copyWith(embedCover: next));
              },
            ),
            if (_editingDownloads) const LinearProgressIndicator(minHeight: 2),
            if (_downloadError case final error?) _SettingsError(error),
          ],
        ),
      );
    },
  );

  Future<void> _copyLogs(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) snackyy(icon: Broken.document_text, message: '已复制诊断日志');
    } catch (error) {
      if (mounted) snackyy(icon: Broken.info_circle, message: '复制诊断日志失败：$error', isError: true);
    }
  }

  Widget _buildLogs() => ValueListenableBuilder<List<LxLogEntry>>(
    valueListenable: _bridge.logsNotifier,
    builder: (context, logs, _) {
      return SettingsCard(
        title: '诊断日志',
        subtitle: '${logs.length} 条记录',
        icon: Broken.document_text,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomListTile(
              title: _logsExpanded ? '收起日志' : '展开日志',
              extraDense: true,
              trailingRaw: NIcon(_logsExpanded ? Broken.arrow_up_2 : Broken.arrow_down_1, size: 18),
              onTap: () => setState(() => _logsExpanded = !_logsExpanded),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  NamidaButton(text: '复制日志', dense: true, enabled: logs.isNotEmpty, onTap: () => _copyLogs(logs.reversed.join('\n'))),
                  NamidaButton(text: '清空', dense: true, enabled: logs.isNotEmpty, onTap: _bridge.clearLogs),
                ],
              ),
            ),
            if (_logsExpanded && logs.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SmoothSingleChildScrollView(
                  primary: false,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SelectableText(logs.reversed.join('\n'), style: NText.small.of(context)),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _DownloadsSection extends StatelessWidget {
  const _DownloadsSection();

  Future<void> _playTrack(Track track) async {
    try {
      await Player.inst.playKeepingQueue([track], QueueSource.others(LxMusicPage.title));
    } catch (error) {
      snackyy(icon: Broken.info_circle, message: '播放失败：$error', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloads = LxDownloadManager.inst;
    final margin = Dimensions.inst.getSettingsHorizontalMargin(context);
    return ValueListenableBuilder<List<LxDownloadTask>>(
      valueListenable: downloads.tasksNotifier,
      builder: (context, tasks, _) => ValueListenableBuilder<LxDownloadSettings>(
        valueListenable: downloads.settingsNotifier,
        builder: (context, settings, _) => SuperSmoothListView.builder(
          key: const PageStorageKey('lx-downloads'),
          padding: EdgeInsets.fromLTRB(margin, 4, margin, Dimensions.globalBottomPaddingTotal),
          itemCount: tasks.isEmpty ? 2 : tasks.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    NamidaText('下载任务 (${tasks.length})', style: NText.medium),
                    NContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: (colors) => BoxDecoration(color: colors.cardTheme, borderRadius: BorderRadius.circular(10.0.multipliedRadius)),
                      child: NamidaText('并行 ${settings.maxConcurrent}', style: NText.small),
                    ),
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
              return const CustomListTile(
                icon: Broken.document_download,
                title: '暂无下载任务',
                subtitle: '在在线曲库搜索歌曲即可加入下载队列',
              );
            }
            final task = tasks[index - 1];
            return Padding(
              key: ValueKey(task.id),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
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

class _SettingsError extends StatelessWidget {
  const _SettingsError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
    child: NamidaText(message, style: NText.small, color: NColors.error),
  );
}
