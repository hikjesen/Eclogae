import 'package:flutter/material.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

import '../lx_models.dart';
import 'lx_cover_thumb.dart';

class LxDownloadQualityDialog extends StatefulWidget {
  const LxDownloadQualityDialog._({
    super.key,
    required this.trackCount,
    required this.singleTrack,
    required this.initialSettings,
    required this.effectiveDir,
    required this.onSettingsChanged,
    required this.onSelected,
  });

  static Future<String?> show({
    required int trackCount,
    LxTrack? singleTrack,
    required LxDownloadSettings initialSettings,
    required String effectiveDir,
    required Future<void> Function(LxDownloadSettings) onSettingsChanged,
  }) async {
    String? selectedQuality;
    final key = GlobalKey<_LxDownloadQualityDialogState>();
    await NamidaNavigator.inst.navigateDialog<void>(
      tapToDismiss: () => key.currentState?._saving != true,
      dialog: LxDownloadQualityDialog._(
        key: key,
        trackCount: trackCount,
        singleTrack: singleTrack,
        initialSettings: initialSettings,
        effectiveDir: effectiveDir,
        onSettingsChanged: onSettingsChanged,
        onSelected: (quality) => selectedQuality = quality,
      ),
    );
    return selectedQuality;
  }

  final int trackCount;
  final LxTrack? singleTrack;
  final LxDownloadSettings initialSettings;
  final String effectiveDir;
  final Future<void> Function(LxDownloadSettings) onSettingsChanged;
  final ValueChanged<String> onSelected;

  @override
  State<LxDownloadQualityDialog> createState() => _LxDownloadQualityDialogState();
}

class _LxDownloadQualityDialogState extends State<LxDownloadQualityDialog> {
  late LxDownloadSettings _settings = widget.initialSettings;
  bool _saving = false;
  String? _saveError;

  Future<void> _save(LxDownloadSettings settings, {String? selectedQuality}) async {
    if (_saving) return;
    final previous = _settings;
    setState(() {
      _settings = settings;
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onSettingsChanged(settings);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _settings = previous;
        _saving = false;
        _saveError = '保存下载设置失败：$error';
      });
      return;
    }
    if (!mounted) return;
    if (selectedQuality != null && ModalRoute.isCurrentOf(context) == true) {
      widget.onSelected(selectedQuality);
      await NamidaNavigator.inst.closeDialog();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = NColorsData.of(context);
    final singleTrack = widget.singleTrack;
    final summary = widget.trackCount == 1 && singleTrack != null ? '1 首歌曲 · ${singleTrack.name}' : '已选 ${widget.trackCount} 首歌曲';
    final saveError = _saveError;

    return ExcludeFocus(
      excluding: _saving,
      child: AbsorbPointer(
        absorbing: _saving,
        child: CustomBlurryDialog(
          normalTitleStyle: true,
          icon: Broken.document_download,
          title: '下载歌曲',
          actions: const [CancelButton()],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NamidaText(summary, style: NText.medium, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(
                children: [
                  const NIcon(Broken.folder_open, size: 15, color: NColors.secondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Tooltip(
                      message: widget.effectiveDir,
                      child: NamidaText(widget.effectiveDir, style: NText.small, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final quality in LxDownloadSettings.qualityOptions.reversed) _qualityOption(colors, quality),
              const NamidaContainerDivider(margin: EdgeInsets.symmetric(vertical: 10.0)),
              CustomSwitchListTile(
                extraDense: true,
                title: '同时保存 LRC 歌词',
                value: _settings.exportLrc,
                onChanged: (current) {
                  final next = !current;
                  _save(_settings.copyWith(exportLrc: next));
                },
              ),
              CustomSwitchListTile(
                extraDense: true,
                title: '包含翻译歌词',
                value: _settings.includeTranslationLyric,
                enabled: _settings.exportLrc,
                onChanged: (current) {
                  final next = !current;
                  _save(_settings.copyWith(includeTranslationLyric: next));
                },
              ),
              CustomSwitchListTile(
                extraDense: true,
                title: '包含罗马音',
                value: _settings.includeRomanizationLyric,
                enabled: _settings.exportLrc,
                onChanged: (current) {
                  final next = !current;
                  _save(_settings.copyWith(includeRomanizationLyric: next));
                },
              ),
              CustomSwitchListTile(
                extraDense: true,
                title: '嵌入专辑封面',
                value: _settings.embedCover,
                onChanged: (current) {
                  final next = !current;
                  _save(_settings.copyWith(embedCover: next));
                },
              ),
              if (_saving) const LinearProgressIndicator(minHeight: 2, semanticsLabel: '正在保存下载设置'),
              if (saveError != null) NamidaText(saveError, style: NText.small, color: NColors.error),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qualityOption(NColorsData colors, String quality) {
    final lastSelected = quality == _settings.lastSelectedQuality;
    final highlighted = quality == (_settings.lastSelectedQuality ?? _settings.preferredQuality);
    return NamidaInkWell(
      width: double.infinity,
      borderRadius: 12.0,
      bgColor: NColors.fixed(highlighted ? colors.primary.withOpacityExt(0.12) : colors.onSurface.withOpacityExt(0.04)),
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      onTap: () => _save(_settings.copyWith(lastSelectedQuality: quality), selectedQuality: quality),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 3,
              children: [
                NamidaText(LxDownloadSettings.qualityLabel(quality), style: NText.medium),
                if (lastSelected)
                  NContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: (colors) => BoxDecoration(
                      color: colors.primary.withOpacityExt(0.15),
                      borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                    ),
                    child: const NamidaText('上次选择', style: NText(.small, size: .s10)),
                  ),
                if (widget.singleTrack?.qualities.contains(quality) == true)
                  const NamidaText('· 源支持', style: NText(.small, size: .s10), color: NColors.secondary),
              ],
            ),
          ),
          const SizedBox(width: 6),
          LxQualityBadge(quality: quality),
        ],
      ),
    );
  }
}
