import '../thumbnail.dart';

class ChannelAboutLink {
  const ChannelAboutLink({required this.title, required this.linkText, this.link, this.icons = const []});

  final String title, linkText;
  final String? link;
  final List<YoutiPieThumbnail> icons;
}
