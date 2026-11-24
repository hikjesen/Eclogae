import 'dart:async';

import 'package:logger/logger.dart';
import 'package:nampack/reactive/reactive.dart';
import 'package:rhttp/rhttp.dart' show ProxySettings;

import 'class/youtipie_feed/user_channel_info.dart';
import 'core/enum.dart';
import 'managers/account_manager.dart';
import 'src/services.dart';

export 'class/cache_details.dart';
export 'class/channels/channel_about_link.dart';
export 'class/channels/channel_home_section.dart';
export 'class/channels/channel_info.dart';
export 'class/channels/channel_page_about.dart';
export 'class/channels/channel_page_result.dart';
export 'class/channels/channel_tab.dart';
export 'class/channels/channel_tab_result.dart';
export 'class/chunks/history_chunk.dart';
export 'class/comments/comment_info_item.dart';
export 'class/comments/comment_info_item_base.dart';
export 'class/execute_details.dart';
export 'class/feedback_menu_action.dart';
export 'class/items_sort.dart';
export 'class/map_serializable.dart';
export 'class/music/music_browse_endpoint.dart';
export 'class/music/music_chip.dart';
export 'class/music/music_form_option.dart';
export 'class/music/music_search_chip.dart';
export 'class/music/music_shelf.dart';
export 'class/music/music_top_result.dart';
export 'class/notification_menu_action.dart';
export 'class/playlist_for_video.dart';
export 'class/publish_time.dart';
export 'class/related_videos_request_params.dart';
export 'class/result_wrapper/channel_user_result.dart';
export 'class/result_wrapper/comment_notification_result.dart';
export 'class/result_wrapper/comment_reply_result.dart';
export 'class/result_wrapper/comment_result.dart';
export 'class/result_wrapper/feed_result.dart';
export 'class/result_wrapper/feedback_holder.dart';
export 'class/result_wrapper/hashtag_result.dart';
export 'class/result_wrapper/history_result.dart';
export 'class/result_wrapper/list_wrapper_base.dart';
export 'class/result_wrapper/music_browse_result.dart';
export 'class/result_wrapper/music_search_result.dart';
export 'class/result_wrapper/notification_result.dart';
export 'class/result_wrapper/playlist_mix_result.dart';
export 'class/result_wrapper/playlist_result.dart';
export 'class/result_wrapper/playlist_result_base.dart';
export 'class/result_wrapper/playlist_user_result.dart';
export 'class/result_wrapper/related_videos_result.dart';
export 'class/result_wrapper/search_result.dart';
export 'class/result_wrapper/user_channels_all_videos_result.dart';
export 'class/search_filters.dart';
export 'class/search_suggestion_info.dart';
export 'class/sponsorblock_segment.dart';
export 'class/sponsorblock_segments_result.dart';
export 'class/stream_info_item/stream_info_item.dart';
export 'class/stream_info_item/stream_info_item_notification.dart';
export 'class/stream_info_item/stream_info_item_short.dart';
export 'class/streams/audio_stream.dart';
export 'class/streams/audio_track.dart';
export 'class/streams/caption.dart';
export 'class/streams/codec_info.dart';
export 'class/streams/endscreens/endscreen_item_base.dart';
export 'class/streams/hls_variant.dart';
export 'class/streams/stream_base.dart';
export 'class/streams/stream_segments.dart';
export 'class/streams/video_stream.dart';
export 'class/streams/video_stream_info.dart';
export 'class/streams/video_streams_result.dart';
export 'class/thumbnail.dart';
export 'class/videos/missing_video_info.dart';
export 'class/videos/video_heat_map.dart';
export 'class/videos/video_info.dart';
export 'class/videos/video_playability.dart';
export 'class/videos/video_result.dart';
export 'class/youtipie_description/youtipie_description.dart';
export 'class/youtipie_feed/channel_info_item.dart';
export 'class/youtipie_feed/music_album_info_item.dart';
export 'class/youtipie_feed/music_navigation_item.dart';
export 'class/youtipie_feed/playlist_basic_info.dart';
export 'class/youtipie_feed/playlist_info_item.dart';
export 'class/youtipie_feed/playlist_info_item_user.dart';
export 'class/youtipie_feed/user_channel_info.dart';
export 'class/youtipie_feed/yt_feed_base.dart';
export 'core/enum.dart';
export 'core/extensions.dart';
export 'core/http.dart';
export 'core/playlist_id_utils.dart';
export 'core/url_utils.dart';
export 'managers/account_manager.dart';
export 'src/services.dart' show YoutiPiePlaylistEditCallbacks;

abstract final class YoutiPie {
  static const playlist = PlaylistService();
  static const userplaylist = UserPlaylistService();
  static const playlistAction = PlaylistService();
  static const userchannel = UserChannelService();
  static const channel = ChannelService();
  static const channelAction = ChannelService();
  static const comment = CommentService();
  static const commentAction = CommentService();
  static const notificationsAction = NotificationService();
  static const feedbackAction = FeedbackService();
  static const search = SearchService();
  static const feed = FeedService();
  static const history = HistoryService();
  static const hashtag = HashtagService();
  static const music = MusicService();
  static const sponsorblock = SponsorBlockService();
  static const returnyoutubedislike = DislikeService();
  static const missingInfo = MissingInfoService();
  static const video = VideoService();
  static const videoAction = VideoService();
  static const potoken = PoTokenService();
  static const cipher = CipherService();
  static const cacheBuilder = CacheBuilder();
  static const cacheManager = CacheManager();
  static const cacheManagerSync = CacheManager();
  static const memoryCache = MemoryCache();
  static final cookies = YoutiAccountManager();

  static Rx<Set<UserChannelInfo>> get signedInAccounts => cookies.signedInAccounts;
  static Rxn<UserChannelInfo> get activeAccountDetails => cookies.activeAccountChannel;
  static String get languageCode => '';
  static String get countryCode => '';
  static DateTime? get lastSessionReset => null;
  static SessionFailureReport? get lastSessionFailureReport => null;

  static bool Function(YoutiPieOperation)? canExecuteOperation;
  static bool Function(YoutiPieOperation)? onOperationFailNoAccount;
  static void Function(String, Object, StackTrace)? onWorkerError;

  static void setLogs(Logger logger) {}
  static void setProxySettings(ProxySettings? settings) {}

  static void initialize({
    required String dataDirectory,
    required String sensitiveDataDirectory,
    required String sensitiveDataEncryptionKey,
    required bool isNewSensitiveDataEncryptionKey,
    required bool checkJSPlayer,
    required bool Function() checkHasConnectionCallback,
    required Completer<void> syncItemsCompleter,
    required Completer<void> accountCompleter,
  }) {
    // Namida waits for both signals even when the backend has no work to do.
    if (!syncItemsCompleter.isCompleted) syncItemsCompleter.complete();
    if (!accountCompleter.isCompleted) accountCompleter.complete();
  }

  static Future<UserChannelInfo?> getActiveAccountChannelIsolate(String dataDirectory, {required String encryptionKey}) async => null;

  static Future<void> resetSession() async {}
  static void dispose() {}
}
