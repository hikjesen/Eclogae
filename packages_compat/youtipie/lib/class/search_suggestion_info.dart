class SearchSuggestionInfo {
  const SearchSuggestionInfo({
    required this.fullText,
    this.typedAndCompletion,
    this.subtitle,
    this.displayName,
    this.entityId,
    this.thumbnailUrl,
    this.isChannel = false,
  });

  final String fullText;
  final (String, String)? typedAndCompletion;
  final String? subtitle, displayName, entityId, thumbnailUrl;
  final bool isChannel;
}
