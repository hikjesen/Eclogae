import 'dart:async';

import 'package:flutter/material.dart';

import 'package:eclogae/class/route.dart';
import 'package:eclogae/controller/current_color.dart';
import 'package:eclogae/controller/navigator_controller.dart';
import 'package:eclogae/core/dimensions.dart';
import 'package:eclogae/core/enums.dart';
import 'package:eclogae/core/extensions.dart';
import 'package:eclogae/core/icon_fonts/broken_icons.dart';
import 'package:eclogae/core/ntheme.dart';
import 'package:eclogae/ui/dialogs/color_picker_dialog.dart';
import 'package:eclogae/ui/widgets/custom_widgets.dart';
import 'package:eclogae/ui/widgets/mascots/mascots.dart';
import 'package:eclogae/ui/widgets/settings_card.dart';

import 'floating_lyrics_controller.dart';
import 'floating_lyrics_eyedropper_dialog.dart';
import 'floating_lyrics_models.dart';

class FloatingLyricsSettingsPage extends StatefulWidget with NamidaRouteWidget {
  const FloatingLyricsSettingsPage({super.key});

  @override
  RouteType get route => RouteType.SETTINGS_subpage;

  @override
  String get name => '悬浮歌词';

  @override
  State<FloatingLyricsSettingsPage> createState() => _FloatingLyricsSettingsPageState();
}

class _FloatingLyricsSettingsPageState extends State<FloatingLyricsSettingsPage> {
  final _controller = FloatingLyricsController.inst;
  late final _changes = Listenable.merge([_controller.settingsNotifier, _controller.hasPermissionNotifier]);

  @override
  void initState() {
    super.initState();
    _controller.setSettingsPreview(true);
    unawaited(_controller.init());
  }

  @override
  void dispose() {
    _controller.setSettingsPreview(false);
    super.dispose();
  }

