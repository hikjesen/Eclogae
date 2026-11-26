import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:lrc/lrc.dart';

import 'package:eclogae/class/route.dart';
import 'package:eclogae/controller/current_color.dart';
import 'package:eclogae/controller/lyrics_controller.dart';
import 'package:eclogae/controller/navigator_controller.dart';
import 'package:eclogae/controller/player_controller.dart';
import 'package:eclogae/controller/romanizer/romanizer.dart';
import 'package:eclogae/controller/romanizer/romanizer_engine.dart';
import 'package:eclogae/controller/settings_controller.dart';
import 'package:eclogae/core/extensions.dart';
import 'package:eclogae/core/icon_fonts/broken_icons.dart';
import 'package:eclogae/ui/widgets/custom_widgets.dart';

import 'floating_lyrics_channel.dart';
import 'floating_lyrics_models.dart';
import 'floating_lyrics_settings_page.dart';
import 'floating_lyrics_store.dart';

typedef _OverlayLine = ({String primary, String? secondary});

class _ShownOverlay {
  _ShownOverlay({
    required this.line,
    required this.playing,
    required this.locked,
    required this.fallbackUnlockNotification,
    required this.colorArgb,
    required this.suppressed,
  });

  _OverlayLine line;
  bool playing;
  bool locked;
  bool fallbackUnlockNotification;
  int colorArgb;
  bool suppressed;
}

class FloatingLyricsController {
  static final inst = FloatingLyricsController._();
  FloatingLyricsController._();

  static bool get isSupported => Platform.isAndroid;

  final settingsNotifier = ValueNotifier<FloatingLyricsSettings>(const FloatingLyricsSettings());
  final hasPermissionNotifier = ValueNotifier<bool>(false);
  bool get isEnabled => settingsNotifier.value.enabled;
  bool get isLocked => settingsNotifier.value.locked;

  bool Function()? hasLockNotificationButton;

  final _store = FloatingLyricsStore();
  final _channel = const FloatingLyricsChannel();
  Future<void>? _initialization;
  bool _initialized = false;
  bool _isAppForeground = true;
  bool _isScreenOn = true;
  bool _inSettingsPreview = false;
  bool _pendingEnableAfterPermission = false;
  int _enableRequest = 0;

  Listenable? _accentColorListenable;
  Color Function()? _readAccentColor;
  int? _textColorPreviewArgb;
  int? _outlineColorPreviewArgb;

  static final _hasLatinRegex = RegExp(r'\p{Script=Latin}', unicode: true);
  static const _OverlayLine _emptyLine = (primary: '', secondary: null);
  List<LrcLine> _lines = const <LrcLine>[];
  Map<Duration, List<int>> _highlightTimestampsMap = const {};
  LrcLineResolver _lineResolver = LrcLineResolver.empty;
  bool _lrcUsesChinese = true;
  String Function(int index, String text)? _generatedRomanizer;
  Map<num, int> _sourceIndices = const {};
  int _lastResolvedIndex = -2;
  bool _linesDirty = true;

  bool get _hasSyncedLyrics => Player.inst.currentItem.value != null && _lines.isNotEmpty;

  Future<void>? _overlayRefresh;
  bool _overlayDirty = false;
  bool _styleDirty = false;
  bool _applyPosition = false;
  _ShownOverlay? _shown;

  Future<void> init() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (!isSupported) return;
    settingsNotifier.value = await _store.load();
    hasPermissionNotifier.value = await _channel.hasPermission();
    _isAppForeground = await _channel.getAppForegroundState();
    _channel.setCallbacks(
      onPositionChanged: _savePosition,
      onAction: _onAction,
      onForegroundChanged: _onForegroundChanged,
      onScreenStateChanged: _onScreenStateChanged,
    );
    _isScreenOn = await _channel.getScreenInteractiveState();

