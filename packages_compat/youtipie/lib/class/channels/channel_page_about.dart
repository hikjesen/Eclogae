import 'channel_about_link.dart';

class ChannelPageAbout {
  const ChannelPageAbout({
    this.aboutLinks = const [],
    this.description,
    this.canonicalChannelUrl,
    this.subscriberCount,
    this.subscriberCountText,
    this.videoCount,
    this.videoCountText,
    this.viewCount,
    this.viewCountText,
    this.joinedText,
    this.country,
  });

  final List<ChannelAboutLink> aboutLinks;
  final String? description, canonicalChannelUrl, subscriberCountText, videoCountText, viewCountText, joinedText, country;
  final int? subscriberCount, videoCount, viewCount;
}
