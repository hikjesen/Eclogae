import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:eclogae/class/track.dart';
import 'package:eclogae/controller/navigator_controller.dart';
import 'package:eclogae/core/extensions.dart';
import 'package:eclogae/core/icon_fonts/broken_icons.dart';
import 'package:eclogae/core/ntheme.dart';
import 'package:eclogae/ui/widgets/custom_widgets.dart';

import '../lx_bridge_service.dart';
import '../lx_models.dart';
import 'lx_cover_thumb.dart';

class LxLyricsSheet extends StatefulWidget {
  const LxLyricsSheet._({
    required this.track,
    required this.onDownload,
    required this.onChooseQualityDownload,
    required this.onPlay,
  });

  static Future<void> show({
    required LxTrack track,
    Track? playableTrack,
    required VoidCallback onDownload,
    required VoidCallback onChooseQualityDownload,
    void Function(Track track)? onPlay,
  }) async {
    final action = await NamidaNavigator.inst.showSheet<VoidCallback>(
      isScrollControlled: true,
      heightPercentage: 0.80,
      showDragHandle: true,
      builder: (_, _, _, _) => LxLyricsSheet._(
        track: track,
        onDownload: onDownload,
        onChooseQualityDownload: onChooseQualityDownload,
        onPlay: playableTrack != null && onPlay != null ? () => onPlay(playableTrack) : null,
      ),
    );
    action?.call();
  }

  final LxTrack track;
  final VoidCallback onDownload;
  final VoidCallback onChooseQualityDownload;
  final VoidCallback? onPlay;

  @override
  State<LxLyricsSheet> createState() => _LxLyricsSheetState();
}

enum _LyricMode {
  bilingual('双语'),
  original('原文'),
  translation('翻译'),
  romanization('罗马音'),
  raw('原 LRC');

  const _LyricMode(this.label);

  final String label;
}

class _LxLyricsSheetState extends State<LxLyricsSheet> {
  final _searchController = TextEditingController();
  late Future<_SheetLyrics> _request;
  _LyricMode? _mode;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _request = _fetchLyrics();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_SheetLyrics> _fetchLyrics() async => _SheetLyrics(await LxBridgeService.inst.fetchLyric(track: widget.track));

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) snackyy(icon: Broken.copy_success, message: '已复制歌词');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SheetLyrics>(
      future: _request,
      builder: (context, snapshot) {
        final List<Widget> body;
        if (snapshot.connectionState == ConnectionState.waiting) {
          body = const [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator(semanticsLabel: '正在加载歌词')),
            ),
          ];
        } else if (snapshot.hasError) {
          body = [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  NamidaText('歌词加载失败：${snapshot.error}', style: NText.small, color: NColors.error, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  NamidaButton(text: '重试', icon: Broken.refresh, dense: true, onTap: () => setState(() => _request = _fetchLyrics())),
                ],
              ),
            ),
          ];
        } else {
          body = _lyricsPanel(context, snapshot.requireData);
        }
        return SuperSmoothListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          children: [_trackHeader(context), ...body],
        );
      },
    );
  }

  List<Widget> _lyricsPanel(BuildContext context, _SheetLyrics lyrics) {
    if (lyrics.isEmpty) return const [_LyricMessage('该曲目暂无歌词')];
    final colors = NColorsData.of(context);
    final modes = lyrics.modes;
    final mode = _mode ?? modes.first;
    final query = _searchController.text.trim().toLowerCase();
    bool matches(String line) => line.toLowerCase().contains(query);
    final emptyMessage = query.isEmpty ? '该曲目暂无歌词' : '没有匹配的歌词';

    if (mode == _LyricMode.raw) {
      final raw = query.isEmpty ? lyrics.raw : const LineSplitter().convert(lyrics.raw).where(matches).join('\n');
      return [
        _controls(colors, modes, mode, raw.trim().isEmpty ? '' : raw),
        if (raw.trim().isEmpty)
          _LyricMessage(emptyMessage)
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SelectableText(raw, style: NText.small.of(context).copyWith(color: colors.onSurface)),
          ),
      ];
    }

    final blocks = lyrics.blocks[mode]!.where((block) => block.original.any(matches) || block.companions.any(matches)).toList();
    final displayedText = [
      for (final block in blocks) ...[...block.original, ...block.companions],
    ].join('\n');
    return [
      _controls(colors, modes, mode, displayedText),
      if (blocks.isEmpty) _LyricMessage(emptyMessage),
      for (final block in blocks)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in block.original) NamidaText(line, style: NText.medium),
              for (final line in block.companions)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: NamidaText(line, style: NText.small, color: const NColors(.onSurface, opacity: 0.66)),
                ),
            ],
          ),
        ),
    ];
  }

  Widget _trackHeader(BuildContext context) {
    final track = widget.track;
    final artistAlbum = [track.singer, track.albumName].where((part) => part.isNotEmpty).join(' · ');
    final play = widget.onPlay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NContainer(
          padding: const EdgeInsets.all(10),
          decoration: (colors) => BoxDecoration(
            color: colors.card.withOpacityExt(0.62),
            borderRadius: BorderRadius.circular(14.0.multipliedRadius),
            border: Border.all(color: colors.onSurface.withOpacityExt(0.08)),
          ),
          child: Row(
            children: [
              LxCoverThumb(url: track.picUrl, size: 58),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NamidaText(track.name, style: const NText(.large, size: .s17), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (artistAlbum.isNotEmpty)
                      NamidaText(artistAlbum, style: NText.small, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        NContainer(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: (colors) => BoxDecoration(
                            color: colors.secondaryContainer.withOpacityExt(0.55),
                            borderRadius: BorderRadius.circular(7.0.multipliedRadius),
                          ),
                          child: NamidaText(track.source.label, style: const NText(.small, size: .s11)),
                        ),
                        if (track.interval.isNotEmpty) NamidaText(track.interval, style: const NText(.small, size: .s11)),
                        for (final quality in track.qualities) LxQualityBadge(quality: quality),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            NamidaButton(text: '下载', icon: Broken.document_download, dense: true, onTap: () => Navigator.of(context).pop(widget.onDownload)),
            NamidaButton(text: '选择音质', icon: Broken.slider_horizontal, dense: true, onTap: () => Navigator.of(context).pop(widget.onChooseQualityDownload)),
            if (play != null) NamidaButton(text: '立即播放', icon: Broken.play, dense: true, onTap: () => Navigator.of(context).pop(play)),
          ],
        ),
        const NamidaContainerDivider(margin: EdgeInsets.symmetric(vertical: 8)),
      ],
    );
  }

  Widget _controls(NColorsData colors, List<_LyricMode> modes, _LyricMode mode, String displayedText) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 5,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final item in modes)
              Semantics(
                selected: mode == item,
                child: NamidaInkWell(
                  borderRadius: 10.0,
                  bgColor: NColors.fixed(mode == item ? colors.primary.withOpacityExt(0.15) : colors.onSurface.withOpacityExt(0.05)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  onTap: () => setState(() => _mode = item),
                  child: NamidaText(item.label, style: const NText(.small, size: .s12), color: mode == item ? NColors.primary : NColors.onSurface),
                ),
              ),
            NamidaIconButton(
              icon: Broken.search_normal_1,
              iconSize: 17,
              iconColor: _showSearch ? NColors.primary : null,
              verticalPadding: 8,
              tooltip: () => _showSearch ? '关闭歌词搜索' : '搜索歌词',
              onPressed: () => setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) _searchController.clear();
              }),
            ),
            NamidaButton(
              text: '复制',
              icon: Broken.copy,
              dense: true,
              enabled: displayedText.isNotEmpty,
              onTap: () => _copy(displayedText),
            ),
          ],
        ),
        if (_showSearch)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: NText.small.of(context),
              decoration: InputDecoration(
                labelText: '搜索歌词',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0.multipliedRadius)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
      ],
    ),
  );
}

