import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';

import 'package:eclogae/base/tracks_search_widget_mixin.dart';
import 'package:eclogae/base/tracks_search_wrapper.dart';
import 'package:eclogae/class/queue.dart';
import 'package:eclogae/class/route.dart';
import 'package:eclogae/class/track.dart';
import 'package:eclogae/controller/queue_controller.dart';
import 'package:eclogae/controller/selected_tracks_controller.dart';
import 'package:eclogae/core/dimensions.dart';
import 'package:eclogae/core/enums.dart';
import 'package:eclogae/core/extensions.dart';
import 'package:eclogae/core/utils.dart';
import 'package:eclogae/ui/dialogs/common_dialogs.dart';
import 'package:eclogae/ui/widgets/artwork.dart';
import 'package:eclogae/ui/widgets/custom_widgets.dart';
import 'package:eclogae/ui/widgets/library/multi_artwork_container.dart';
import 'package:eclogae/ui/widgets/library/track_tile.dart';

class QueueTracksPage extends StatefulWidget with NamidaRouteWidget {
  @override
  String? get name => queue.date.toString();

  @override
  RouteType get route => RouteType.SUBPAGE_queueTracks;

  final Queue queue;
  const QueueTracksPage({super.key, required this.queue});

  @override
  State<QueueTracksPage> createState() => _QueueTracksPageState();
}

class _QueueTracksPageState extends State<QueueTracksPage> with PortsProvider<TracksSearchParams>, TracksSearchWidgetMixin<QueueTracksPage> {
  @override
  List<Selectable> getSearchableTracks() {
    return widget.queue.tracks;
  }

  @override
  RxBaseCore listChangesListenerRx() => QueueController.inst.queuesMap;

  @override
  Widget build(BuildContext context) {
    final queue = widget.queue;
    final tracks = queue.tracks;
    final searchResults = this.searchResults;
    final rangeOrder = searchResults == null ? null : FilteredRangeOrder(searchResults);
    final queueSource = QueueSource.queuePage(queue);
    final heroTag = 'queue_${queue.date}';
    final tracksInfoText = [
      tracks.displayTrackKeyword,
      tracks.totalDurationFormatted,
    ].join(' - ');
    return BackgroundWrapper(
      child: AnimationLimiter(
        child: TrackTilePropertiesProvider(
          configs: TrackTilePropertiesConfigs(
            queueSource: queueSource,
          ),
          builder: (properties) => NamidaListView(
            stickyHeader: TracksSearchWidgetBoxBase(
              state: this,
              leftText: tracksInfoText,
              sorting: null,
            ),
            infoBox: (maxWidth) => SubpageInfoContainer(
              maxWidth: maxWidth,
              type: MediaType.playlist,
              onOpenMenu: () => NamidaDialogs.inst.showQueueDialog(queue.date),
              source: queueSource,
              title: queue.date.dateFormattedOriginal,
              subtitle: queue.date.clockFormatted,
              thirdLineText: tracksInfoText,
              heroTag: heroTag,
              imageBuilder: (size) => MultiArtworkContainer(
                size: size,
                heroTag: heroTag,
                tracks: tracks.toImageTracks(),
              ),
              tracksFn: () => tracks,
              bannerBuilder: (width, height) => ArtworkStripBanner(
                tracks: tracks,
                width: width,
                height: height,
              ),
            ),
            itemCount: searchResults?.length ?? tracks.length,
            itemExtent: Dimensions.inst.trackTileItemExtent,
            itemBuilder: (context, i) {
              final index = searchResults == null ? i : searchResults[i];
              final track = tracks[index];
              return AnimatingTile(
                key: ValueKey(index),
                position: i,
                child: TrackTile(
                  properties: properties,
                  index: index,
                  trackOrTwd: track,
                  tracks: tracks,
                  rangeOrder: rangeOrder,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
