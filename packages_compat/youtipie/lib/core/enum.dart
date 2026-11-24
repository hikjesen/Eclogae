export '../class/feedback_menu_action.dart' show FeedbackMenuActionType;
export '../class/streams/endscreens/endscreen_item_base.dart' show VideoEndScreenItemType;
export '../class/search_filters.dart' show YoutiPieSearchType, YoutiPieSearchSort, YoutiPieSearchUploadDate, YoutiPieSearchMatchMode;

enum LikeStatus { liked, disliked, undefined, unknown }

enum LikeAction {
  addLike, removeLike, addDislike, removeDislike;

  LikeStatus toExpectedStatus() => switch (this) {
    addLike => LikeStatus.liked,
    addDislike => LikeStatus.disliked,
    removeLike || removeDislike => LikeStatus.undefined,
  };
}

enum CommentsSortType { top, newest }
enum ChannelNotifications { all, personalized, none }
enum PlaylistPrivacy { public, unlisted, private }

enum YoutiPieOperation {
  changeVideoLikeStatus,
  addVideoToHistory,
  fetchUserPlaylists,
  fetchUserPlaylistsNext,
  fetchUserPlaylistsSort,
  fetchUserChannels,
  fetchUserChannelsNext,
  fetchUserChannelsSort,
  fetchUserChannelsAllVideos,
  fetchUserChannelsAllVideosNext,
  getPlaylistsForVideo,
  getPlaylistEditInfo,
  addRemoveVideosPlaylist,
  createPlaylist,
  sendVoteReturnYoutubeDislike,
  fetchNotifications,
  fetchNotificationsNext,
  markNotificationRead,
  fetchNotificationComments,
  fetchNotificationCommentsNext,
  sendFeedback,
  undoFeedback,
  fetchFeed,
  fetchHistory,
  fetchChannelTab,
  fetchHashtag,
  fetchMusicBrowse;

  bool get requiresAccount => switch (this) {
    fetchChannelTab || fetchHashtag || fetchMusicBrowse || sendVoteReturnYoutubeDislike => false,
    _ => true,
  };
}
