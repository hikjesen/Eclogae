import 'package:nampack/reactive/reactive.dart';

import 'general_playlist.dart';

class FavouritePlaylist<T, E, S> extends Rx<GeneralPlaylist<T, S>> {
  final E Function(T) _identifyBy;
  Map<E, T> _items;

  FavouritePlaylist(GeneralPlaylist<T, S> playlist, E Function(T) identifyBy)
    : _identifyBy = identifyBy,
      _items = _index(playlist.tracks, identifyBy),
      super(playlist);

  static Map<E, T> _index<T, E>(List<T> items, E Function(T) identifyBy) {
    final index = <E, T>{};
    for (final item in items) {
      index.putIfAbsent(identifyBy(item), () => item);
    }
    return index;
  }

  @override
  set value(GeneralPlaylist<T, S> playlist) {
    this.set(playlist);
    refresh();
  }

  @override
  void set(GeneralPlaylist<T, S> playlist) {
    _items = _index(playlist.tracks, _identifyBy);
    super.set(playlist);
  }

  bool isItemFavourite(T item) => isSubItemFavourite(_identifyBy(item));
  bool isSubItemFavourite(E item) => _items.containsKey(item);

  ({T item})? firstItemForSubItem(E item) {
    final match = _items[item];
    return match == null ? null : (item: match);
  }
}
