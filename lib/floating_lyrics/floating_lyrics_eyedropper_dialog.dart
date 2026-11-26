import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:eclogae/class/track.dart';
import 'package:eclogae/controller/file_browser.dart';
import 'package:eclogae/controller/logs_controller.dart';
import 'package:eclogae/controller/navigator_controller.dart';
import 'package:eclogae/controller/platform/namida_storage/namida_storage.dart';
import 'package:eclogae/controller/player_controller.dart';
import 'package:eclogae/core/icon_fonts/broken_icons.dart';
import 'package:eclogae/lx_music/lx_preview_player.dart';
import 'package:eclogae/ui/widgets/custom_widgets.dart';

class FloatingLyricsEyedropperDialog extends StatefulWidget {
  const FloatingLyricsEyedropperDialog._({required this.title, required this.initialColor, required this.onPicked});

  final String title;
  final Color initialColor;
  final ValueChanged<Color> onPicked;

  static Future<void> show({required String title, required Color initialColor, required ValueChanged<Color> onPicked}) =>
      NamidaNavigator.inst.navigateDialog<void>(
        dialog: FloatingLyricsEyedropperDialog._(title: title, initialColor: initialColor, onPicked: onPicked),
      );

  @override
  State<FloatingLyricsEyedropperDialog> createState() => _FloatingLyricsEyedropperDialogState();
}

class _FloatingLyricsEyedropperDialogState extends State<FloatingLyricsEyedropperDialog> {
  ({ui.Image image, ByteData rgba})? _artwork;
  late Color _color = widget.initialColor;
  Offset? _sample;
  bool _loading = false;
  String? _loadError;
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadImage(_readCurrentArtwork));
  }

  @override
  void dispose() {
    _artwork?.image.dispose();
    super.dispose();
  }

  Future<Uint8List?> _readCurrentArtwork() async {
    final item = Player.inst.currentItem.value;
    if (item is! Selectable) return null;
    final track = item.track;
    if (LxPreviewPlayer.isPreviewPath(track.path)) return LxPreviewPlayer.inst.fetchArtworkBytes(track.path);
    final path = track.pathToImage;
    if (path.isEmpty) return null;
    final file = File(path);
    return await file.exists() ? file.readAsBytes() : null;
  }

  Future<void> _pickLocalImage() async {
    final file = await NamidaFileBrowser.pickFile(note: '选择要取色的图片', memeType: NamidaStorageFileMemeType.image);
    if (mounted && file != null) await _loadImage(file.readAsBytes);
  }

  Future<void> _loadImage(Future<Uint8List?> Function() readBytes) async {
    final request = ++_loadRequest;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    ui.ImmutableBuffer? buffer;
    ui.Codec? codec;
    ui.Image? decoded;
    try {
      final bytes = await readBytes();
      if (bytes == null || !mounted || request != _loadRequest) return;
      const maxSide = 720;
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (width, height) {
          if (width >= height && width > maxSide) return const ui.TargetImageSize(width: maxSide);
          if (height > maxSide) return const ui.TargetImageSize(height: maxSide);
          return const ui.TargetImageSize();
        },
      );
      final image = (await codec.getNextFrame()).image;
      decoded = image;
      if (!mounted || request != _loadRequest) return;
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) throw StateError('Could not read decoded image pixels');
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _artwork?.image.dispose();
        _artwork = (image: image, rgba: rgba);
        _sample = null;
      });
      decoded = null;
    } catch (error, stack) {
      logger.error('悬浮歌词图片取色：读取或解码图片失败', e: error, st: stack);
      if (mounted && request == _loadRequest) {
        setState(() => _loadError = '无法读取或解码图片，请选择另一张图片。');
      }
    } finally {
      codec?.dispose();
      buffer?.dispose();
      decoded?.dispose();
      if (mounted && request == _loadRequest) setState(() => _loading = false);
    }
  }

  void _sampleAt(Offset position, Rect imageRect, ui.Image image, ByteData rgba) {
    if (!imageRect.contains(position)) return;
    final x = (position.dx - imageRect.left) * image.width / imageRect.width;
    final y = (position.dy - imageRect.top) * image.height / imageRect.height;
    final px = x.floor().clamp(0, image.width - 1);
    final py = y.floor().clamp(0, image.height - 1);
    final offset = (py * image.width + px) * 4;
    final alpha = rgba.getUint8(offset + 3);
    if (alpha == 0) return;
    // rawRgba stores premultiplied channels.
    int channel(int index) => (rgba.getUint8(offset + index) * 255 / alpha).round().clamp(0, 255);
    setState(() {
      _color = Color.fromARGB(255, channel(0), channel(1), channel(2));
      _sample = Offset((px + 0.5) / image.width, (py + 0.5) / image.height);
    });
  }

  Widget _imageCanvas(ui.Image image, ByteData rgba) => LayoutBuilder(
    builder: (context, constraints) {
      final canvasSize = constraints.biggest;
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final fitted = applyBoxFit(BoxFit.contain, imageSize, canvasSize);
      final imageRect = Alignment.center.inscribe(fitted.destination, Offset.zero & canvasSize);
      final sample = _sample;
      const markerSize = 24.0;
      return Semantics(
        label: '取色图片',
        hint: '点按或拖动选择颜色',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _sampleAt(details.localPosition, imageRect, image, rgba),
          onPanStart: (details) => _sampleAt(details.localPosition, imageRect, image, rgba),
          onPanUpdate: (details) => _sampleAt(details.localPosition, imageRect, image, rgba),
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              RawImage(image: image, fit: BoxFit.contain),
              if (sample != null)
                Positioned(
                  left: imageRect.left + sample.dx * imageRect.width - markerSize / 2,
                  top: imageRect.top + sample.dy * imageRect.height - markerSize / 2,
                  width: markerSize,
                  height: markerSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black, spreadRadius: 1)],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final artwork = _artwork;
    final error = _loadError;
    final argb = _color.toARGB32();
    final hex = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
    final red = (argb >> 16) & 0xFF;
    final green = (argb >> 8) & 0xFF;
    final blue = argb & 0xFF;
    final theme = Theme.of(context);
    return CustomBlurryDialog(
      title: widget.title,
      icon: Broken.colorfilter,
      normalTitleStyle: true,
      actions: [
        const CancelButton(),
        NamidaButton(
          text: '使用此颜色',
          enabled: _sample != null && !_loading,
          onTap: () {
            widget.onPicked(_color);
            unawaited(NamidaNavigator.inst.closeDialog());
          },
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (artwork != null)
            SizedBox(
              height: math.min(300.0, MediaQuery.sizeOf(context).height * 0.4),
              child: _imageCanvas(artwork.image, artwork.rgba),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(semanticsLabel: '正在加载图片'),
            )
          else if (artwork == null && error == null)
            const Text('暂无当前歌曲封面，可选择本地图片取色。', textAlign: TextAlign.center),
          if (error != null) Text(error, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _color,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.outline),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(child: Text('#$hex\nRGB($red, $green, $blue)')),
            ],
          ),
          const SizedBox(height: 12),
          NamidaButton(
            text: artwork == null ? '选择本地图片' : '从本地图片取色',
            icon: Broken.colorfilter,
            dense: true,
            minHeight: 44,
            onTap: _pickLocalImage,
          ),
        ],
      ),
    );
  }
}