class _LyricMessage extends StatelessWidget {
  const _LyricMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: NamidaText(message, style: NText.small, textAlign: TextAlign.center),
  );
}

typedef _LyricLine = ({List<int> times, String text});
typedef _LyricBlock = ({Set<String> original, Set<String> companions});

class _SheetLyrics {
  _SheetLyrics(LxLyricResult result) : raw = result.lyric {
    final original = _parse(result.lyric);
    final translation = _parse(result.tlyric ?? '');
    final romanization = _parse(result.rlyric ?? '');
    final hasCompanions = translation.isNotEmpty || romanization.isNotEmpty;
    blocks = {
      if (hasCompanions) _LyricMode.bilingual: _align([original, translation, romanization]),
      _LyricMode.original: _plainBlocks(original),
      if (translation.isNotEmpty) _LyricMode.translation: _plainBlocks(translation),
      if (romanization.isNotEmpty) _LyricMode.romanization: _plainBlocks(romanization),
    };
  }

  static final _timestamp = RegExp(r'\[(\d{1,4}):([0-5]\d)(?:[.:](\d{1,3}))?\]');
  static final _metadata = RegExp(r'^(?:\[[a-z][a-z\d_-]*:[^\]]*\]\s*)+$', caseSensitive: false);

  final String raw;
  late final Map<_LyricMode, List<_LyricBlock>> blocks;

  bool get isEmpty => blocks.values.every((lines) => lines.isEmpty);
  List<_LyricMode> get modes => [...blocks.keys, _LyricMode.raw];

  static List<_LyricLine> _parse(String lrc) {
    final lines = <_LyricLine>[];
    for (final rawLine in const LineSplitter().convert(lrc)) {
      final line = rawLine.trim();
      final times = <int>[];
      var end = 0;
      for (final stamp in _timestamp.allMatches(line)) {
        if (stamp.start != end) break;
        final seconds = int.parse(stamp[1]!) * 60 + int.parse(stamp[2]!);
        times.add(seconds * 1000 + int.parse(stamp[3]?.padRight(3, '0') ?? '0'));
        end = stamp.end;
      }
      final text = line.substring(end).trim();
      if (text.isEmpty || _metadata.hasMatch(text)) continue;
      lines.add((times: times, text: text));
    }
    return lines;
  }

  static List<_LyricBlock> _plainBlocks(List<_LyricLine> lines) => [
    for (final line in lines) (original: {line.text}, companions: const <String>{}),
  ];

  static List<_LyricBlock> _align(List<List<_LyricLine>> versions) {
    final timed = SplayTreeMap<int, _LyricBlock>();
    final untimed = <_LyricBlock>[];
    for (final (index, version) in versions.indexed) {
      final isOriginal = index == 0;
      for (final line in version) {
        final times = line.times;
        if (times.isEmpty) untimed.add((original: <String>{}, companions: <String>{}));
        for (final block in times.isEmpty
            ? [untimed.last]
            : times.map((time) => timed.putIfAbsent(time, () => (original: <String>{}, companions: <String>{})))) {
          if (isOriginal) {
            block.original.add(line.text);
          } else if (!block.original.contains(line.text)) {
            block.companions.add(line.text);
          }
        }
      }
    }
    return [...untimed, ...timed.values];
  }
}
