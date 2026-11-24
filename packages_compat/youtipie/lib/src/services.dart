import 'dart:io';
import 'dart:typed_data';

import 'package:nampack/reactive/reactive.dart';

import '../class/cache_details.dart';
import '../class/channels/channel_info.dart';
import '../class/channels/channel_page_about.dart';
import '../class/channels/channel_page_result.dart';
import '../class/channels/channel_tab.dart';
import '../class/channels/channel_tab_result.dart';
import '../class/comments/comment_info_item.dart';
import '../class/comments/comment_info_item_base.dart';
import '../class/execute_details.dart';
import '../class/feedback_menu_action.dart';
import '../class/items_sort.dart';
import '../class/map_serializable.dart';
import '../class/music/music_browse_endpoint.dart';
import '../class/notification_menu_action.dart';
import '../class/playlist_for_video.dart';
import '../class/related_videos_request_params.dart';
import '../class/result_wrapper/channel_user_result.dart';
import '../class/result_wrapper/comment_notification_result.dart';
import '../class/result_wrapper/comment_reply_result.dart';
import '../class/result_wrapper/comment_result.dart';
import '../class/result_wrapper/feed_result.dart';
import '../class/result_wrapper/feedback_holder.dart';
import '../class/result_wrapper/hashtag_result.dart';
import '../class/result_wrapper/history_result.dart';
import '../class/result_wrapper/list_wrapper_base.dart';
import '../class/result_wrapper/music_browse_result.dart';
import '../class/result_wrapper/music_search_result.dart';
import '../class/result_wrapper/notification_result.dart';
import '../class/result_wrapper/playlist_mix_result.dart';
import '../class/result_wrapper/playlist_result.dart';
import '../class/result_wrapper/playlist_result_base.dart';
import '../class/result_wrapper/playlist_user_result.dart';
import '../class/result_wrapper/related_videos_result.dart';
import '../class/result_wrapper/search_result.dart';
import '../class/result_wrapper/user_channels_all_videos_result.dart';
import '../class/search_filters.dart';
import '../class/search_suggestion_info.dart';
import '../class/sponsorblock_segments_result.dart';
import '../class/stream_info_item/stream_info_item.dart';
import '../class/stream_info_item/stream_info_item_notification.dart';
import '../class/streams/hls_variant.dart';
import '../class/streams/video_streams_result.dart';
import '../class/thumbnail.dart';
import '../class/videos/missing_video_info.dart';
import '../class/videos/video_info.dart';
import '../class/videos/video_result.dart';
import '../class/youtipie_feed/playlist_info_item_user.dart';
import '../class/youtipie_feed/user_channel_info.dart';
import '../core/enum.dart';
import '../core/http.dart';

class CacheBuilder {
  const CacheBuilder();

  CacheDetails<YoutiPiePlaylistResult> forPlaylistVideos({required String playlistId}) => const CacheDetails();
  CacheDetails<YoutiPieUserPlaylistsResult> forUserPlaylists() => const CacheDetails();
  CacheDetails<YoutiPieFeedResult> forFeedItems() => const CacheDetails();
  CacheDetails<YoutiPieNotificationCommentResult> forNotificationComments({required String videoId, required String linkedCommentId}) => const CacheDetails();
  CacheDetails<YoutiPieNotificationResult> forNotificationItems() => const CacheDetails();
  CacheDetails<YoutiPieUserChannelsResult> forUserChannels() => const CacheDetails();
  CacheDetails<YoutiPieHistoryResult> forHistoryVideos() => const CacheDetails();
  CacheDetails<YoutiPieUserChannelsAllVideosResult> forUserChannelsAllVideos() => const CacheDetails();
  CacheDetails<YoutiPieChannelTabResult> forChannelTab({required String channelId, required ChannelTab tab}) => const CacheDetails();
  CacheDetails<YoutiPieHashtagResult> forHashtag({required String params}) => const CacheDetails();
  CacheDetails<YoutiPieMusicBrowseResult> forMusicBrowse({required YoutiPieMusicBrowseEndpoint endpoint}) => const CacheDetails();
  CacheDetails<YoutiPieCommentReplyResult> forCommentReplies({required String commentId}) => const CacheDetails();
  CacheDetails<YoutiPieChannelPageResult> forChannel({required String channelId}) => const CacheDetails();
  CacheDetails<ChannelPageAbout> forChannelAbout({required String channelId}) => const CacheDetails();
  CacheDetails<MissingVideoInfo> forMissingInfo({required String videoId}) => const CacheDetails();
  CacheDetails<StreamInfoItem> forStreamInfoItem({required String videoId}) => const CacheDetails();
  CacheDetails<YoutiPieVideoPageResult> forVideoPage({required String videoId}) => const CacheDetails();
  CacheDetails<VideoStreamsResult> forVideoStreams({required String videoId}) => const CacheDetails();
  CacheDetails<({int? dislikes})> forReturnYoutubeDislike({required String videoId}) => const CacheDetails();
  CacheDetails<YoutiPieMixPlaylistResult> forMixPlaylistVideos({required String mixId, required bool userPersonalized}) => const CacheDetails();
  CacheDetails<YoutiPieRelatedVideosResult> forRelatedVideos({required String videoId, required bool userPersonalized}) => const CacheDetails();
  CacheDetails<YoutiPieCommentResult> forComments({required String videoId}) => const CacheDetails();
}

