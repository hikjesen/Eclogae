class HlsVariant {
  const HlsVariant({required this.height, required this.bandwidth});

  final int height, bandwidth;
}

class HlsMasterPlaylist {
  const HlsMasterPlaylist({this.variants = const []});

  final List<HlsVariant> variants;
  String buildSingleVariantMaster(HlsVariant variant) => throw UnsupportedError('YouTube disabled in Namida LX build');
}
