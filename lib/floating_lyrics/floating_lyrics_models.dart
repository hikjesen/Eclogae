enum FloatingLyricsAlign {
  left('左对齐'),
  center('居中'),
  right('右对齐');

  const FloatingLyricsAlign(this.label);
  final String label;
}

enum FloatingLyricsColorPreset {
  followAlbum('跟随专辑色', null),
  white('纯白', 0xFFFFFFFF),
  mint('清新绿', 0xFF1ED760),
  sky('天空蓝', 0xFF38BDF8),
  amber('暖金黄', 0xFFFFD54F),
  coral('珊瑚粉', 0xFFFF6B8A),
  violet('紫罗兰', 0xFFC084FC),
  black('深墨黑', 0xFF141414),
  custom('自定义', null);

  const FloatingLyricsColorPreset(this.label, this.argb);
  final String label;
  final int? argb;
}

const floatingLyricsOutlinePresets = [
  (label: '黑', argb: FloatingLyricsSettings.defaultOutlineColorArgb),
  (label: '白', argb: 0xFFFFFFFF),
  (label: '深蓝', argb: 0xFF0F2942),
  (label: '酒红', argb: 0xFF4A1020),
  (label: '墨绿', argb: 0xFF0D3B2A),
  (label: '暗紫', argb: 0xFF2E1047),
  (label: '焦糖棕', argb: 0xFF432312),
];

class FloatingLyricsSettings {
  static const defaultXPercent = 7.0;
  static const defaultYPercent = 12.0;
  static const defaultPosition = (xPercent: defaultXPercent, yPercent: defaultYPercent);
  static const defaultOutlineColorArgb = 0xFF121212;

  final bool enabled;
  final bool locked;
  final bool showInApp;
  final bool showTranslation;
  final bool showRomanization;
  final bool singleLine;
  final int maxLines;
  final bool toggleAnimation;
  final double fontSizeSp;
  final double opacity;
  final double widthPercent;
  final FloatingLyricsAlign textAlign;
  final FloatingLyricsColorPreset colorPreset;
  final int customTextColorArgb;
  final bool textOutline;
  final int outlineColorArgb;
  final double xPercent;
  final double yPercent;

  const FloatingLyricsSettings({
    this.enabled = false,
    this.locked = false,
    this.showInApp = false,
    this.showTranslation = true,
    this.showRomanization = true,
    this.singleLine = false,
    int maxLines = 2,
    this.toggleAnimation = true,
    double fontSizeSp = 18.0,
    double opacity = 0.95,
    double widthPercent = 86.0,
    this.textAlign = FloatingLyricsAlign.center,
    this.colorPreset = FloatingLyricsColorPreset.followAlbum,
    this.customTextColorArgb = 0xFFFFFFFF,
    this.textOutline = true,
    this.outlineColorArgb = defaultOutlineColorArgb,
    double xPercent = defaultXPercent,
    double yPercent = defaultYPercent,
  }) : maxLines = maxLines < 2 ? 2 : (maxLines > 8 ? 8 : maxLines),
       fontSizeSp = fontSizeSp >= 8.0 ? (fontSizeSp > 34.0 ? 34.0 : fontSizeSp) : 8.0,
       opacity = opacity >= 0.2 ? (opacity > 1.0 ? 1.0 : opacity) : 0.2,
       widthPercent = widthPercent >= 40.0 ? (widthPercent > 100.0 ? 100.0 : widthPercent) : 40.0,
       xPercent = xPercent >= 0.0 ? (xPercent > 100.0 ? 100.0 : xPercent) : 0.0,
       yPercent = yPercent >= 0.0 ? (yPercent > 100.0 ? 100.0 : yPercent) : 0.0;

  FloatingLyricsSettings copyWith({
    bool? enabled,
    bool? locked,
    bool? showInApp,
    bool? showTranslation,
    bool? showRomanization,
    bool? singleLine,
    int? maxLines,
    bool? toggleAnimation,
    double? fontSizeSp,
    double? opacity,
    double? widthPercent,
    FloatingLyricsAlign? textAlign,
    FloatingLyricsColorPreset? colorPreset,
    int? customTextColorArgb,
    bool? textOutline,
    int? outlineColorArgb,
    double? xPercent,
    double? yPercent,
  }) => FloatingLyricsSettings(
    enabled: enabled ?? this.enabled,
    locked: locked ?? this.locked,
    showInApp: showInApp ?? this.showInApp,
    showTranslation: showTranslation ?? this.showTranslation,
    showRomanization: showRomanization ?? this.showRomanization,
    singleLine: singleLine ?? this.singleLine,
    maxLines: maxLines ?? this.maxLines,
    toggleAnimation: toggleAnimation ?? this.toggleAnimation,
    fontSizeSp: fontSizeSp ?? this.fontSizeSp,
    opacity: opacity ?? this.opacity,
    widthPercent: widthPercent ?? this.widthPercent,
    textAlign: textAlign ?? this.textAlign,
    colorPreset: colorPreset ?? this.colorPreset,
    customTextColorArgb: customTextColorArgb ?? this.customTextColorArgb,
    textOutline: textOutline ?? this.textOutline,
    outlineColorArgb: outlineColorArgb ?? this.outlineColorArgb,
    xPercent: xPercent ?? this.xPercent,
    yPercent: yPercent ?? this.yPercent,
  );

  factory FloatingLyricsSettings.fromJson(Map<String, dynamic> json) {
    T? read<T>(String key) {
      final value = json[key];
      return value is T ? value : null;
    }

    final legacyShowSecondaryLine = read<bool>('showSecondaryLine') ?? true;
    return const FloatingLyricsSettings().copyWith(
      enabled: read<bool>('enabled'),
      locked: read<bool>('locked'),
      showInApp: read<bool>('showInApp'),
      showTranslation: read<bool>('showTranslation') ?? legacyShowSecondaryLine,
      showRomanization: read<bool>('showRomanization') ?? legacyShowSecondaryLine,
      singleLine: read<bool>('singleLine'),
      maxLines: read<num>('maxLines')?.toInt(),
      toggleAnimation: read<bool>('toggleAnimation'),
      fontSizeSp: read<num>('fontSizeSp')?.toDouble(),
      opacity: read<num>('opacity')?.toDouble(),
      widthPercent: read<num>('widthPercent')?.toDouble(),
      textAlign: FloatingLyricsAlign.values.asNameMap()[json['textAlign']],
      colorPreset: FloatingLyricsColorPreset.values.asNameMap()[json['colorPreset']],
      customTextColorArgb: read<int>('customTextColorArgb'),
      textOutline: read<bool>('textOutline'),
      outlineColorArgb: read<int>('outlineColorArgb'),
      xPercent: read<num>('xPercent')?.toDouble(),
      yPercent: read<num>('yPercent')?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'locked': locked,
    'showInApp': showInApp,
    'showTranslation': showTranslation,
    'showRomanization': showRomanization,
    'singleLine': singleLine,
    'maxLines': maxLines,
    'toggleAnimation': toggleAnimation,
    'fontSizeSp': fontSizeSp,
    'opacity': opacity,
    'widthPercent': widthPercent,
    'textAlign': textAlign.name,
    'colorPreset': colorPreset.name,
    'customTextColorArgb': customTextColorArgb,
    'textOutline': textOutline,
    'outlineColorArgb': outlineColorArgb,
    'xPercent': xPercent,
    'yPercent': yPercent,
  };
}