class CacheManager {
  const CacheManager();
  void init(String directory) {}
  void closeAll() {}
}

class MemoryCache {
  const MemoryCache();

  final channelThumbnails = const ChannelThumbnailCache();
  ({Map<String, StreamInfoItem> temp}) get streamInfoItem => (temp: const {},);
}

class ChannelThumbnailCache {
  const ChannelThumbnailCache();

  void add(YoutiPieChannelInfo? info) {}
  List<YoutiPieThumbnail>? get(String channelId) => null;
}

class CipherService {
  const CipherService();

  bool get isPrepared => false;
  String? get jsPlayerVersion => null;
  int? get signatureTimestamp => null;
  bool get didFailedToExtractJsCode => false;
  Future<bool> prepareJSPlayer({required String cacheDirectoryPath}) async => false;
}

class PoTokenService {
  const PoTokenService();

  bool get hasPoToken => false;
  DateTime? get lastRefreshed => null;
  String? getVisitorData() => null;
  void updateInfo({required String visitorData, required String playerRequestPoToken, required String streamingPoToken}) {}
}

class SessionFailureReport {
  const SessionFailureReport();

  DateTime? get date => null;
  String toText() => 'YouTube disabled in Namida LX build';
}

class VideoService {
  const VideoService();

  Future<YoutiPieVideoPageResult?> fetchVideoPage({
    required String videoId,
    required RelatedVideosRequestParams relatedVideosParams,
    ExecuteDetails? details,
  }) async => null;

  Future<YoutiPieRelatedVideosResult?> fetchRelatedVideos({
    required String videoId,
    required bool userPersonalized,
    required bool preferMix,
    required RelatedVideosRequestParams relatedVideosParams,
    ExecuteDetails? details,
  }) async => null;

  Future<VideoStreamsResult?> fetchVideoStreams({required String id, required InnertubeClients client, ExecuteDetails? details}) async => null;
  Future<HlsMasterPlaylist?> fetchHlsMasterPlaylist(String masterUrl) async => null;
  Future<File?> fetchMusicVideoThumbnailToFile({required String id, required String filePath}) async => null;

  Future<bool> changeLikeStatus({
    required YoutiPieVideoPageResult videoPage,
    required VideoEngagement? engagement,
    required LikeAction action,
  }) async => false;
}

class PlaylistService {
  const PlaylistService();

  Future<YoutiPiePlaylistResult?> fetchPlaylist({required String playlistId, ExecuteDetails? details}) async => null;

  Future<YoutiPieMixPlaylistResult?> getMixPlaylist({
    required String videoId,
    String? mixId,
    required bool includeFirstVideo,
    required bool userPersonalized,
    ExecuteDetails? details,
  }) async => null;

  Future<bool> addRemoveVideosInPlaylist({
    required Iterable<String>? videosToAdd,
    required Iterable<String>? videosToRemove,
    required String playlistId,
    required Rxn<YoutiPieUserPlaylistsResult>? mainList,
    required void Function(PlaylistInfoItemUser) onUserPlaylistUpdated,
  }) async => false;
}

