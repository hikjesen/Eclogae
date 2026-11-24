import '../music/music_chip.dart';
import '../music/music_form_option.dart';
import '../music/music_shelf.dart';
import '../thumbnail.dart';
import 'feedback_holder.dart';
import 'list_wrapper_base.dart';

class YoutiPieMusicBrowseResult extends YoutiPieListWrapper<YoutiPieMusicShelf> with YoutiPieFeedbackHolder {
  const YoutiPieMusicBrowseResult({
    super.items = const [],
    super.cacheKey,
    super.continuation,
    this.formOptions = const [],
    this.chips = const [],
    this.title = '',
    this.subtitle,
    this.channelId,
    this.avatarThumbnails = const [],
    this.bannerThumbnails = const [],
  });

  final List<YoutiPieMusicFormOption> formOptions;
  final List<YoutiPieMusicChip> chips;
  final String title;
  final String? subtitle, channelId;
  final List<YoutiPieThumbnail> avatarThumbnails, bannerThumbnails;

  String? findSongsPlaylistId() => null;
}
