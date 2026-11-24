import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

import 'lx_download_manager.dart';
import 'lx_music_page.dart';

class LxMusicAppBarIcon extends StatelessWidget {
  const LxMusicAppBarIcon({super.key});

  @override
  Widget build(BuildContext context) => Obx((context) {
    if (NamidaNavigator.inst.currentRouteR?.name == LxMusicPage.title) return const SizedBox.shrink();

    return ValueListenableBuilder<int>(
      valueListenable: LxDownloadManager.inst.activeCountNotifier,
      builder: (context, count, _) => NamidaAppBarIcon(
        icon: Broken.music_square_search,
        tooltip: () => LxMusicPage.title,
        onPressed: () => LxMusicPage(initialTab: count > 0 ? 1 : 0).navigate(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const NIcon(Broken.music_square_search, color: NColors.secondary),
            if (count > 0)
              Positioned(
                top: -4.0,
                right: -6.0,
                child: NDecoratedBox(
                  decoration: (colors) => BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                    child: NamidaText(
                      count.formatDecimal(),
                      style: const NText(.small, size: .s10),
                      color: NColors.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  });
}
