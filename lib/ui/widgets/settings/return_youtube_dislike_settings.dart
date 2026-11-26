import 'package:flutter/material.dart';

import 'package:eclogae/controller/player_controller.dart';
import 'package:eclogae/controller/settings_controller.dart';
import 'package:eclogae/core/constants.dart';
import 'package:eclogae/core/extensions.dart';
import 'package:eclogae/core/icon_fonts/broken_icons.dart';
import 'package:eclogae/core/translations/language.dart';
import 'package:eclogae/core/utils.dart';
import 'package:eclogae/ui/widgets/custom_widgets.dart';
import 'package:eclogae/ui/widgets/settings_card.dart';
import 'package:eclogae/youtube/class/return_youtube_dislike.dart';
import 'package:eclogae/youtube/class/youtube_id.dart';
import 'package:eclogae/youtube/controller/youtube_info_controller.dart';

class ReturnYoutubeDislikeSettingsPage extends StatelessWidget {
  const ReturnYoutubeDislikeSettingsPage({super.key});

  ReturnYoutubeDislikeSettings get _currentConfigValue => settings.youtube.ryd.value;
  RxBaseCore<ReturnYoutubeDislikeSettings> get _currentConfig => settings.youtube.ryd;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.returnYoutubeDislike,
      subtitle: null,
      icon: Broken.dislike,
      child: Column(
        children: [
          Obx(
            (context) {
              final isEnabled = _currentConfig.valueR.enabled;
              return CustomSwitchListTile(
                icon: isEnabled ? Broken.dislike_filled : Broken.dislike,
                title: lang.enableReturnYoutubeDislike,
                value: isEnabled,
                onChanged: (isTrue) {
                  final newConfigs = _currentConfigValue.copyWith(enabled: !isTrue);
                  settings.youtube.ryd.save(newConfigs);

                  if (newConfigs.enabled) {
                    final currentItem = Player.inst.currentItem.value;
                    if (currentItem is YoutubeID) {
                      YoutubeInfoController.current.fetchAndUpdateDislikeCount(currentItem.id);
                      return;
                    }
                  }
                  YoutubeInfoController.current.clearCurrentDislikeCount();
                },
              );
            },
          ),
          CustomListTile(
            icon: Broken.info_circle,
            title: lang.about,
            subtitle: "${lang.dataIsProvidedByName(name: _currentConfigValue.defaultWebsiteUrl.replaceFirst('https://', '').addDQuotation())}. ${lang.learnMore}",
            trailing: const Icon(
              Broken.export_1,
              size: 18.0,
            ),
            onTap: () => NamidaLinkUtils.openLink(_currentConfigValue.defaultWebsiteUrl),
          ),
        ],
      ),
    );
  }
}
