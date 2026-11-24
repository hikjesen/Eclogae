enum YoutiPieMusicSearchType { songs, videos, albums, artists, playlists, profiles, podcasts, episodes }

class YoutiPieMusicSearchChip {
  const YoutiPieMusicSearchChip({required this.title, this.type, this.params, this.isSelected = false});

  final String title;
  final String? params;
  final YoutiPieMusicSearchType? type;
  final bool isSelected;
}
