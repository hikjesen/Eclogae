import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:lrc/lrc.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/romanizer/romanizer.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

import 'floating_lyrics_channel.dart';
import 'floating_lyrics_models.dart';
import 'floating_lyrics_settings_page.dart';
import 'floating_lyrics_store.dart';

typedef _OverlayLine = ({String primary, String? secondary});

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
  bool _inSettingsPreview = false;
  bool _pendingEnableAfterPermission = false;
  int _enableRequest = 0;

  Listenable? _accentColorListenable;
  Color Function()? _readAccentColor;

  List<LrcLine> _lines = const <LrcLine>[];
  Map<Duration, List<int>> _highlightTimestampsMap = const {};
  LrcLineResolver _lineResolver = LrcLineResolver.empty;
  bool _linesDirty = true;

  bool get _hasSyncedLyrics => Player.inst.currentItem.value != null && _lines.isNotEmpty;

  Future<void>? _overlayRefresh;
  bool _overlayDirty = false;
  bool _styleDirty = false;
  bool _applyPosition = false;
  ({_OverlayLine line, bool playing, bool locked, bool fallbackUnlockNotification, int colorArgb})? _shown;

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
    );

    Lyrics.inst.currentLyricsLRC.addListener(_onLyricsChanged);
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
      bodyText: '请在系统设置中允许 Namida 显示在其他应用上层，以启用悬浮歌词。',
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

  void setSettingsPreview(bool active) {
    if (_inSettingsPreview == active) return;
    _inSettingsPreview = active;
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
      romanizer: Romanizer.inst.lyricsRomanizer(lrc),
    );
    _lines = info.uiLyricsLines;
    _highlightTimestampsMap = info.highlightTimestampsMap;
    _lineResolver = info.lineResolver;
  }

  _OverlayLine _resolveLine(FloatingLyricsSettings s, bool hasSyncedLyrics) {
    final index = hasSyncedLyrics ? _lineResolver.indexAt(Player.inst.nowPlayingPosition.value) : -1;
    final line = index < 0 ? null : _lines[index];
    final primary = line?.readableText ?? '';
    final showSecondary = s.showSecondaryLine && !s.singleLine;
    if (_inSettingsPreview && primary.isEmpty) {
      return (primary: '这是一条悬浮歌词预览效果', secondary: showSecondary ? 'Floating lyrics preview subtitle' : null);
    }
    return (primary: primary, secondary: showSecondary && line != null ? _secondaryTextOf(line) : null);
  }

  String? _secondaryTextOf(LrcLine line) {
    final indices = _highlightTimestampsMap[line.timestamp];
    if (indices == null || indices.length < 2) return null;
    final secondary = <String>[];
    for (final index in indices) {
      final other = _lines[index];
      if (identical(other, line) || other.isBGLyrics || other.readableText.isEmpty) continue;
      secondary.add(other.readableText);
      if (secondary.length == 2) break;
    }
    return secondary.isEmpty ? null : secondary.join('\n');
  }

  void _onOverlayInputChanged() => unawaited(_refreshOverlay());

  void _onPlaybackPositionChanged() {
    if (_shown != null || _overlayRefresh != null) _onOverlayInputChanged();
  }

  Future<void> _refreshOverlay() {
    if (!_initialized) return Future<void>.value();
    _overlayDirty = true;
    return _overlayRefresh ??= Future<void>.microtask(() async {
      try {
        while (_overlayDirty) {
          _overlayDirty = false;
          final styleDirty = _styleDirty;
          final applyPosition = _applyPosition;
          _styleDirty = false;
          _applyPosition = false;
          await _syncOverlay(styleDirty: styleDirty, applyPosition: applyPosition);
        }
      } finally {
        _overlayRefresh = null;
      }
    });
  }

  Future<void> _syncOverlay({required bool styleDirty, required bool applyPosition}) async {
    final s = settingsNotifier.value;
    final canShow = s.enabled && hasPermissionNotifier.value;
    if (canShow && _linesDirty) {
      _loadLines();
      _linesDirty = false;
    }
    final hasSyncedLyrics = _hasSyncedLyrics;
    final shouldShow = canShow && (_inSettingsPreview || (hasSyncedLyrics && (s.showInApp || !_isAppForeground)));
    final shown = _shown;
    if (!shouldShow) {
      if (shown != null) {
        await _channel.hide();
        _shown = null;
      }
      return;
    }

    final line = _resolveLine(s, hasSyncedLyrics);
    final playing = Player.inst.playWhenReady.value;
    final fallbackUnlockNotification = !(hasLockNotificationButton?.call() ?? false);
    final colorArgb = s.colorPreset.argb ?? (_readAccentColor?.call() ?? CurrentColor.inst.miniplayerColorValue).withValues(alpha: 1.0).toARGB32();
    if (shown == null) {
      final visible = await _channel.show(
        primaryText: line.primary,
        secondaryText: line.secondary,
        isPlaying: playing,
        settings: s,
        textColorArgb: colorArgb,
        fallbackUnlockNotification: fallbackUnlockNotification,
      );
      if (!visible) return;
    } else {
      if (styleDirty || applyPosition || shown.colorArgb != colorArgb) {
        await _channel.updateStyle(
          settings: s,
          textColorArgb: colorArgb,
          fallbackUnlockNotification: fallbackUnlockNotification,
          applyPosition: applyPosition,
        );
      } else if (shown.locked != s.locked || shown.fallbackUnlockNotification != fallbackUnlockNotification) {
        await _channel.setLocked(locked: s.locked, fallbackUnlockNotification: fallbackUnlockNotification);
      }
      if (shown.line != line) await _channel.updateLine(primaryText: line.primary, secondaryText: line.secondary);
      if (shown.playing != playing) await _channel.setPlaying(playing);
    }
    _shown = (line: line, playing: playing, locked: s.locked, fallbackUnlockNotification: fallbackUnlockNotification, colorArgb: colorArgb);
  }
}
