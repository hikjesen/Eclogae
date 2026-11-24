class ChannelTab {
  const ChannelTab({required this.title, this.initiallySelected = false});

  static const videos = ChannelTab(title: 'Videos');

  final String title;
  final bool initiallySelected;

  bool isVideosTab() => title == videos.title;
}
