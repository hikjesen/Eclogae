class YoutiPieMusicBrowseEndpoint {
  const YoutiPieMusicBrowseEndpoint(this.browseId, {this.formValues = const []});

  static const home = YoutiPieMusicBrowseEndpoint('FEmusic_home');
  static const charts = YoutiPieMusicBrowseEndpoint('FEmusic_charts');
  static const explore = YoutiPieMusicBrowseEndpoint('FEmusic_explore');
  static const moodsAndGenres = YoutiPieMusicBrowseEndpoint('FEmusic_moods_and_genres');
  static const newReleases = YoutiPieMusicBrowseEndpoint('FEmusic_new_releases');

  final String browseId;
  final List<String> formValues;

  YoutiPieMusicBrowseEndpoint withFormValues(List<String> values) => YoutiPieMusicBrowseEndpoint(browseId, formValues: values);

  String? extractPlaylistId() => browseId.startsWith('VL') ? browseId.substring(2) : null;
}
