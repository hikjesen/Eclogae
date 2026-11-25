import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'lx_bridge_service.dart';
import 'lx_models.dart';
import 'lx_user_api_store.dart';

class LxPagedState<T> {
  const LxPagedState._({
    this.query = '',
    this.items = const [],
    this.page = 0,
    this.total = 0,
    this.limit = 0,
    this.maxPage = 0,
    this.maxPagesByPlatform = const {},
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final String query;
  final List<T> items;
  final int page;
  final int total;
  final int limit;
  final int maxPage;
  final Map<LxPlatform, int> maxPagesByPlatform;
  final bool loading;
  final bool loadingMore;
  final String? error;

  bool get hasMore => maxPagesByPlatform.isEmpty ? page < maxPage : maxPagesByPlatform.values.any((max) => page < max);

  LxPagedState<T> _withStatus({bool loading = false, bool loadingMore = false, String? error}) => LxPagedState<T>._(
    query: query,
    items: items,
    page: page,
    total: total,
    limit: limit,
    maxPage: maxPage,
    maxPagesByPlatform: maxPagesByPlatform,
    loading: loading,
    loadingMore: loadingMore,
    error: error,
  );
}

typedef _SearchPage<T> = ({List<T> items, int total, int limit, int maxPage});

class LxSearchController extends ChangeNotifier {
  LxSearchController._();

  static final inst = LxSearchController._();
  final _bridge = LxBridgeService.inst;
  final _store = LxUserApiStore();
  final _songs = <LxSearchSource, LxPagedState<LxTrack>>{};
  final _songlists = <LxSearchSource, LxPagedState<LxSonglist>>{};

  LxSearchMode _mode = LxSearchMode.songs;
  LxSearchSource _source = LxSearchSource.all;
  String _inputText = '';
  String _submittedKeyword = '';
  List<String> _history = const [];
  List<String> _tips = const [];
  bool _tipsVisible = false;

  LxSearchMode get mode => _mode;
  LxSearchSource get source => _source;
  String get inputText => _inputText;
  String get submittedKeyword => _submittedKeyword;
  List<String> get history => _history;
  List<String> get tips => _tips;
  bool get tipsVisible => _tipsVisible;

  double songsScrollOffset = 0;
  double songlistsScrollOffset = 0;

  LxPagedState<LxTrack> get songState => songStateFor(source);
  LxPagedState<LxSonglist> get songlistState => songlistStateFor(source);
  LxPagedState<LxTrack> songStateFor(LxSearchSource source) => _songs[source] ?? const LxPagedState<LxTrack>._();
  LxPagedState<LxSonglist> songlistStateFor(LxSearchSource source) => _songlists[source] ?? const LxPagedState<LxSonglist>._();

  Future<void>? _historyLoad;
  Future<void> _historyWrites = Future.value();
  Timer? _tipTimer;
  int _tipSeq = 0;

  Future<void> ensureHistoryLoaded() => _historyLoad ??= _loadHistory();

  Future<void> _loadHistory() async {
    try {
      _history = List.unmodifiable(await _store.loadSearchHistory());
    } catch (_) {
      _historyLoad = null;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> _saveHistory(List<String> keywords) async {
    final updated = List<String>.unmodifiable(keywords.take(LxUserApiStore.maxSearchHistory));
    final previousWrite = _historyWrites;
    final done = Completer<void>();
    _historyWrites = done.future;
    _history = updated;
    notifyListeners();
    try {
      await previousWrite;
      await _store.saveSearchHistory(updated);
    } finally {
      done.complete();
    }
  }

  Future<void> _recordHistory(String keyword) async {
    await ensureHistoryLoaded();
    await _saveHistory([keyword, ...history.where((entry) => entry != keyword)]);
  }

  Future<void> removeHistory(String keyword) async {
    await ensureHistoryLoaded();
    await _saveHistory(history.where((entry) => entry != keyword).toList());
  }

  Future<void> clearHistory() async {
    await ensureHistoryLoaded();
    await _saveHistory(const []);
  }

  void _clearTips() {
    _tipTimer?.cancel();
    _tipSeq++;
    _tips = const [];
    _tipsVisible = false;
  }

  void onInputChanged(String text) {
    if (_inputText == text) return;
    _inputText = text;
    _clearTips();
    final keyword = text.trim();
    if (keyword.isNotEmpty) {
      _tipsVisible = true;
      final seq = _tipSeq;
      _tipTimer = Timer(const Duration(milliseconds: 220), () async {
        final List<String> result;
        try {
          result = await _bridge.tipSearch(keyword);
        } catch (_) {
          // Suggestions are optional. A transient failure should leave manual search available.
          return;
        }
        if (seq != _tipSeq) return;
        _tips = result;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void setTipsVisible(bool visible) {
    final next = visible && inputText.trim().isNotEmpty;
    if (_tipsVisible == next) return;
    _tipsVisible = next;
    notifyListeners();
  }

  void setMode(LxSearchMode next) {
    if (_mode == next) return;
    _mode = next;
    _onSearchContextChanged();
  }

  void setSource(LxSearchSource next) {
    if (_source == next) return;
    _source = next;
    _onSearchContextChanged();
  }

  LxPagedState<Object> get _activeState => mode == LxSearchMode.songs ? songState : songlistState;

  void _onSearchContextChanged() {
    if (submittedKeyword.isNotEmpty && _activeState.query != submittedKeyword) {
      unawaited(_search(submittedKeyword));
    } else {
      notifyListeners();
    }
  }

  Future<void> submitSearch(String rawKeyword, {bool forceRefresh = false}) async {
    final keyword = rawKeyword.trim();
    _inputText = rawKeyword;
    _clearTips();
    if (keyword.isEmpty) {
      notifyListeners();
      return;
    }
    if (submittedKeyword != keyword) {
      songsScrollOffset = 0;
      songlistsScrollOffset = 0;
    }
    _submittedKeyword = keyword;
    await Future.wait([_search(keyword, forceRefresh: forceRefresh), _recordHistory(keyword)]);
  }

  Future<void> loadMore() async {
    final state = _activeState;
    if (state.query != submittedKeyword || state.loading || state.loadingMore || !state.hasMore) return;
    await _search(submittedKeyword, page: state.page + 1);
  }

  Future<void> refresh() async {
    if (submittedKeyword.isNotEmpty) await _search(submittedKeyword, forceRefresh: true);
  }

  Future<void> _search(String query, {int page = 1, bool forceRefresh = false}) {
    return switch (mode) {
      LxSearchMode.songs => _searchPage(
        _songs,
        songState,
        source,
        query,
        page,
        forceRefresh,
        fetch: (platform) async {
          final result = await _bridge.search(platform: platform, keyword: query, page: page);
          return (items: result.tracks, total: result.total, limit: result.limit, maxPage: result.allPage);
        },
        keyOf: (track) => track.uniqueKey,
        titleOf: (track) => '${track.name} ${track.singer}',
      ),
      LxSearchMode.songlists => _searchPage(
        _songlists,
        songlistState,
        source,
        query,
        page,
        forceRefresh,
        fetch: (platform) async {
          final result = await _bridge.searchSonglist(platform: platform, keyword: query, page: page);
          final maxPage = result.hasMore ? (result.total + result.limit - 1) ~/ result.limit : page;
          return (items: result.list, total: result.total, limit: result.limit, maxPage: maxPage);
        },
        keyOf: (songlist) => songlist.uniqueKey,
        titleOf: (songlist) => songlist.name,
      ),
    };
  }

  Future<void> _searchPage<T>(
    Map<LxSearchSource, LxPagedState<T>> cache,
    LxPagedState<T> previous,
    LxSearchSource source,
    String query,
    int page,
    bool forceRefresh, {
    required Future<_SearchPage<T>> Function(LxPlatform) fetch,
    required String Function(T) keyOf,
    required String Function(T) titleOf,
  }) async {
    final sameQuery = previous.query == query;
    if (page == 1 && sameQuery && !forceRefresh && (previous.loading || previous.items.isNotEmpty)) {
      notifyListeners();
      return;
    }

    final state = sameQuery ? previous : LxPagedState<T>._(query: query);
    // The loading snapshot is the request token for this mode and source.
    final request = cache[source] = state._withStatus(loading: page == 1, loadingMore: page > 1);
    notifyListeners();
    try {
      final platform = source.platform;
      final maxPages = <LxPlatform, int>{if (page > 1) ...state.maxPagesByPlatform};
      final List<T> pageItems;
      final int total;
      final int limit;
      final int maxPage;
      if (platform != null) {
        final result = await fetch(platform);
        pageItems = result.items;
        total = result.total;
        limit = result.limit;
        maxPage = result.maxPage;
      } else {
        final platforms = LxPlatform.values.where((p) => page == 1 || (maxPages[p] ?? 0) >= page);
        final results = await _fetchAggregate(platforms, fetch);
        for (final entry in results.entries) {
          maxPages[entry.key] = entry.value.maxPage;
        }
        final items = results.values.expand((result) => result.items);
        final ranked = [
          for (final (index, item) in items.indexed) (item: item, score: _similar(query, titleOf(item)), index: index),
        ]..sort((a, b) {
          final scoreOrder = b.score.compareTo(a.score);
          return scoreOrder == 0 ? a.index.compareTo(b.index) : scoreOrder;
        });
        pageItems = ranked.map((entry) => entry.item).toList();
        total = results.values.map((result) => result.total).reduce(math.max);
        limit = results.values.map((result) => result.limit).reduce(math.max);
        maxPage = maxPages.values.reduce(math.max);
      }
      if (!identical(request, cache[source])) return;
      final seen = <String>{};
      cache[source] = LxPagedState<T>._(
        query: query,
        items: List.unmodifiable([
          for (final item in [if (page > 1) ...state.items, ...pageItems])
            if (seen.add(keyOf(item))) item,
        ]),
        page: page,
        total: total,
        limit: limit,
        maxPage: maxPage,
        maxPagesByPlatform: Map.unmodifiable(maxPages),
      );
    } catch (error) {
      if (!identical(request, cache[source])) return;
      cache[source] = state._withStatus(error: error.toString());
    }
    notifyListeners();
  }

  Future<Map<LxPlatform, _SearchPage<T>>> _fetchAggregate<T>(
    Iterable<LxPlatform> platforms,
    Future<_SearchPage<T>> Function(LxPlatform) fetch,
  ) async {
    Future<({LxPlatform platform, _SearchPage<T>? result, Object? error})> searchPlatform(LxPlatform platform) async {
      try {
        return (platform: platform, result: await fetch(platform), error: null);
      } catch (error) {
        return (platform: platform, result: null, error: error);
      }
    }

    final attempts = await Future.wait(platforms.map(searchPlatform));
    final successes = {
      for (final attempt in attempts) attempt.platform: ?attempt.result,
    };
    if (successes.isEmpty) throw attempts.first.error!;
    return successes;
  }

  static double _similar(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final row = List.generate(b.length + 1, (index) => index);
    for (var i = 1; i <= a.length; i++) {
      var diagonal = row[0];
      row[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final substitution = diagonal + (a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1);
        diagonal = row[j];
        row[j] = math.min(math.min(row[j] + 1, row[j - 1] + 1), substitution);
      }
    }
    return 1 - row.last / math.max(a.length, b.length);
  }
}
