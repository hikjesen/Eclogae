import 'package:flutter/material.dart';

import 'package:eclogae/core/extensions.dart';
import 'package:eclogae/core/icon_fonts/broken_icons.dart';
import 'package:eclogae/core/ntheme.dart';

import '../lx_models.dart';

class LxCoverThumb extends StatelessWidget {
  const LxCoverThumb({super.key, this.url, this.size = 46, this.borderRadius = 10});

  final String? url;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    final cachePx = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    final radius = BorderRadius.circular(borderRadius.multipliedRadius);
    return NContainer(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: (colors) => BoxDecoration(
        color: Color.alphaBlend(colors.secondaryContainer.withOpacityExt(0.45), colors.cardTheme),
        borderRadius: radius,
      ),
      foregroundDecoration: (colors) => BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: colors.onSurface.withOpacityExt(0.08)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          NIcon(Broken.musicnote, size: size * 0.44, color: NColors.defaultIcon()),
          if (imageUrl != null && imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: cachePx,
              cacheHeight: cachePx,
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
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class LxQualityBadge extends StatelessWidget {
  const LxQualityBadge({super.key, required this.quality, this.compact = true});

  final String quality;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = NColorsData.of(context);
    final accent = switch (quality) {
      'flac24bit' => const Color(0xFFD99B26),
      'flac' => const Color(0xFF1F9D7A),
      '320k' => colors.primary,
      _ => colors.onSurface.withOpacityExt(0.65),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withOpacityExt(0.14),
        border: Border.all(color: accent.withOpacityExt(0.35)),
        borderRadius: BorderRadius.circular(6.0.multipliedRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          LxDownloadSettings.qualityBadge(quality),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: NText.small.of(context).copyWith(
            color: Color.alphaBlend(accent.withOpacityExt(0.44), colors.onSurface),
            fontSize: compact ? 9.5 : 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
