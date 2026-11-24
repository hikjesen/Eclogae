class YoutipieDescription {
  const YoutipieDescription({this.rawText, this.parts});
  final String? rawText;
  final List<StylesWrapper>? parts;
}

class StylesWrapper {
  const StylesWrapper({
    required this.text,
    this.attachementUrl,
    this.hashtagParams,
    this.hashtag,
    this.videoId,
    this.videoStartSeconds,
    this.channelId,
    this.playlistId,
    this.link,
    this.linkClean,
    this.italic = false,
    this.bold = false,
    this.strikethrough = false,
  });

  final String text;
  final String? attachementUrl, hashtagParams, hashtag, videoId, channelId, playlistId, link, linkClean;
  final int? videoStartSeconds;
  final bool italic, bold, strikethrough;
}
