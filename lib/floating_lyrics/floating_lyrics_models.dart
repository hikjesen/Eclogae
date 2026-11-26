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
  black('深墨黑', 0xFF141414);

  const FloatingLyricsColorPreset(this.label, this.argb);
  final String label;
  final int? argb;
}

class FloatingLyricsSettings {
  static const defaultXPercent = 7.0;
  static const defaultYPercent = 12.0;
  static const defaultPosition = (xPercent: defaultXPercent, yPercent: defaultYPercent);

  final bool enabled;
  final bool locked;
  final bool showInApp;
  final bool showSecondaryLine;
  final bool singleLine;
  final int maxLines;
  final bool toggleAnimation;
  final double fontSizeSp;
  final double opacity;
  final double widthPercent;
  final FloatingLyricsAlign textAlign;
  final FloatingLyricsColorPreset colorPreset;
  final bool textOutline;
  final double xPercent;
  final double yPercent;

  const FloatingLyricsSettings({
    this.enabled = false,
    this.locked = false,
    this.showInApp = false,
    this.showSecondaryLine = true,
    this.singleLine = false,
    int maxLines = 2,
    this.toggleAnimation = true,
    double fontSizeSp = 18.0,
    double opacity = 0.95,
    double widthPercent = 86.0,
    this.textAlign = FloatingLyricsAlign.center,
    this.colorPreset = FloatingLyricsColorPreset.followAlbum,
    this.textOutline = true,
    double xPercent = defaultXPercent,
    double yPercent = defaultYPercent,
  }) : maxLines = maxLines < 2 ? 2 : (maxLines > 6 ? 6 : maxLines),
       fontSizeSp = fontSizeSp >= 12.0 ? (fontSizeSp > 34.0 ? 34.0 : fontSizeSp) : 12.0,
       opacity = opacity >= 0.2 ? (opacity > 1.0 ? 1.0 : opacity) : 0.2,
       widthPercent = widthPercent >= 40.0 ? (widthPercent > 100.0 ? 100.0 : widthPercent) : 40.0,
       xPercent = xPercent >= 0.0 ? (xPercent > 100.0 ? 100.0 : xPercent) : 0.0,
       yPercent = yPercent >= 0.0 ? (yPercent > 100.0 ? 100.0 : yPercent) : 0.0;

  FloatingLyricsSettings copyWith({
    bool? enabled,
    bool? locked,
    bool? showInApp,
    bool? showSecondaryLine,
    bool? singleLine,
    int? maxLines,
    bool? toggleAnimation,
    double? fontSizeSp,
    double? opacity,
    double? widthPercent,
    FloatingLyricsAlign? textAlign,
    FloatingLyricsColorPreset? colorPreset,
    bool? textOutline,
    double? xPercent,
    double? yPercent,
  }) => FloatingLyricsSettings(
    enabled: enabled ?? this.enabled,
    locked: locked ?? this.locked,
    showInApp: showInApp ?? this.showInApp,
    showSecondaryLine: showSecondaryLine ?? this.showSecondaryLine,
    singleLine: singleLine ?? this.singleLine,
    maxLines: maxLines ?? this.maxLines,
    toggleAnimation: toggleAnimation ?? this.toggleAnimation,
    fontSizeSp: fontSizeSp ?? this.fontSizeSp,
    opacity: opacity ?? this.opacity,
    widthPercent: widthPercent ?? this.widthPercent,
    textAlign: textAlign ?? this.textAlign,
    colorPreset: colorPreset ?? this.colorPreset,
    textOutline: textOutline ?? this.textOutline,
    xPercent: xPercent ?? this.xPercent,
    yPercent: yPercent ?? this.yPercent,
  );

  factory FloatingLyricsSettings.fromJson(Map<String, dynamic> json) {
    T? read<T>(String key) {
      final value = json[key];
      return value is T ? value : null;
    }

    return const FloatingLyricsSettings().copyWith(
      enabled: read<bool>('enabled'),
      locked: read<bool>('locked'),
      showInApp: read<bool>('showInApp'),
      showSecondaryLine: read<bool>('showSecondaryLine'),
      singleLine: read<bool>('singleLine'),
      maxLines: read<num>('maxLines')?.toInt(),
      toggleAnimation: read<bool>('toggleAnimation'),
      fontSizeSp: read<num>('fontSizeSp')?.toDouble(),
      opacity: read<num>('opacity')?.toDouble(),
      widthPercent: read<num>('widthPercent')?.toDouble(),
      textAlign: FloatingLyricsAlign.values.asNameMap()[json['textAlign']],
      colorPreset: FloatingLyricsColorPreset.values.asNameMap()[json['colorPreset']],
      textOutline: read<bool>('textOutline'),
      xPercent: read<num>('xPercent')?.toDouble(),
      yPercent: read<num>('yPercent')?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'locked': locked,
    'showInApp': showInApp,
    'showSecondaryLine': showSecondaryLine,
    'singleLine': singleLine,
    'maxLines': maxLines,
    'toggleAnimation': toggleAnimation,
    'fontSizeSp': fontSizeSp,
    'opacity': opacity,
    'widthPercent': widthPercent,
    'textAlign': textAlign.name,
    'colorPreset': colorPreset.name,
    'textOutline': textOutline,
    'xPercent': xPercent,
    'yPercent': yPercent,
  };
}