    Lyrics.inst.currentLyricsLRC.addListener(_onLyricsChanged);
    Lyrics.inst.isResolvingLyrics.addListener(_onOverlayInputChanged);
    settings.visualDelayMS.addListener(_onLyricsChanged);
    settings.romanizeLyrics.addListener(_onLyricsChanged);
    settings.stretchLyricsDuration.addListener(_onLyricsChanged);
    Player.inst.currentItemDuration.addListener(_onLyricsChanged);
    Player.inst.currentItem.addListener(_onOverlayInputChanged);
    Player.inst.nowPlayingPosition.addListener(_onPlaybackPositionChanged);
    Player.inst.playWhenReady.addListener(_onOverlayInputChanged);
    CurrentColor.inst.currentPlayingTrack.addListener(_onOverlayInputChanged);
    settings.notificationButtons.addListener(syncNotificationButtons);

    _initialized = true;
    await _refreshOverlay();
  }

  Future<bool> setEnabled(bool enabled, {bool promptPermission = true}) async {
    if (!isSupported) return false;
    await init();
    final request = ++_enableRequest;
    if (!enabled) {
      _pendingEnableAfterPermission = false;
      await _saveEnabled(false);
      return true;
    }

    final hasPermission = await refreshPermission();
    if (request != _enableRequest) return isEnabled;
    if (!hasPermission) {
      if (promptPermission) {
        if (_isAppForeground) {
          await _showPermissionDialog();
        } else {
          _pendingEnableAfterPermission = true;
          await requestOverlayPermission();
        }
      }
      return false;
    }

    await _saveEnabled(true);
    return true;
  }

  Future<void> toggleEnabled({bool promptPermission = false}) async {
    await init();
    await setEnabled(!isEnabled, promptPermission: promptPermission);
  }

  Future<void> _saveEnabled(bool enabled) async {
    final current = settingsNotifier.value;
    final saving = current.enabled == enabled ? Future<void>.value() : _saveSettings(current.copyWith(enabled: enabled));
    final item = Player.inst.currentItem.value;
    if (enabled && item != null && Lyrics.inst.currentLyricsLRC.value == null && !Lyrics.inst.isResolvingLyrics.value) {
      unawaited(Lyrics.inst.updateLyrics(item));
    }
    await Future.wait([saving, _refreshOverlay()]);
  }

  Future<void> setLocked(bool locked) async {
    if (!isSupported) return;
    await init();
    if (isLocked == locked) return;
    await Future.wait([_saveSettings(settingsNotifier.value.copyWith(locked: locked)), _refreshOverlay()]);
  }

  Future<void> toggleLocked() async {
    await init();
    await setLocked(!isLocked);
  }

  Future<void> updateSettings(FloatingLyricsSettings next, {bool applyPosition = false, bool persist = true}) async {
    if (!isSupported) return;
    if (!_initialized) await init();
    if (next.showRomanization != settingsNotifier.value.showRomanization) _linesDirty = true;
    _lastResolvedIndex = -2;
    _styleDirty = true;
    _applyPosition = _applyPosition || applyPosition;
    settingsNotifier.value = next;
    await Future.wait([if (persist) _store.save(next), _refreshOverlay()]);
  }

  Future<void> resetPosition() async {
    await init();
    const position = FloatingLyricsSettings.defaultPosition;
    await updateSettings(settingsNotifier.value.copyWith(xPercent: position.xPercent, yPercent: position.yPercent), applyPosition: true);
  }

  Future<void> _saveSettings(FloatingLyricsSettings next) {
    _lastResolvedIndex = -2;
    settingsNotifier.value = next;
    return _store.save(next);
  }

  Future<void> _savePosition(double xPercent, double yPercent) async {
    final current = settingsNotifier.value;
    final next = current.copyWith(xPercent: xPercent, yPercent: yPercent);
    if (next.xPercent == current.xPercent && next.yPercent == current.yPercent) return;
    await _saveSettings(next);
  }

  Future<void> _showPermissionDialog() => NamidaNavigator.inst.navigateDialog<void>(
    dialog: CustomBlurryDialog(
      title: '需要悬浮窗权限',
      bodyText: '请在系统设置中允许 Eclogae 显示在其他应用上层，以启用悬浮歌词。',
      icon: Broken.layer,
      normalTitleStyle: true,
      actions: [
        const CancelButton(),
        NamidaButton(
          text: '去开启',
          onTap: () async {
            _pendingEnableAfterPermission = true;
            await NamidaNavigator.inst.closeDialog();
            await requestOverlayPermission();
          },
        ),
      ],
    ),
  );

  Future<void> requestOverlayPermission() async {
    if (!isSupported) return;
    await init();
    await _channel.requestPermission();
    await refreshPermission();
  }

  Future<bool> refreshPermission() async {
    if (!isSupported) return false;
    await init();
    final granted = await _channel.hasPermission();
    hasPermissionNotifier.value = granted;
    if (granted && _pendingEnableAfterPermission) {
      _pendingEnableAfterPermission = false;
      await _saveEnabled(true);
    } else {
      await _refreshOverlay();
    }
    return granted;
  }

  Future<void> _onForegroundChanged(bool isForeground) async {
    _isAppForeground = isForeground;
    if (isForeground) {
      await refreshPermission();
    } else {
      await _refreshOverlay();
    }
  }

  Future<void> _onScreenStateChanged(bool isScreenOn) async {
    _isScreenOn = isScreenOn;
    if (isScreenOn) {
      _lastResolvedIndex = -2;
      await _refreshOverlay();
    }
  }

  void setSettingsPreview(bool active) {
    if (_inSettingsPreview == active) return;
    _inSettingsPreview = active;
    _lastResolvedIndex = -2;
    _onOverlayInputChanged();
  }

  void openSettingsPage() {
    if (!isSupported || NamidaNavigator.inst.currentRoute is FloatingLyricsSettingsPage) return;
    unawaited(const FloatingLyricsSettingsPage().navigate());
  }

  void syncNotificationButtons() => _onOverlayInputChanged();

  void attachAccentColorSource({required Listenable listenable, required Color Function() readColor}) {
    _accentColorListenable?.removeListener(_onOverlayInputChanged);
    _accentColorListenable = listenable..addListener(_onOverlayInputChanged);
    _readAccentColor = readColor;
    _onOverlayInputChanged();
  }

  Color textColorFor(FloatingLyricsSettings s, {FloatingLyricsColorPreset? preset}) => switch (preset ?? s.colorPreset) {
    FloatingLyricsColorPreset.followAlbum => (_readAccentColor?.call() ?? CurrentColor.inst.miniplayerColorValue).withValues(alpha: 1.0),
    FloatingLyricsColorPreset.custom => Color(s.customTextColorArgb),
    final fixed => Color(fixed.argb!),
  };

  void setColorPreview({int? textColorArgb, int? outlineColorArgb}) {
    if (_textColorPreviewArgb == textColorArgb && _outlineColorPreviewArgb == outlineColorArgb) return;
    if (_outlineColorPreviewArgb != outlineColorArgb) _styleDirty = true;
    _textColorPreviewArgb = textColorArgb;
    _outlineColorPreviewArgb = outlineColorArgb;
    _lastResolvedIndex = -2;
    _onOverlayInputChanged();
  }

  Future<void> _onAction(String action) async {
    switch (action) {
      case 'togglePlayPause':
        await Player.inst.togglePlayPause().ignoreError();
      case 'lock':
        await setLocked(true);
      case 'unlock':
        await setLocked(false);
      case 'openSettings':
        openSettingsPage();
      case 'close':
        await setEnabled(false);
      default:
        throw ArgumentError.value(action, 'action', 'Unknown floating lyrics action');
    }
  }

  void _onLyricsChanged() {
    _linesDirty = true;
    _onOverlayInputChanged();
  }

  void _loadLines() {
    _lastResolvedIndex = -2;
    _generatedRomanizer = null;
    _sourceIndices = const {};
    final lrc = Lyrics.inst.currentLyricsLRC.value;
    if (lrc == null) {
      _lines = const <LrcLine>[];
      _highlightTimestampsMap = const {};
      _lineResolver = LrcLineResolver.empty;
      return;
    }
    final info = lrc.forUiDisplay(
      Lyrics.inst.getStretchMultiplier(lrc),
      durationDifferenceToInsertEmptyLine: const Duration(seconds: 1),
      extraOffsetDuration: Duration(milliseconds: settings.visualDelayMS.value),
    );
    _lines = info.uiLyricsLines;
    _highlightTimestampsMap = info.highlightTimestampsMap;
    _lineResolver = info.lineResolver;

    var scripts = 0;
    for (final line in lrc.lyrics) {
      scripts |= RomanizerEngine.scriptsOf(line.readableText);
    }
    _lrcUsesChinese = !RomanizerEngine.scriptsHaveKana(scripts);
    if (settingsNotifier.value.showRomanization) {
      _generatedRomanizer = Romanizer.inst.lyricsRomanizer(lrc);
      if (_generatedRomanizer != null) {
        // Display indices can shift when forUiDisplay inserts a gap line.
        _sourceIndices = {for (final (index, line) in lrc.lyrics.indexed) line.originalIndex: index};
      }
    }
  }

  _OverlayLine _resolveLine(FloatingLyricsSettings s, bool hasSyncedLyrics) {
    final index = hasSyncedLyrics ? _lineResolver.indexAt(Player.inst.nowPlayingPosition.value) : -1;
    _lastResolvedIndex = index;
    var line = index < 0 ? null : _lines[index];
    if (line != null && line.isBGLyrics) {
      for (final siblingIndex in _highlightTimestampsMap[line.timestamp]!) {
        final sibling = _lines[siblingIndex];
        if (sibling.isBGLyrics) continue;
        line = sibling;
        break;
      }
    }
    final primary = line?.readableText ?? '';
    if (_inSettingsPreview && primary.isEmpty) {
      final secondary = [
        if (!s.singleLine && s.showTranslation) 'Floating lyrics translation preview',
        if (!s.singleLine && s.showRomanization) 'zhe shi yi tiao xuan fu ge ci yu lan',
      ];
      return (primary: '这是一条悬浮歌词预览效果', secondary: secondary.isEmpty ? null : secondary.join('\n'));
    }
    if (!hasSyncedLyrics && Lyrics.inst.isResolvingLyrics.value) return _shown?.line ?? _emptyLine;
    final showSecondary = !s.singleLine && (s.showTranslation || s.showRomanization);
    return (primary: primary, secondary: showSecondary && line != null && primary.isNotEmpty ? _secondaryTextOf(line, s) : null);
  }

  String? _secondaryTextOf(LrcLine line, FloatingLyricsSettings s) {
    final primary = line.readableText;
    final canRomanize = RomanizerEngine.needsRomanization(primary);
    final siblings = <String>[];
    for (final index in _highlightTimestampsMap[line.timestamp]!) {
      final other = _lines[index];
      if (identical(other, line) || other.isBGLyrics || other.readableText.isEmpty) continue;
      siblings.add(other.readableText);
    }
    final hasNonLatinSibling = canRomanize && siblings.length >= 2 && siblings.any(RomanizerEngine.needsRomanization);
    final secondary = <String>[];
    final romanizations = <String>[];
    for (final text in siblings) {
      final isRomanization =
          canRomanize &&
          _hasLatinRegex.hasMatch(text) &&
          !RomanizerEngine.needsRomanization(text) &&
          (hasNonLatinSibling || Romanizer.inst.isRomanizationMatch(primary, text, chinese: _lrcUsesChinese));
      if (isRomanization) {
        if (s.showRomanization) romanizations.add(text);
      } else if (s.showTranslation) {
        secondary.add(text);
      }
    }
    final generate = _generatedRomanizer;
    if (canRomanize && s.showRomanization && romanizations.isEmpty && generate != null) {
      final generated = generate(_sourceIndices[line.originalIndex]!, primary);
      if (generated.isNotEmpty && generated != primary) romanizations.add(generated);
    }
    secondary.addAll(romanizations);
    return secondary.isEmpty ? null : secondary.take(3).join('\n');
  }

  void _onOverlayInputChanged() => unawaited(_refreshOverlay());

  void _onPlaybackPositionChanged() {
    final shown = _shown;
    if (!_isScreenOn || shown == null || shown.suppressed || _lines.isEmpty) return;
    final index = _lineResolver.indexAt(Player.inst.nowPlayingPosition.value);
    if (index == _lastResolvedIndex) return;
    _onOverlayInputChanged();
  }

  Future<void> _refreshOverlay() {
    if (!_initialized) return Future<void>.value();
    _overlayDirty = true;
    return _overlayRefresh ??= Future<void>.microtask(() async {
      try {
        while (_overlayDirty) {
          _overlayDirty = false;
          await _syncOverlay();
        }
      } finally {
        _overlayRefresh = null;
      }
    });
  }

  Future<void> _syncOverlay() async {
    final s = settingsNotifier.value;
    final shouldAttach = s.enabled && hasPermissionNotifier.value;
    final shown = _shown;
    if (!shouldAttach) {
      if (shown != null) {
        await _channel.hide();
        _shown = null;
      }
      return;
    }
    if (_linesDirty) {
      _loadLines();
      _linesDirty = false;
    }

    final hasSyncedLyrics = _hasSyncedLyrics;
    final hasDisplayableLyrics = hasSyncedLyrics || Lyrics.inst.isResolvingLyrics.value;
    final suppressed = !(_inSettingsPreview || (hasDisplayableLyrics && (s.showInApp || !_isAppForeground)));
    final fallbackUnlockNotification = !(hasLockNotificationButton?.call() ?? false);
    final colorArgb = _textColorPreviewArgb ?? textColorFor(s).toARGB32();
    final outlinePreview = _outlineColorPreviewArgb;
    final style = outlinePreview == null ? s : s.copyWith(outlineColorArgb: outlinePreview);
    if (shown == null) {
      final line = !suppressed && _isScreenOn ? _resolveLine(s, hasSyncedLyrics) : _emptyLine;
      final playing = Player.inst.playWhenReady.value;
      _styleDirty = false;
      _applyPosition = false;
      final attached = await _channel.show(
        primaryText: line.primary,
        secondaryText: line.secondary,
        isPlaying: playing,
        settings: style,
        textColorArgb: colorArgb,
        fallbackUnlockNotification: fallbackUnlockNotification,
        suppressed: suppressed,
      );
      if (attached) {
        _shown = _ShownOverlay(
          line: line,
          playing: playing,
          locked: s.locked,
          fallbackUnlockNotification: fallbackUnlockNotification,
          colorArgb: colorArgb,
          suppressed: suppressed,
        );
        if (!suppressed && _isScreenOn && hasSyncedLyrics) {
          // Playback may have advanced while show was awaiting the native window.
          _onPlaybackPositionChanged();
        }
      }
      return;
    }

    final suppressionChanged = shown.suppressed != suppressed;
    final styleChanged = _styleDirty || shown.colorArgb != colorArgb;
    if (styleChanged && (suppressionChanged || (!suppressed && _isScreenOn))) {
      final applyPosition = _applyPosition;
      _styleDirty = false;
      _applyPosition = false;
      await _channel.updateStyle(
        settings: style,
        textColorArgb: colorArgb,
        fallbackUnlockNotification: fallbackUnlockNotification,
        suppressed: suppressed,
        applyPosition: applyPosition,
      );
      shown.colorArgb = colorArgb;
      shown.locked = s.locked;
      shown.suppressed = suppressed;
      shown.fallbackUnlockNotification = fallbackUnlockNotification;
    } else if (suppressionChanged) {
      await _channel.setSuppressed(suppressed: suppressed, fallbackUnlockNotification: fallbackUnlockNotification);
      shown.suppressed = suppressed;
      shown.fallbackUnlockNotification = fallbackUnlockNotification;
    }

    if (suppressed || !_isScreenOn) return;
    if (shown.locked != s.locked || shown.fallbackUnlockNotification != fallbackUnlockNotification) {
      await _channel.setLocked(locked: s.locked, fallbackUnlockNotification: fallbackUnlockNotification);
      shown.locked = s.locked;
      shown.fallbackUnlockNotification = fallbackUnlockNotification;
    }
    if (!_isScreenOn) return;
    final line = _resolveLine(s, hasSyncedLyrics);
    if (shown.line != line) {
      await _channel.updateLine(primaryText: line.primary, secondaryText: line.secondary);
      shown.line = line;
    }
    final playing = Player.inst.playWhenReady.value;
    if (_isScreenOn && shown.playing != playing) {
      await _channel.setPlaying(playing);
      shown.playing = playing;
    }
  }
}
