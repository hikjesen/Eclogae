import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_storage/namida_storage.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/mascots/mascots.dart';
import 'package:namida/ui/widgets/settings_card.dart';

import 'lx_bridge_service.dart';
import 'lx_download_manager.dart';
import 'lx_models.dart';
import 'widgets/lx_cover_thumb.dart';
import 'widgets/lx_source_dialogs.dart';

class LxSettingsPage extends StatefulWidget with NamidaRouteWidget {
  const LxSettingsPage({super.key});

  static const title = '在线曲库设置';
  static const subtitle = '自定义音源、下载目录、默认音质、并发数与诊断日志';

  @override
  RouteType get route => RouteType.SETTINGS_subpage;

  @override
  String? get name => title;

  @override
  State<LxSettingsPage> createState() => _LxSettingsPageState();
}

class _LxSettingsPageState extends State<LxSettingsPage> {
  final _bridge = LxBridgeService.inst;
  final _downloads = LxDownloadManager.inst;
  late final _sourceChanges = Listenable.merge([_bridge.scriptsNotifier, _bridge.userApiStateNotifier, _bridge.updateAlertNotifier]);

  bool _editingSources = false;
  bool _editingDownloads = false;
  bool _logsExpanded = false;
  String? _sourceError;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    _editSources('读取音源', _bridge.ensureInitialized);
    _editDownloads('读取下载偏好', _downloads.ensureLoaded);
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
        SuperSmoothListView(
          padding: EdgeInsets.symmetric(horizontal: Dimensions.inst.getSettingsHorizontalMargin(context)),
          children: [_buildSources(), _buildDownloadPreferences(), _buildLogs(), kBottomPaddingWidget],
        ),
      ],
    ),
  );

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

  Future<void> _pickDefaultQuality() => _editDownloads('设置默认音质', () async {
    final current = _downloads.settingsNotifier.value.preferredQuality;
    String? chosen;
    await NamidaNavigator.inst.navigateDialog<void>(
      dialog: CustomBlurryDialog(
        title: '默认音质',
        icon: Broken.sound,
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
    if (chosen != null) await _downloads.updateSettings(_downloads.settingsNotifier.value.copyWith(preferredQuality: chosen));
  });

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
              onTap: _pickDefaultQuality,
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

class _SettingsError extends StatelessWidget {
  const _SettingsError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
    child: NamidaText(message, style: NText.small, color: NColors.error),
  );
}
