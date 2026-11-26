import 'package:flutter/material.dart';

import 'package:eclogae/core/extensions.dart';
import 'package:eclogae/core/icon_fonts/broken_icons.dart';
import 'package:eclogae/core/ntheme.dart';
import 'package:eclogae/ui/widgets/custom_widgets.dart';

import '../lx_models.dart';

class LxSonglistCard extends StatelessWidget {
  const LxSonglistCard({super.key, required this.songlist, this.showSourceBadge = false, required this.onTap});

  final LxSonglist songlist;
  final bool showSourceBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = songlist.img;
    final meta = [
      if (songlist.total != null) '${songlist.total}首',
      if (songlist.author.isNotEmpty) songlist.author,
    ].join(' · ');
    return NamidaInkWell(
      borderRadius: 12.0,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: NContainer(
              clipBehavior: Clip.antiAlias,
              decoration: (colors) => BoxDecoration(
                color: Color.alphaBlend(colors.secondaryContainer.withOpacityExt(0.45), colors.cardTheme),
                borderRadius: BorderRadius.circular(12.0.multipliedRadius),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const Center(child: NIcon(Broken.music_playlist, size: 30, color: NColors.disabled)),
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      excludeFromSemantics: true,
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded) return child;
                        return AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180),
                          child: child,
                        );
                      },
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  if (showSourceBadge)
                    PositionedDirectional(
                      top: 6,
                      start: 6,
                      end: 6,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _CoverBadge(label: songlist.source.label),
                      ),
                    ),
                  if (songlist.playCount.isNotEmpty)
                    PositionedDirectional(
                      bottom: 6,
                      start: 6,
                      end: 6,
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _CoverBadge(label: songlist.playCount, icon: Broken.play),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              songlist.name,
              style: NText.small.of(context).copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (meta.isNotEmpty)
            NamidaText(meta, style: const NText(.small, size: .s11), color: const NColors(.onSurface, opacity: 0.66), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _CoverBadge extends StatelessWidget {
  const _CoverBadge({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6.0.multipliedRadius)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon case final icon?) ...[Icon(icon, size: 10, color: Colors.white), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NText.small.of(context).copyWith(fontSize: 10, color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}
