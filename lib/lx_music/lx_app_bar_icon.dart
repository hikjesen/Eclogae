import 'package:flutter/material.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

import 'lx_download_manager.dart';
import 'lx_settings_page.dart';

class LxMusicAppBarIcon extends StatelessWidget {
  const LxMusicAppBarIcon({super.key});

  @override
  Widget build(BuildContext context) => Obx((context) {
    final current = NamidaNavigator.inst.currentRouteR;
    if (current is LxSettingsPage || current?.route == RouteType.YOUTUBE_HOME || current?.route == RouteType.YOUTUBE_HOME_SECTION) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<int>(
      valueListenable: LxDownloadManager.inst.activeCountNotifier,
      builder: (context, count, _) {
        if (count <= 0) return const SizedBox.shrink();
        return NamidaAppBarIcon(
          icon: Broken.document_download,
          tooltip: () => '在线曲库下载中 ($count)',
          onPressed: LxSettingsPage.openDownloads,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const NIcon(Broken.document_download, color: NColors.secondary),
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
                      '$count',
                      style: const NText(.small, size: .s10),
                      color: NColors.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  });
}
