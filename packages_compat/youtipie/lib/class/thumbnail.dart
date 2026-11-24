class YoutiPieThumbnail {
  const YoutiPieThumbnail({required this.url, this.width = 0, this.height = 0});
  final String url;
  final int width, height;

  static List<YoutiPieThumbnail> listFromMap(Object? value) => (value as List<Object?>?)
      ?.cast<Map<Object?, Object?>>()
      .map((item) => YoutiPieThumbnail(url: item['url'] as String, width: item['width'] as int? ?? 0, height: item['height'] as int? ?? 0))
      .toList() ?? const [];

  Map<String, Object?> toMap() => {'url': url, 'width': width, 'height': height};
}

abstract final class YoutiPieVideoThumbnail {
  static List<String> mixLow(String id) => const [];
  static List<String> mix(String id) => const [];
}
