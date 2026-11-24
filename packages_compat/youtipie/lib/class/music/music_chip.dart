import 'music_browse_endpoint.dart';

class YoutiPieMusicChip {
  const YoutiPieMusicChip({required this.endpoint, required this.title, this.isSelected = false});

  final YoutiPieMusicBrowseEndpoint endpoint;
  final String title;
  final bool isSelected;
}
