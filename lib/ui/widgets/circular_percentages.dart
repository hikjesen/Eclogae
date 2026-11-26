import 'package:flutter/material.dart';

import 'package:eclogae/controller/indexer_controller.dart';
import 'package:eclogae/controller/json_to_history_parser.dart';
import 'package:eclogae/controller/video_controller.dart';
import 'package:eclogae/core/enums.dart';
import 'package:eclogae/core/extensions.dart';
import 'package:eclogae/core/utils.dart';
import 'package:eclogae/ui/widgets/custom_widgets.dart';

class IndexingPercentage extends _PercentageWithHeroWidget {
  const IndexingPercentage({super.key, super.size = 48.0, super.hero}) : super(defaultHeroTag: 'indexingper');

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: Indexer.inst.isIndexing,
      builder: (context, isIndexing) {
        if (!isIndexing) return const SizedBox();
        return NamidaCircularPercentage(
          hero: hero,
          heroTag: defaultHeroTag,
          percentageRx: Indexer.inst.indexingProgress.percentageRx,
          size: size,
        ).animateEntrance(showWhen: isIndexing);
      },
    );
  }
}

class ParsingJsonPercentage extends _PercentageWithHeroWidget {
  final TrackSource? source;
  final bool forceDisplay;
  const ParsingJsonPercentage({super.key, super.size = 48.0, this.source, this.forceDisplay = true, super.hero}) : super(defaultHeroTag: 'parsingjsonper');

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) => JsonToHistoryParser.inst.isParsing.valueR && (forceDisplay ? true : source == JsonToHistoryParser.inst.currentParsingSource.valueR)
          ? TapDetector(
              onTap: () => JsonToHistoryParser.inst.showParsingProgressDialog(),
              child: NamidaCircularPercentage(
                hero: hero,
                heroTag: defaultHeroTag,
                percentageRx: JsonToHistoryParser.inst.parsingProgress.percentageRx,
                size: size,
              ),
            )
          : const SizedBox(),
    );
  }
}

class VideosExtractingPercentage extends _PercentageWithHeroWidget {
  const VideosExtractingPercentage({super.key, super.size = 48.0, super.hero}) : super(defaultHeroTag: 'extractingvideosper');

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) => VideoController.inst.videosCountExtractingTotal.valueR > 0
          ? NamidaCircularPercentage(
              hero: hero,
              heroTag: defaultHeroTag,
              percentageRx: VideoController.inst.videosExtractingProgress.percentageRx,
              size: size,
            )
          : const SizedBox(),
    );
  }
}

abstract class _PercentageWithHeroWidget extends StatelessWidget {
  final bool hero;
  final double size;
  final String defaultHeroTag;

  const _PercentageWithHeroWidget({
    super.key,
    this.hero = true,
    required this.size,
    required this.defaultHeroTag,
  });

  @override
  Widget build(BuildContext context);
}