class YoutiPiePlaylistEditCallbacks {
  const YoutiPiePlaylistEditCallbacks({required this.oldPlaylist, required this.newPlaylistCallback});

  final YoutiPiePlaylistResultBase Function() oldPlaylist;
  final void Function(YoutiPiePlaylistResultBase) newPlaylistCallback;
}

class UserPlaylistService {
  const UserPlaylistService();

  // These limits are used by the existing playlist text fields.
  int get MAX_PLAYLIST_NAME => 150;
  int get MAX_PLAYLIST_DESCRIPTION => 5000;

  Future<YoutiPieUserPlaylistsResult?> getUserPlaylists({ExecuteDetails? details}) async => null;
  Future<List<PlaylistForVideoItem>?> getPlaylistsForVideo({required String videoId, required bool insertActiveAtTop}) async => const [];

  Future<YoutiPieUserPlaylistsResult> injectDefaultPlaylistsInUserPlaylists(YoutiPieUserPlaylistsResult result) async => result;

  Future<({String title, String? description, PlaylistPrivacy? privacy})?> getPlaylistEditInfo(String playlistId) async => null;
  String? validatePlaylistTitle(String title) => null;

  Future<String?> createPlaylist({
    required Rxn<YoutiPieUserPlaylistsResult>? mainList,
    required String title,
    required Iterable<String> initialVideoIds,
    required PlaylistPrivacy? privacy,
  }) async => null;

  Future<bool> editPlaylist({
    required Rxn<YoutiPieUserPlaylistsResult>? mainList,
    required List<YoutiPiePlaylistEditCallbacks> playlists,
    required String playlistId,
    required String title,
    required String? description,
    required PlaylistPrivacy? privacy,
    required bool? newVideosAtTop,
  }) async => false;

  Future<bool> removeHostedPlaylistFromLibrary({required YoutiPiePlaylistResult playlist}) async => false;
  Future<bool> addHostedPlaylistToLibrary({required YoutiPiePlaylistResult playlist}) async => false;
}

class ChannelService {
  const ChannelService();

  Future<YoutiPieChannelPageResult?> fetchChannelPage({required String? channelId, String? handle, ExecuteDetails? details}) async => null;
  Future<ChannelPageAbout?> fetchChannelAbout({required YoutiPieChannelPageResult channel, ExecuteDetails? details}) async => null;
  Future<YoutiPieChannelTabResult?> fetchChannelTab({
    required String channelId,
    required ChannelTab tab,
    YoutiPieItemsSort? sort,
    ExecuteDetails? details,
  }) async => null;

  Future<({bool isNowSubbed, ChannelNotifications? newNotificationStatus})?> changeSubscribeStatus({
    required YoutiPieChannelInfo? mainChannelInfo,
    required ChannelEngagement? channelEngagement,
    required bool subscribe,
  }) async => null;

  Future<bool> changeChannelNotificationStatus({
    required YoutiPieChannelInfo? mainChannelInfo,
    required ChannelNotifications notifications,
  }) async => false;
}

class UserChannelService {
  const UserChannelService();

  Future<YoutiPieUserChannelsResult?> fetchUserChannels({ExecuteDetails? details}) async => null;
  Future<YoutiPieUserChannelsAllVideosResult?> fetchUserChannelsAllVideos({ExecuteDetails? details}) async => null;
}

class CommentService {
  const CommentService();

  Future<YoutiPieCommentResult?> fetchComments({required String videoId, required String continuationToken, ExecuteDetails? details}) async => null;
  Future<YoutiPieNotificationCommentResult?> fetchNotificationComments({
    required String videoId,
    required String linkedCommentId,
    ExecuteDetails? details,
  }) async => null;

  Future<YoutiPieCommentReplyResult?> fetchCommentReplies({required CommentInfoItem mainComment, ExecuteDetails? details}) async => null;

  Future<bool> changeLikeStatus({
    required CommentInfoItemBase comment,
    required YoutiPieListWrapper<CommentInfoItemBase> mainList,
    required LikeAction action,
  }) async => false;

  Future<CommentInfoItem?> createComment({
    required YoutiPieCommentResult? mainList,
    required String? createCommentParams,
    required String content,
    required YoutiPieVideoPageResult? videoPage,
    required String videoId,
  }) async => null;

