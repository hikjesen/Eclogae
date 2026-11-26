import 'dart:io';

import 'package:flutter/services.dart';

import 'floating_lyrics_models.dart';

class FloatingLyricsChannel {
  const FloatingLyricsChannel();

  static const _channel = MethodChannel('eclogae/floating_lyrics');

  Future<bool> hasPermission() => _invokeBool('hasPermission');

  Future<bool> requestPermission() => _invokeBool('requestPermission');

  Future<bool> getAppForegroundState() => _invokeBool('getAppForegroundState');

  Future<bool> getScreenInteractiveState() => _invokeBool('getScreenInteractiveState');

  Future<bool> show({
    required String primaryText,
    required String? secondaryText,
    required bool isPlaying,
    required FloatingLyricsSettings settings,
    required int textColorArgb,
    required bool fallbackUnlockNotification,
    required bool suppressed,
  }) => _invokeBool('show', {
    'primaryText': primaryText,
    'secondaryText': secondaryText,
    'isPlaying': isPlaying,
    ..._styleArguments(settings, textColorArgb, fallbackUnlockNotification, suppressed),
  });

  Future<void> hide() => _invokeVoid('hide');

  Future<void> setSuppressed({required bool suppressed, required bool fallbackUnlockNotification}) =>
      _invokeVoid('setSuppressed', {'suppressed': suppressed, 'fallbackUnlockNotification': fallbackUnlockNotification});

  Future<void> updateStyle({
    required FloatingLyricsSettings settings,
    required int textColorArgb,
    required bool fallbackUnlockNotification,
    required bool suppressed,
    required bool applyPosition,
  }) => _invokeVoid('updateStyle', {
    ..._styleArguments(settings, textColorArgb, fallbackUnlockNotification, suppressed),
    'applyPosition': applyPosition,
  });

  Future<void> updateLine({required String primaryText, required String? secondaryText}) =>
      _invokeVoid('updateLine', {'primaryText': primaryText, 'secondaryText': secondaryText});

  Future<void> setPlaying(bool isPlaying) => _invokeVoid('setPlaying', {'isPlaying': isPlaying});

  Future<void> setLocked({required bool locked, required bool fallbackUnlockNotification}) =>
      _invokeVoid('setLocked', {'locked': locked, 'fallbackUnlockNotification': fallbackUnlockNotification});

  void setCallbacks({
    required Future<void> Function(double xPercent, double yPercent) onPositionChanged,
    required Future<void> Function(String action) onAction,
    required Future<void> Function(bool isForeground) onForegroundChanged,
    required Future<void> Function(bool isScreenOn) onScreenStateChanged,
  }) {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPositionChanged':
          if (call.arguments case {'xPercent': final num x, 'yPercent': final num y} when x.isFinite && y.isFinite) {
            await onPositionChanged(x.toDouble(), y.toDouble());
          } else {
            throw PlatformException(code: 'invalid_position', message: 'Expected finite xPercent and yPercent.');
          }
        case 'onAction':
          await onAction(call.arguments as String);
        case 'onForegroundChanged':
          await onForegroundChanged(call.arguments as bool);
        case 'onScreenStateChanged':
          await onScreenStateChanged(call.arguments as bool);
        default:
          throw MissingPluginException('Unknown floating lyrics callback: ${call.method}');
      }
    });
  }

  Future<bool> _invokeBool(String method, [Map<String, Object?>? args]) async {
    if (!Platform.isAndroid) return false;
    return (await _channel.invokeMethod<bool>(method, args))!;
  }

  Future<void> _invokeVoid(String method, [Map<String, Object?>? args]) async {
    if (Platform.isAndroid) await _channel.invokeMethod<void>(method, args);
  }

  Map<String, Object> _styleArguments(FloatingLyricsSettings settings, int textColorArgb, bool fallbackUnlockNotification, bool suppressed) => {
    'locked': settings.locked,
    'fallbackUnlockNotification': fallbackUnlockNotification,
    'singleLine': settings.singleLine,
    'maxLines': settings.maxLines,
    'toggleAnimation': settings.toggleAnimation,
    'fontSizeSp': settings.fontSizeSp,
    'opacity': settings.opacity,
    'widthPercent': settings.widthPercent,
    'textAlign': settings.textAlign.name,
    'textColorArgb': textColorArgb,
    'textOutline': settings.textOutline,
    'outlineColorArgb': settings.outlineColorArgb,
    'suppressed': suppressed,
    'xPercent': settings.xPercent,
    'yPercent': settings.yPercent,
  };
}