  Future<void> _update(FloatingLyricsSettings Function(FloatingLyricsSettings) change, {bool persist = true}) async {
    await _controller.init();
    await _controller.updateSettings(change(_controller.settingsNotifier.value), persist: persist);
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
        ListenableBuilder(
          listenable: _changes,
          builder: (context, _) {
            final s = _controller.settingsNotifier.value;
            return SuperSmoothListView(
              key: const PageStorageKey('floating-lyrics-settings'),
              padding: EdgeInsets.symmetric(horizontal: Dimensions.inst.getSettingsHorizontalMargin(context)),
              children: [
                if (!_controller.hasPermissionNotifier.value) _buildPermission(),
                _buildControls(s),
                _buildStyle(context, s),
                _shortcutHelp,
                kBottomPaddingWidget,
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget _buildPermission() => SettingsCard(
    title: '需要悬浮窗权限',
    subtitle: '允许 Eclogae 显示在其他应用上层后，即可启用悬浮歌词。',
    icon: Broken.info_circle,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: NamidaButton(
        text: '去开启悬浮窗权限',
        icon: Broken.layer,
        onTap: _controller.requestOverlayPermission,
      ),
    ),
  );

  Widget _buildControls(FloatingLyricsSettings s) => SettingsCard(
    title: '基础控制',
    subtitle: null,
    icon: Broken.setting_2,
    child: Column(
      children: [
        CustomSwitchListTile(
          title: '启用悬浮歌词',
          icon: Broken.message_text,
          value: s.enabled,
          onChanged: (current) => _controller.setEnabled(!current),
        ),
        CustomSwitchListTile(
          title: '锁定位置',
          subtitle: '锁定后触摸会穿透悬浮窗',
          icon: Broken.lock_1,
          value: s.locked,
          onChanged: (current) => _controller.setLocked(!current),
        ),
        CustomSwitchListTile(
          title: '在应用内也显示',
          icon: Broken.mobile,
          value: s.showInApp,
          onChanged: (current) => _update((latest) => latest.copyWith(showInApp: !current)),
        ),
        CustomSwitchListTile(
          title: '显示翻译歌词',
          subtitle: s.singleLine ? '单行滚动模式仅显示主行' : null,
          icon: Broken.translate,
          value: s.showTranslation,
          enabled: !s.singleLine,
          onChanged: (current) => _update((latest) => latest.copyWith(showTranslation: !current)),
        ),
        CustomSwitchListTile(
          title: '显示罗马音',
          subtitle: s.singleLine ? '单行滚动模式仅显示主行' : null,
          icon: Broken.translate,
          value: s.showRomanization,
          enabled: !s.singleLine,
          onChanged: (current) => _update((latest) => latest.copyWith(showRomanization: !current)),
        ),
      ],
    ),
  );

  Widget _buildStyle(BuildContext context, FloatingLyricsSettings s) {
    final colors = NColorsData.of(context);
    return SettingsCard(
      title: '样式与排版',
      subtitle: null,
      icon: Broken.brush_2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomListTile(title: '文字颜色', subtitle: s.colorPreset.label, icon: Broken.color_swatch),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final preset in FloatingLyricsColorPreset.values)
                  if (preset != FloatingLyricsColorPreset.custom || preset == s.colorPreset)
                    _colorButton(
                      colors,
                      label: preset.label,
                      color: _controller.textColorFor(s, preset: preset),
                      selected: preset == s.colorPreset,
                      followsAlbum: preset == FloatingLyricsColorPreset.followAlbum,
                      onTap: preset == FloatingLyricsColorPreset.custom
                          ? () => _pickRgbColor(s, outline: false)
                          : () => _update((latest) => latest.copyWith(colorPreset: preset)),
                    ),
              ],
            ),
          ),
          _colorActions(s, outline: false),
          CustomSwitchListTile(
            title: '文字描边',
            subtitle: '增强歌词在复杂背景上的可读性',
            icon: Broken.text_block,
            value: s.textOutline,
            onChanged: (current) => _update((latest) => latest.copyWith(textOutline: !current)),
          ),
          if (s.textOutline) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final preset in floatingLyricsOutlinePresets)
                    _colorButton(
                      colors,
                      label: preset.label,
                      color: Color(preset.argb),
                      selected: preset.argb == s.outlineColorArgb,
                      onTap: () => _update((latest) => latest.copyWith(outlineColorArgb: preset.argb)),
                    ),
                  if (!floatingLyricsOutlinePresets.any((preset) => preset.argb == s.outlineColorArgb))
                    _colorButton(
                      colors,
                      label: '自定义描边色',
                      color: Color(s.outlineColorArgb),
                      selected: true,
                      onTap: () => _pickRgbColor(s, outline: true),
                    ),
                ],
              ),
            ),
            _colorActions(s, outline: true),
          ],
          _FloatingLyricsSlider(
            title: '字体大小',
            icon: Broken.text,
            value: s.fontSizeSp,
            min: 8,
            max: 34,
            unit: ' sp',
            onChanged: (value) => _update((latest) => latest.copyWith(fontSizeSp: value), persist: false),
            onChangeEnd: (value) => _update((latest) => latest.copyWith(fontSizeSp: value), persist: true),
          ),
          _FloatingLyricsSlider(
            title: '文字透明度',
            icon: Broken.eye,
            value: (s.opacity * 100).roundToDouble(),
            min: 20,
            max: 100,
            unit: '%',
            onChanged: (value) => _update((latest) => latest.copyWith(opacity: value / 100), persist: false),
            onChangeEnd: (value) => _update((latest) => latest.copyWith(opacity: value / 100), persist: true),
          ),
          _FloatingLyricsSlider(
            title: '悬浮窗宽度',
            icon: Broken.size,
            value: s.widthPercent,
            min: 40,
            max: 100,
            unit: '%',
            onChanged: (value) => _update((latest) => latest.copyWith(widthPercent: value), persist: false),
            onChangeEnd: (value) => _update((latest) => latest.copyWith(widthPercent: value), persist: true),
          ),
          const CustomListTile(title: '水平对齐', icon: Broken.textalign_center),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final align in FloatingLyricsAlign.values) _alignButton(align, selected: align == s.textAlign),
              ],
            ),
          ),
          CustomSwitchListTile(
            title: '单行滚动模式',
            icon: Broken.textalign_left,
            value: s.singleLine,
            onChanged: (current) => _update((latest) => latest.copyWith(singleLine: !current)),
          ),
          if (!s.singleLine)
            _FloatingLyricsSlider(
              title: '最大行数',
              icon: Broken.layer,
              value: s.maxLines.toDouble(),
              min: 2,
              max: 8,
              unit: ' 行',
              onChanged: (value) => _update((latest) => latest.copyWith(maxLines: value.round()), persist: false),
              onChangeEnd: (value) => _update((latest) => latest.copyWith(maxLines: value.round()), persist: true),
            ),
          CustomSwitchListTile(
            title: '切句过渡动画',
            icon: Broken.flash_1,
            value: s.toggleAnimation,
            onChanged: (current) => _update((latest) => latest.copyWith(toggleAnimation: !current)),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: NamidaButton(
                text: '重置悬浮窗位置',
                icon: Broken.refresh,
                onTap: _controller.resetPosition,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorButton(
    NColorsData colors, {
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
    bool followsAlbum = false,
  }) {
    return Semantics(
      label: label,
      selected: selected,
      child: NamidaButton(
        minWidth: 44,
        minHeight: 44,
        isCircle: true,
        dense: true,
        colors: selected ? NamidaButtonColors.selected : NamidaButtonColors.dimmed,
        tooltip: () => label,
        iconWidget: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: colors.onSurface.withOpacityExt(0.3)),
            shape: BoxShape.circle,
          ),
          child: followsAlbum ? const Icon(Broken.colorfilter, size: 12) : null,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _colorActions(FloatingLyricsSettings s, {required bool outline}) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        NamidaButton(
          text: 'RGB 调色',
          icon: Broken.color_swatch,
          dense: true,
          minHeight: 44,
          onTap: () => _pickRgbColor(s, outline: outline),
        ),
        NamidaButton(
          text: '图片取色',
          icon: Broken.colorfilter,
          dense: true,
          minHeight: 44,
          onTap: () => FloatingLyricsEyedropperDialog.show(
            title: outline ? '从图片选取描边色' : '从图片选取文字颜色',
            initialColor: outline ? Color(s.outlineColorArgb) : _controller.textColorFor(s),
            onPicked: (color) => unawaited(_savePickedColor(color, outline: outline)),
          ),
        ),
      ],
    ),
  );

  Future<void> _pickRgbColor(FloatingLyricsSettings s, {required bool outline}) async {
    final navigator = NamidaNavigator.inst;
    Color? picked;
    var previewActive = true;
    try {
      await navigator.navigateDialog<void>(
        dialog: NamidaColorPickerDialog(
          initialColor: outline ? Color(s.outlineColorArgb) : _controller.textColorFor(s),
          doneText: '保存',
          cancelButton: true,
          isAlphaAllowed: false,
          suggestedColors: CurrentColor.inst.palette,
          onColorChangeEnd: (color) {
            if (!previewActive) return;
            final argb = color.toARGB32();
            _controller.setColorPreview(textColorArgb: outline ? null : argb, outlineColorArgb: outline ? argb : null);
          },
          onDonePressed: (color) {
            previewActive = false;
            picked = color;
            unawaited(navigator.closeDialog());
          },
        ),
      );
      previewActive = false;
      if (picked case final color?) await _savePickedColor(color, outline: outline);
    } finally {
      previewActive = false;
      _controller.setColorPreview();
    }
  }

  Future<void> _savePickedColor(Color color, {required bool outline}) {
    final argb = color.toARGB32();
    return _update(
      (latest) => outline
          ? latest.copyWith(outlineColorArgb: argb)
          : latest.copyWith(colorPreset: FloatingLyricsColorPreset.custom, customTextColorArgb: argb),
    );
  }

  Widget _alignButton(FloatingLyricsAlign align, {required bool selected}) {
    final (text, icon) = switch (align) {
      FloatingLyricsAlign.left => ('左', Broken.textalign_left),
      FloatingLyricsAlign.center => ('中', Broken.textalign_center),
      FloatingLyricsAlign.right => ('右', Broken.textalign_right),
    };
    return Semantics(
      selected: selected,
      child: NamidaButton(
        text: text,
        icon: icon,
        minHeight: 44,
        minWidth: 52,
        tooltip: () => align.label,
        colors: selected ? NamidaButtonColors.selected : NamidaButtonColors.dimmed,
        onTap: () => _update((latest) => latest.copyWith(textAlign: align)),
      ),
    );
  }

  static const _shortcutHelp = SettingsCard(
    title: '快捷操作',
    subtitle: null,
    icon: Broken.flash_1,
    child: Padding(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NamidaText('点按悬浮窗可打开四键控制条，进行播放或暂停、锁定、打开设置和关闭操作。', style: NText.small, color: NColors.textSmall),
          SizedBox(height: 8),
          NamidaText(
            '在「播放设置 → 通知栏按钮」中可添加悬浮歌词快捷开关和锁定按钮。未配置锁定按钮时，锁定悬浮窗会显示静默解锁通知。',
            style: NText.small,
            color: NColors.textSmall,
          ),
          SizedBox(height: 8),
          NamidaText('长按 Android 系统的「正在其他应用上层显示」通知，关闭该通知类别即可永久隐藏它。', style: NText.small, color: NColors.textSmall),
        ],
      ),
    ),
  );
}

class _FloatingLyricsSlider extends StatelessWidget {
  const _FloatingLyricsSlider({
    required this.title,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String title;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final String unit;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  String _label(double value) => '${value.round()}$unit';

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CustomListTile(title: title, icon: icon, trailingRaw: NamidaText(_label(value), style: NText.small)),
      Semantics(
        label: title,
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round(),
          label: _label(value),
          semanticFormatterCallback: _label,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ),
    ],
  );
}