  Future<CommentInfoItem?> editComment({
    required YoutiPieCommentResult? mainList,
    required CommentInfoItem comment,
    required String content,
  }) async => null;

  Future<bool> deleteComment({
    required YoutiPieCommentResult? mainList,
    required CommentInfoItem comment,
    required YoutiPieVideoPageResult? videoPage,
  }) async => false;

  Future<CommentInfoItemBase?> createReply({
    required YoutiPieCommentReplyResult? mainList,
    required String? createReplyParams,
    required String content,
    required CommentInfoItem? mainComment,
    required YoutiPieCommentResult? commentsList,
    required YoutiPieVideoPageResult? videoPage,
    required String videoId,
  }) async => null;

  Future<CommentInfoItemBase?> editReply({
    required YoutiPieCommentReplyResult? mainList,
    required CommentInfoItemBase reply,
    required String content,
    required String videoId,
  }) async => null;

  Future<bool> deleteReply({
    required YoutiPieCommentReplyResult? mainList,
    required CommentInfoItemBase reply,
    required CommentInfoItem mainComment,
    required YoutiPieCommentResult? commentsList,
    required YoutiPieVideoPageResult? videoPage,
  }) async => false;
}

class FeedService {
  const FeedService();

  Future<YoutiPieFeedResult?> fetchFeed({ExecuteDetails? details}) async => null;
  Future<YoutiPieNotificationResult?> fetchNotifications({ExecuteDetails? details, required bool useNewExtractor}) async => null;
}

class NotificationService {
  const NotificationService();

  Future<bool> markNotficationRead({required YoutiPieNotificationResult mainList, required StreamInfoItemNotification notification}) async => false;
  Future<bool> applyMenuAction({
    required YoutiPieNotificationResult mainList,
    required StreamInfoItemNotification notification,
    required NotificationMenuAction action,
  }) async => false;
}

class FeedbackService {
  const FeedbackService();

  Future<YoutiPieFeedbackUndo?> sendFeedback({required YoutiPieFeedbackHolder list, required MapSerializable item, required FeedbackMenuAction action}) async => null;
  Future<bool> undoFeedback(YoutiPieFeedbackUndo undo) async => false;
}

class SearchService {
  const SearchService();

  Future<List<SearchSuggestionInfo>?> getSuggestions(String query, {ExecuteDetails? details}) async => const [];

  Future<YoutiPieSearchResult?> search(
    String query, {
    required YoutiPieSearchFilters filters,
    required bool peopleAlsoWatched,
    ExecuteDetails? details,
  }) async => null;
}

class HashtagService {
  const HashtagService();

  Future<YoutiPieHashtagResult?> fetchHashtag({required String params, ExecuteDetails? details}) async => null;
}

class HistoryService {
  const HistoryService();

  Future<YoutiPieHistoryResult?> fetchHistory({ExecuteDetails? details}) async => null;
  Future<(bool,)> addVideoToHistory({required String? statsPlaybackUrl, required String? statsWatchtimeUrl}) async => (false,);
}

class MusicService {
  const MusicService();

  Future<YoutiPieMusicBrowseResult?> browse(YoutiPieMusicBrowseEndpoint endpoint, {ExecuteDetails? details}) async => null;
  Future<YoutiPieMusicSearchResult?> search(String query, {String? params, ExecuteDetails? details}) async => null;
}

class SponsorBlockService {
  const SponsorBlockService();

  Future<SponsorBlockSegmentsResult?> getSegments(
    String videoId, {
    required List<String> categories,
    required String serverAddress,
    ExecuteDetails? details,
  }) async => const SponsorBlockSegmentsResult();

  Future<void> trackSkippedSegment(String uuid, {required String serverAddress}) async {}
}

class DislikeService {
  const DislikeService();

  Future<({int? dislikes})?> fetchDislikes(String videoId) async => null;
  Future<void> sendVoteAction(String videoId, LikeAction action) async {}
}

class MissingInfoService {
  const MissingInfoService();

  Future<MissingVideoInfo?> fetchMissingInfo({required String videoId}) async => null;
  Future<Uint8List?> fetchMissingThumbnail({required String videoId}) async => null;
}
