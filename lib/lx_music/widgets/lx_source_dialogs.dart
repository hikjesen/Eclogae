import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

import '../lx_models.dart';
import 'lx_cover_thumb.dart';

String? _httpUrl(String? value) {
  if (value == null) return null;
  final url = value.trim();
  final uri = Uri.tryParse(url);
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty ? url : null;
}

class LxImportUrlDialog extends StatefulWidget {
  const LxImportUrlDialog._(this.onImport);

  final ValueChanged<String> onImport;

  static Future<String?> show() async {
    String? url;
    await NamidaNavigator.inst.navigateDialog<void>(
      dialog: LxImportUrlDialog._((value) => url = value),
    );
    return url;
  }

  @override
  State<LxImportUrlDialog> createState() => _LxImportUrlDialogState();
}

class _LxImportUrlDialogState extends State<LxImportUrlDialog> {
  final _form = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text?.trim();
    if (!mounted || text == null || text.isEmpty) return;
    _controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    widget.onImport(_controller.text.trim());
    NamidaNavigator.inst.closeDialog();
  }

  @override
  Widget build(BuildContext context) {
    return CustomBlurryDialog(
      normalTitleStyle: true,
      icon: Broken.import_1,
      title: '从链接导入自定义音源',
      child: Form(
        key: _form,
        child: CustomTagTextField(
          controller: _controller,
          labelText: '音源 URL',
          hintText: 'https://example.com/source.js',
          keyboardType: TextInputType.url,
          maxLines: 1,
          showChangedMark: false,
          validator: (value) => _httpUrl(value) == null ? '请输入有效的 HTTP 或 HTTPS 链接' : null,
          onFieldSubmitted: (_) => _submit(),
          suffixIcon: NamidaIconButton(
            icon: Broken.clipboard_text,
            tooltip: () => '粘贴链接',
            onPressed: _paste,
          ),
        ),
      ),
      actions: [
        const CancelButton(),
        NamidaButton(text: '导入', icon: Broken.import_1, dense: true, onTap: _submit),
      ],
    );
  }
}

class LxSourceDetailDialog {
  static Future<void> show({required LxUserApiMeta meta, required LxUserApiState state}) async {
    final homepage = _httpUrl(meta.homepage);
    final active = state.status == LxUserApiStatus.ready && state.meta?.id == meta.id;
    await NamidaNavigator.inst.navigateDialog<void>(
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        icon: Broken.info_circle,
        title: '自定义音源详情',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NamidaText(meta.name, style: const NText(.large, size: .s17)),
            const SizedBox(height: 8),
            _metadata('版本', meta.version),
            _metadata('作者', meta.author),
            _metadata('文件名', meta.fileName),
            if (meta.description.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              const NamidaText('简介', style: NText.small),
              NamidaText(meta.description, style: NText.medium),
            ],
            if (homepage != null)
              CustomListTile(
                title: '音源主页',
                subtitle: homepage,
                maxSubtitleLines: 1,
                extraDense: true,
                icon: Broken.global,
                onTap: () => NamidaLinkUtils.openLink(homepage),
              )
            else if (meta.homepage.isNotEmpty)
              _metadata('主页', meta.homepage),
            if (active) ...[
              const NamidaContainerDivider(margin: EdgeInsets.symmetric(vertical: 10.0)),
              const NamidaText('平台与音质支持', style: NText.medium),
              const SizedBox(height: 8),
              _qualityMatrix(state.supportedQualities),
            ],
          ],
        ),
        actions: [
          NamidaButton(text: '知道了', dense: true, onTap: NamidaNavigator.inst.closeDialog),
        ],
      ),
    );
  }

  static Widget _metadata(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 0,
          child: SizedBox(width: 56, child: NamidaText(title, style: NText.small)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: NamidaText(value.isEmpty ? '—' : value, style: NText.medium),
        ),
      ],
    ),
  );

  static Widget _qualityMatrix(Map<String, List<String>> supportedQualities) {
    final qualities = LxDownloadSettings.qualityOptions.reversed;
    return NDecoratedBox(
      decoration: (colors) => BoxDecoration(
        color: colors.secondaryContainer.withOpacityExt(0.22),
        borderRadius: BorderRadius.circular(10.0.multipliedRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {0: FlexColumnWidth(1.25)},
          children: [
            TableRow(
              children: [
                const NamidaText('平台', style: NText.small),
                for (final quality in qualities)
                  Center(
                    child: Tooltip(message: LxDownloadSettings.qualityLabel(quality), child: LxQualityBadge(quality: quality)),
                  ),
              ],
            ),
            for (final platform in LxPlatform.values)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: NamidaText(platform.label, style: NText.small),
                  ),
                  for (final quality in qualities)
                    Center(
                      child: supportedQualities[platform.code]?.contains(quality) == true
                          ? const NIcon(Broken.tick_circle, size: 15, color: NColors.primary, semanticLabel: '支持')
                          : const NamidaText('—', style: NText.small, color: NColors.disabled),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class LxUpdateAlertDialog {
  static Future<void> show(LxUpdateAlert alert) async {
    final url = _httpUrl(alert.updateUrl);
    await NamidaNavigator.inst.navigateDialog<void>(
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        title: '自定义音源更新',
        icon: Broken.refresh,
        child: Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NamidaText(alert.sourceName, style: NText.medium),
              const SizedBox(height: 8),
              SelectableText(alert.log, style: NText.small.of(context)),
            ],
          ),
        ),
        actions: [
          NamidaButton(text: '知道了', dense: true, onTap: NamidaNavigator.inst.closeDialog),
          if (url != null)
            NamidaButton(text: '打开更新链接', icon: Broken.link, dense: true, onTap: () => NamidaLinkUtils.openLink(url)),
        ],
      ),
    );
  }
}

enum LxDuplicateAction { cancel, onlyFresh, downloadAll }

class LxDuplicateConfirmDialog {
  static Future<LxDuplicateAction> show({
    required int freshCount,
    required int onDiskCount,
    required int inQueueCount,
    String? singleTrackName,
  }) async {
    var action = LxDuplicateAction.cancel;
    void choose(LxDuplicateAction selected) {
      action = selected;
      NamidaNavigator.inst.closeDialog();
    }

    await NamidaNavigator.inst.navigateDialog<void>(
      dialog: CustomBlurryDialog(
        normalTitleStyle: true,
        title: '确认下载',
        icon: Broken.document_download,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NamidaText(singleTrackName ?? '所选曲目中有重复下载项。', style: NText.medium, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            if (onDiskCount > 0) NamidaText('本地已有 $onDiskCount 首', style: NText.small),
            if (inQueueCount > 0) NamidaText('下载队列中已有 $inQueueCount 首', style: NText.small),
            if (freshCount > 0) NamidaText('新曲目 $freshCount 首', style: NText.small),
          ],
        ),
        actions: [
          const CancelButton(),
          if (freshCount > 0)
            NamidaButton(
              text: '仅下载新曲目 ($freshCount)',
              dense: true,
              onTap: () => choose(LxDuplicateAction.onlyFresh),
            ),
          NamidaButton(
            text: singleTrackName == null ? '全部重新下载' : '仍然下载',
            dense: true,
            colors: freshCount > 0 ? NamidaButtonColors.dimmed : NamidaButtonColors.saturated,
            onTap: () => choose(LxDuplicateAction.downloadAll),
          ),
        ],
      ),
    );
    return action;
  }
}
