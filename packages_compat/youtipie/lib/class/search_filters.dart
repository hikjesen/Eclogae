enum YoutiPieSearchType { all, video, channel, playlist, movie }
enum YoutiPieSearchSort { relevance, rating, date, views }
enum YoutiPieSearchUploadDate { none, lastHour, today, thisWeek, thisMonth, thisYear }
enum YoutiPieSearchMatchMode { phrase, title }

class YoutiPieSearchDate {
  const YoutiPieSearchDate._(this.year, this.month, this.day);
  YoutiPieSearchDate.fromDateTime(DateTime date) : this._(date.year, date.month, date.day);

  final int year;
  final int? month, day;

  static final _pattern = RegExp(r'^(\d{4})(?:-(\d{2})(?:-(\d{2}))?)?$');

  static YoutiPieSearchDate? parse(String text) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.tryParse(match[2] ?? '');
    final day = int.tryParse(match[3] ?? '');
    final date = DateTime.utc(year, month ?? 1, day ?? 1);
    if (date.year != year || date.month != (month ?? 1) || date.day != (day ?? 1)) return null;
    return YoutiPieSearchDate._(year, month, day);
  }

  DateTime toDateTime() => DateTime(year, month ?? 1, day ?? 1);

  DateTime toDateTimeUtc() => DateTime.utc(year, month ?? 1, day ?? 1);

  @override
  String toString() => [
    year.toString().padLeft(4, '0'),
    if (month != null) month.toString().padLeft(2, '0'),
    if (day != null) day.toString().padLeft(2, '0'),
  ].join('-');
}

class YoutiPieSearchFilters {
  const YoutiPieSearchFilters({
    this.type = YoutiPieSearchType.all,
    this.sort = YoutiPieSearchSort.relevance,
    this.uploadDate = YoutiPieSearchUploadDate.none,
    this.after,
    this.before,
  });

  static const defaults = YoutiPieSearchFilters();
  static final _dateOperator = RegExp(r'(?:^|\s)(after|before):([^\s]+)');

  final YoutiPieSearchType type;
  final YoutiPieSearchSort sort;
  final YoutiPieSearchUploadDate uploadDate;
  final YoutiPieSearchDate? after, before;

  bool get hasDateRange => after != null || before != null;

  YoutiPieSearchFilters copyWith({
    YoutiPieSearchType? type,
    YoutiPieSearchSort? sort,
    YoutiPieSearchUploadDate? uploadDate,
    YoutiPieSearchDate? after,
    YoutiPieSearchDate? before,
    bool clearAfter = false,
    bool clearBefore = false,
  }) => YoutiPieSearchFilters(
    type: type ?? this.type,
    sort: sort ?? this.sort,
    uploadDate: uploadDate ?? this.uploadDate,
    after: clearAfter ? null : after ?? this.after,
    before: clearBefore ? null : before ?? this.before,
  );

  static ({YoutiPieSearchDate? after, YoutiPieSearchDate? before})? parseDateOperators(String text) {
    YoutiPieSearchDate? after;
    YoutiPieSearchDate? before;
    for (final match in _dateOperator.allMatches(text)) {
      final date = YoutiPieSearchDate.parse(match[2]!);
      if (match[1] == 'after') {
        after = date;
      } else {
        before = date;
      }
    }
    return after == null && before == null ? null : (after: after, before: before);
  }

  static String stripDateOperators(String text) => text.replaceAll(_dateOperator, ' ').trim();
}

class YoutiPieSearchOperators {
  const YoutiPieSearchOperators._(this.remainingText, this.phrases, this.titlePhrases, this.excluded);

  static final _operator = RegExp(r'(?:^|\s)(?:intitle:"([^"]+)"|"([^"]+)"|-"([^"]+)"|-([^\s]+))');

  final String remainingText;
  final List<String> phrases, titlePhrases, excluded;

  YoutiPieSearchMatchMode? get matchMode => titlePhrases.isNotEmpty
      ? YoutiPieSearchMatchMode.title
      : phrases.isNotEmpty ? YoutiPieSearchMatchMode.phrase : null;

  static YoutiPieSearchOperators? parse(String text) {
    final phrases = <String>[];
    final titlePhrases = <String>[];
    final excluded = <String>[];
    final remaining = text.replaceAllMapped(_operator, (match) {
      if (match[1] case final String title) {
        titlePhrases.add(title);
      } else if (match[2] case final String phrase) {
        phrases.add(phrase);
      } else {
        excluded.add((match[3] ?? match[4])!);
      }
      return ' ';
    }).trim();
    if (titlePhrases.isEmpty && phrases.isEmpty && excluded.isEmpty) return null;
    return YoutiPieSearchOperators._(remaining, phrases, titlePhrases, excluded);
  }

  static String buildQuery(String text, {required YoutiPieSearchMatchMode? matchMode, required List<String> excluded}) {
    final parsed = parse(text);
    final terms = parsed == null ? [text] : [parsed.remainingText, ...parsed.phrases, ...parsed.titlePhrases];
    final search = terms.where((term) => term.isNotEmpty).join(' ');
    return [
      if (search.isNotEmpty)
        switch (matchMode) {
          YoutiPieSearchMatchMode.phrase => '"$search"',
          YoutiPieSearchMatchMode.title => 'intitle:"$search"',
          null => search,
        },
      ...excluded.map((term) => '-"$term"'),
    ].join(' ');
  }
}
