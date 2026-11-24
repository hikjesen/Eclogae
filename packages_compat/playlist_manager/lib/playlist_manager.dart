import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_extensions/dart_extensions.dart' show DEFileUtils;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:nampack/reactive/reactive.dart';
import 'package:path/path.dart' as p;

import 'class/favourite_playlist.dart';
import 'class/general_playlist.dart';
import 'class/playlist_tags_filter.dart';
import 'core/enum.dart';
import 'module/playlist_id.dart';

export 'class/general_playlist.dart';
export 'class/playlist_tags_filter.dart';
export 'core/enum.dart';

abstract class PlaylistManager<T extends PlaylistItemWithDate, E, S> {
  final playlistsMap = <String, GeneralPlaylist<T, S>>{}.obs;
  final customIndicesOrderRx = Rxn<List<String>>();
  final _visibleCustomOrder = Rxn<List<String>>(<String>[]);
  final canReorderItems = false.obs;

  late final favouritesPlaylist = FavouritePlaylist<T, E, S>(_emptyFavourites(), identifyBy);
  late final tagsFilter = PlaylistTagsFilter(onTagsFilterChanged, (json) {
    _writeJsonSync(_tagsFile(playlistsMetadataDirectory), json);
  });

  final _playlistsLoaded = Completer<void>();
  final _favouritesLoaded = Completer<void>();
  Future<void> _pending = Future.value();
  int _customOrderModifiedDate = 0;

  Future<void> get waitForPlaylistsLoad => _playlistsLoaded.future;
  Future<void> get waitForFavouritePlaylistLoad => _favouritesLoaded.future;
  int get customOrderModifiedDate => _customOrderModifiedDate;

  String get playlistsDirectory;
  String get playlistsArtworksDirectory;
  String get playlistsMetadataDirectory;
  String get favouritePlaylistPath;
  bool get sortAfterPreparing;
  bool get addTracksAtBeginning;
  RegExp get cleanupFilenameRegex;

  // The controllers provide their localized validation strings.
  // ignore: non_constant_identifier_names
  String get EMPTY_NAME;
  // ignore: non_constant_identifier_names
  String get NAME_CONTAINS_BAD_CHARACTER;
  // ignore: non_constant_identifier_names
  String get SAME_NAME_EXISTS;
  // ignore: non_constant_identifier_names
  String get NAME_IS_NOT_ALLOWED;
  // ignore: non_constant_identifier_names
  String get PLAYLIST_NAME_FAV;
  // ignore: non_constant_identifier_names
  String get PLAYLIST_NAME_HISTORY;
  // ignore: non_constant_identifier_names
  String get PLAYLIST_NAME_MOST_PLAYED;

  E identifyBy(T item);
  Map<String, dynamic> itemToJson(T item);
  Object? sortToJson(List<S> items);
  Future<Map<String, GeneralPlaylist<T, S>>> prepareAllPlaylistsFunction();
  Future<GeneralPlaylist<T, S>?> prepareFavouritePlaylistFunction();
  FutureOr<bool> canRemovePlaylist(GeneralPlaylist<T, S> playlist);
  FutureOr<void> onPlaylistItemsSort(List<S> sorts, bool reverse, List<T> items);
  void sortPlaylists();
  void onPlaylistRemovedFromMap(List<String> names) {}
  FutureOr<void> onPlaylistTracksChanged(GeneralPlaylist<T, S> playlist) {}
  void onTagsFilterChanged() {}
  void onArtworkFileChanged(String artworkPath) {}
  void onReadOnlyPlaylistError() {}
  void onFavouritesChanged(Iterable<E>? items) {}

  int get _now => DateTime.now().millisecondsSinceEpoch;

  int _nextDate(int previous) {
    final now = _now;
    return now > previous ? now : previous + 1;
  }

  int? getMetadataEditDate(GeneralPlaylist<T, S> playlist) => _nextDate(playlist.modifiedDate);

  Future<R> _serialize<R>(FutureOr<R> Function() operation) {
    final previous = _pending;
    final finished = Completer<void>();
    _pending = finished.future;
    return previous.then((_) async {
      try {
        return await operation();
      } finally {
        finished.complete();
      }
    });
  }

  bool isOneOfDefaultPlaylists(String name) =>
      name == PLAYLIST_NAME_FAV || name == PLAYLIST_NAME_HISTORY || name == PLAYLIST_NAME_MOST_PLAYED;

  String? _invalidName(String name) {
    if (name.isEmpty) return EMPTY_NAME;
    if (cleanupFilenameRegex.hasMatch(name) || name.contains('/') || name.contains(r'\') || name.contains('\u0000')) {
      return NAME_CONTAINS_BAD_CHARACTER;
    }
    if (isOneOfDefaultPlaylists(name) || name == '.' || name == '..') return NAME_IS_NOT_ALLOWED;
    return null;
  }

  String? validatePlaylistName(String? value) {
    final name = (value ?? '').trim();
    return _invalidName(name) ?? (playlistsMap.value.containsKey(name) ? SAME_NAME_EXISTS : null);
  }

  GeneralPlaylist<T, S>? getPlaylist(String? name) =>
      name == PLAYLIST_NAME_FAV ? favouritesPlaylist.value : playlistsMap.value[name];

  File getFileForPlaylist(String name) =>
      name == PLAYLIST_NAME_FAV ? File(favouritePlaylistPath) : File(p.join(playlistsDirectory, '$name.json'));

  File getArtworkFileForPlaylist(String name) => File(p.join(playlistsArtworksDirectory, '$name.png'));
  File _orderFile(String directory) => File(p.join(directory, 'custom_order.json'));
  File _tagsFile(String directory) => File(p.join(directory, 'tags.json'));

  Map<String, dynamic> _readJson(File file) =>
      file.existsSync() ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic> : {};

  File _temporary(File file) => File('${file.path}${DEFileUtils.kAtomicTempSuffix}');

  void _writeJsonSync(File file, Map<String, dynamic> json) {
    file.parent.createSync(recursive: true);
    final temporary = _temporary(file);
    temporary.writeAsStringSync(jsonEncode(json), flush: true);
    temporary.renameSync(file.path);
  }

  Future<void> _writeBytes(File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    final temporary = _temporary(file);
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(file.path);
  }

  void _writeFavourites(GeneralPlaylist<T, S> playlist, Iterable<E>? changed) {
    _writeJsonSync(File(favouritePlaylistPath), playlist.toJson(itemToJson, sortToJson));
    favouritesPlaylist.value = playlist;
    onFavouritesChanged(changed);
  }

  GeneralPlaylist<T, S> _emptyFavourites() {
    final now = _now;
    return GeneralPlaylist<T, S>(
      name: PLAYLIST_NAME_FAV,
      tracks: [],
      creationDate: now,
      modifiedDate: now,
      isFav: true,
    );
  }

  Future<void> prepareDefaultPlaylistsFileAsync() => _serialize(() async {
    final loaded = await prepareFavouritePlaylistFunction();
    if (loaded != null) {
      favouritesPlaylist.value = loaded.copyWith(name: PLAYLIST_NAME_FAV, isFav: true);
      onFavouritesChanged(null);
    } else if (!File(favouritePlaylistPath).existsSync()) {
      _writeFavourites(favouritesPlaylist.value, null);
    }
    if (!_favouritesLoaded.isCompleted) _favouritesLoaded.complete();
  });

  Future<void> prepareAllPlaylistsFile() => _serialize(() async {
    await Directory(playlistsDirectory).create(recursive: true);
    await Directory(playlistsMetadataDirectory).create(recursive: true);
    final metadata = _readJson(_orderFile(playlistsMetadataDirectory));
    customIndicesOrderRx.value = (metadata['keys'] as List?)?.cast<String>();
    _customOrderModifiedDate = metadata['_mt'] as int? ?? 0;
    tagsFilter.load(_readJson(_tagsFile(playlistsMetadataDirectory)));
    playlistsMap.value = await prepareAllPlaylistsFunction();
    _updateLibrary(sort: false);
    if (!_playlistsLoaded.isCompleted) _playlistsLoaded.complete();
    if (sortAfterPreparing) sortPlaylists();
  });

  Future<bool> writePlaylistToStorage(GeneralPlaylist<T, S> playlist) async {
    final file = getFileForPlaylist(playlist.name);
    final json = playlist.toJson(itemToJson, sortToJson);
    await _writeBytes(file, JsonUtf8Encoder().convert(json));
    return true;
  }

  Future<void> _deleteFile(File file) async {
    if (await file.exists()) await file.delete();
  }

  Future<bool> renamePlaylistInStorage(GeneralPlaylist<T, S> playlist, String newName) async {
    if (!await writePlaylistToStorage(playlist.copyWith(name: newName))) return false;
    await _deleteFile(getFileForPlaylist(playlist.name));
    return true;
  }

  Future<bool> setArtworkForPlaylist(String playlistName, {required File? artworkFile, required Uint8List? artworkBytes}) => _serialize(() async {
    final file = getArtworkFileForPlaylist(playlistName);
    if (artworkFile == null && artworkBytes == null) {
      if (!await file.exists()) return false;
      await file.delete();
    } else {
      final bytes = artworkBytes ?? await artworkFile!.readAsBytes();
      await _writeBytes(file, bytes);
    }
    onArtworkFileChanged(file.path);
    return true;
  });

  void _updateLibrary({required bool sort}) {
    if (customIndicesOrderRx.value != null) ensureCustomOrderValid();
    tagsFilter.rebuild(playlistsMap.value.values);
    if (sort) sortPlaylists();
  }

  Future<bool> _save(
    GeneralPlaylist<T, S> playlist, {
    bool sort = true,
    bool tracksChanged = false,
    Iterable<E>? changedFavourites,
  }) async {
    if (playlist.name == PLAYLIST_NAME_FAV) {
      _writeFavourites(playlist, changedFavourites);
      return true;
    }
    if (!await writePlaylistToStorage(playlist)) return false;
    playlistsMap.value[playlist.name] = playlist;
    playlistsMap.refresh();
    _updateLibrary(sort: sort);
    if (tracksChanged) unawaited(Future<void>.sync(() => onPlaylistTracksChanged(playlist)));
    return true;
  }

  Iterable<T> _combineTracks(List<T> old, List<T> added, PlaylistAddDuplicateAction action) {
    final prepend = addTracksAtBeginning;
    switch (action) {
      case PlaylistAddDuplicateAction.justAddEverything:
        return prepend ? [...added, ...old] : [...old, ...added];
      case PlaylistAddDuplicateAction.addAllAndRemoveOldOnes:
        final keys = added.map(identifyBy).toSet();
        final kept = old.where((item) => !keys.contains(identifyBy(item)));
        return prepend ? [...added, ...kept] : [...kept, ...added];
      case PlaylistAddDuplicateAction.addOnlyMissing:
        final keys = old.map(identifyBy).toSet();
        final missing = added.where((item) => keys.add(identifyBy(item))).toList();
        return prepend ? [...missing, ...old] : [...old, ...missing];
      case PlaylistAddDuplicateAction.mergeAndSortByAddedDate:
        final items = <T>{...old, ...added}.toList();
        items.sort((a, b) => a.dateAddedMS.compareTo(b.dateAddedMS));
        return items;
      case PlaylistAddDuplicateAction.deleteAndCreateNewPlaylist:
        return added;
    }
  }

  Future<GeneralPlaylist<T, S>?> addNewPlaylistRaw(
    String name, {
    required List<E> tracks,
    required T Function(E, int, PlaylistID) convertItem,
    int? creationDate,
    int? modifiedDate,
    String comment = '',
    List<String> moods = const [],
    List<String> tags = const [],
    bool isPinned = false,
    String? m3uPath,
    required FutureOr<PlaylistAddDuplicateAction?> Function() actionIfAlreadyExists,
  }) async {
    name = name.trim();
    if (_invalidName(name) != null) return null;
    final existing = playlistsMap.value[name];
    final action = existing == null ? null : await actionIfAlreadyExists();
    if (existing != null && action == null) return null;

    return _serialize(() async {
      final current = playlistsMap.value[name];
      if (current != null && action == null) return null;
      if (current?.isReadOnly == true) {
        onReadOnlyPlaylistError();
        return null;
      }

      final now = _now;
      var dateAdded = now;
      final id = PlaylistID(id: name);
      final items = [for (final track in tracks) convertItem(track, dateAdded++, id)];
      final GeneralPlaylist<T, S> playlist;
      if (current == null || action == PlaylistAddDuplicateAction.deleteAndCreateNewPlaylist) {
        playlist = GeneralPlaylist<T, S>(
          name: name,
          tracks: items,
          creationDate: creationDate ?? now,
          modifiedDate: modifiedDate ?? creationDate ?? now,
          comment: comment,
          moods: List.of(moods),
          tags: PlaylistTagsFilter.normalizeTags(tags),
          pinnedDate: isPinned ? now : null,
          m3uPath: m3uPath,
        );
      } else {
        final combined = _combineTracks(computeCustomOrder(current) ?? current.tracks, items, action!).toList();
        playlist = await _withTracks(current, combined, modifiedDate: modifiedDate);
      }
      return await _save(playlist, tracksChanged: current != null) ? playlist : null;
    });
  }

  GeneralPlaylist<T, S>? _editablePlaylist(String name) {
    final playlist = getPlaylist(name);
    if (playlist?.isReadOnly == true) {
      onReadOnlyPlaylistError();
      return null;
    }
    return playlist;
  }

  Future<int?> addTracksToPlaylistRaw(
    GeneralPlaylist<T, S> playlist,
    List<E> tracks,
    FutureOr<PlaylistAddDuplicateAction?> Function()? chooseAction,
    T Function(E, int) convertItem,
  ) async {
    final name = playlist.name;
    final initial = _editablePlaylist(name);
    if (initial == null) return null;
    if (tracks.isEmpty) return 0;
    final keys = initial.tracks.map(identifyBy).toSet();
    final hasDuplicates = tracks.any(keys.contains);
    final action = hasDuplicates && chooseAction != null ? await chooseAction() : PlaylistAddDuplicateAction.justAddEverything;
    if (action == null) return null;

    int addedCount = 0;
    final saved = await _editTracks(name, (current, old) {
      var dateAdded = _now;
      final effectiveAction = current.isFav && action == PlaylistAddDuplicateAction.justAddEverything ? PlaylistAddDuplicateAction.addOnlyMissing : action;
      final items = [for (final track in tracks) convertItem(track, dateAdded++)];
      final combined = _combineTracks(old, items, effectiveAction).toList();
      if (effectiveAction == PlaylistAddDuplicateAction.addOnlyMissing) {
        addedCount = combined.length - old.length;
      } else if (effectiveAction == PlaylistAddDuplicateAction.mergeAndSortByAddedDate) {
        addedCount = items.toSet().difference(old.toSet()).length;
      } else {
        addedCount = items.length;
      }
      return addedCount == 0 ? null : combined;
    }, changedFavourites: tracks);
    return saved ? addedCount : null;
  }

  List<T>? computeCustomOrder(GeneralPlaylist<T, S> playlist) {
    final order = playlist.customOrder;
    if (order == null) return null;
    final remaining = <T, int>{};
    for (final item in playlist.tracks) {
      remaining.update(item, (count) => count + 1, ifAbsent: () => 1);
    }
    final result = <T>[];
    void take(T item) {
      final count = remaining[item];
      if (count == null) return;
      result.add(item);
      if (count == 1) {
        remaining.remove(item);
      } else {
        remaining[item] = count - 1;
      }
    }
    order.forEach(take);
    if (remaining.isNotEmpty) playlist.tracks.forEach(take);
    return result;
  }

  Future<GeneralPlaylist<T, S>> ensureNewSourceItemsSorted(GeneralPlaylist<T, S> playlist) async {
    final sorts = playlist.sortsType;
    if (sorts == null || sorts.isEmpty) return playlist;
    final sorted = List<T>.of(playlist.tracks);
    await onPlaylistItemsSort(sorts, playlist.sortReverse, sorted);
    return playlist.copyWith(tracks: sorted, customOrder: playlist.tracks);
  }

  Future<GeneralPlaylist<T, S>> _withTracks(GeneralPlaylist<T, S> playlist, List<T> tracks, {int? modifiedDate}) =>
      ensureNewSourceItemsSorted(playlist.copyWith(
        tracks: tracks,
        modifiedDate: modifiedDate ?? _nextDate(playlist.modifiedDate),
        clearCustomOrder: true,
      ));

  Future<int> importTracksToPlaylist(GeneralPlaylist<T, S> playlist, Iterable<T> tracks) async {
    final incoming = tracks.toList();
    var addedCount = 0;
    final saved = await _editTracks(playlist.name, (current, old) {
      final keys = old.map(identifyBy).toSet();
      final added = incoming.where((item) => keys.add(identifyBy(item))).toList();
      addedCount = added.length;
      if (added.isEmpty) return null;
      return addTracksAtBeginning && !current.isFav ? [...added, ...old] : [...old, ...added];
    }, changedFavourites: incoming.map(identifyBy));
    return saved ? addedCount : 0;
  }

  Future<void> removeTracksFromPlaylist(GeneralPlaylist<T, S> playlist, List<int> indexes) async {
    final removed = [for (final index in indexes.toSet()) playlist.tracks[index]];
    if (removed.isEmpty) return;
    await _editTracks(playlist.name, (current, items) {
      final tracks = List<T>.of(items);
      for (final item in removed) {
        tracks.remove(item);
      }
      return tracks.length == items.length ? null : tracks;
    }, changedFavourites: removed.map(identifyBy));
  }

  Future<void> insertTracksInPlaylist(GeneralPlaylist<T, S> playlist, List<T> tracks, int index) =>
      _editTrackOrder(playlist, (items) => items.insertAll(index.clamp(0, items.length).toInt(), tracks));

  Future<void> insertTracksInPlaylistWithEachIndex(GeneralPlaylist<T, S> playlist, Map<T, int> indexes) =>
      _editTrackOrder(playlist, (items) {
        final entries = indexes.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
        for (final entry in entries) {
          items.insert(entry.value.clamp(0, items.length).toInt(), entry.key);
        }
      });

  Future<void> reorderTrack(GeneralPlaylist<T, S> playlist, int oldIndex, int newIndex) async {
    final moved = playlist.tracks[oldIndex];
    final anchor = newIndex == playlist.tracks.length ? null : playlist.tracks[newIndex];
    await _editTracks(playlist.name, (current, items) {
      final tracks = List<T>.of(items);
      if (!tracks.remove(moved)) return null;
      final dropIndex = anchor == null ? tracks.length : tracks.indexOf(anchor);
      tracks.insert(dropIndex < 0 ? oldIndex.clamp(0, tracks.length).toInt() : dropIndex, moved);
      return tracks;
    });
  }

  Future<void> _editTrackOrder(GeneralPlaylist<T, S> playlist, void Function(List<T>) edit) async {
    await _editTracks(playlist.name, (current, items) {
      final tracks = List<T>.of(items);
      edit(tracks);
      return tracks;
    });
  }

  Future<bool> _editTracks(
    String name,
    List<T>? Function(GeneralPlaylist<T, S> playlist, List<T> items) edit, {
    Iterable<E>? changedFavourites,
  }) => _serialize(() async {
    while (true) {
      final current = _editablePlaylist(name);
      if (current == null) return false;
      var tracks = edit(current, computeCustomOrder(current) ?? current.tracks);
      if (tracks == null) return true;
      if (name == PLAYLIST_NAME_FAV) {
        final seen = <E>{};
        tracks = tracks.where((item) => seen.add(identifyBy(item))).toList();
      }
      final updated = await _withTracks(current, tracks);
      // The like button changes favourites synchronously, including while a sorter is awaiting data.
      if (name == PLAYLIST_NAME_FAV && !identical(current, favouritesPlaylist.value)) continue;
      return _save(updated, tracksChanged: true, changedFavourites: changedFavourites);
    }
  });

  void resetCanReorder() => canReorderItems.value = false;

  bool toggleTrackFavourite(T item) {
    final current = favouritesPlaylist.value;
    final key = identifyBy(item);
    final wasFavourite = favouritesPlaylist.isSubItemFavourite(key);
    List<T> toggle(List<T> items) => [
      for (final old in items)
        if (!wasFavourite || identifyBy(old) != key) old,
      if (!wasFavourite) item,
    ];
    final order = computeCustomOrder(current);
    final updated = current.copyWith(
      tracks: toggle(current.tracks),
      customOrder: order == null ? null : toggle(order),
      modifiedDate: _nextDate(current.modifiedDate),
    );
    _writeFavourites(updated, [key]);
    final sorts = updated.sortsType;
    if (!wasFavourite && sorts != null && sorts.isNotEmpty) {
      unawaited(_editTracks(PLAYLIST_NAME_FAV, (current, items) => items, changedFavourites: const []));
    }
    return !wasFavourite;
  }

  Future<void> updatePropertyInPlaylist(
    String? name, {
    List<T>? tracks,
    Iterable<E>? tracksRaw,
    T Function(E, int)? convertItem,
    int? creationDate,
    int? modifiedDate,
    String? comment,
    List<String>? moods,
    List<String>? tags,
    bool? isFav,
    String? m3uPath,
    PlaylistRemoteSource? remoteSource,
    List<S>? itemsSortType,
    bool? itemsSortReverse,
    bool restoreCustomOrder = false,
    bool tracksFromNewSource = false,
  }) => _serialize(() async {
    final tracksChanged = tracks != null || tracksRaw != null;
    final sortsChanged = itemsSortType != null || itemsSortReverse != null;
    final metadataChanged = comment != null || moods != null || tags != null;
    while (true) {
      final current = getPlaylist(name);
      if (current == null) return;
      if (tracksChanged && current.isReadOnly && !tracksFromNewSource) {
        onReadOnlyPlaylistError();
        return;
      }
      var updated = current.copyWith(
        creationDate: creationDate,
        modifiedDate: modifiedDate ?? (metadataChanged ? getMetadataEditDate(current) : _nextDate(current.modifiedDate)),
        comment: comment,
        moods: moods,
        tags: tags == null ? null : PlaylistTagsFilter.normalizeTags(tags),
        isFav: isFav,
        m3uPath: m3uPath,
        remoteSource: remoteSource,
        sortsType: itemsSortType,
        sortReverse: itemsSortReverse,
      );

      if (tracksChanged || sortsChanged) {
        final customOrder = computeCustomOrder(current);
        final sorted = updated.sortsType?.isNotEmpty == true;
        final nextTracks = tracksRaw != null
            ? _convertSourceTracks(tracksRaw, customOrder ?? current.tracks, convertItem!)
            : tracks ?? ((sorted || restoreCustomOrder ? customOrder : null) ?? current.tracks);
        updated = await ensureNewSourceItemsSorted(updated.copyWith(tracks: List.of(nextTracks), clearCustomOrder: true));
      }
      if (name == PLAYLIST_NAME_FAV && !identical(current, favouritesPlaylist.value)) continue;
      final saved = await _save(updated, tracksChanged: tracksChanged && !tracksFromNewSource);
      if (saved && current.m3uPath == null && updated.m3uPath != null && !tracksFromNewSource) {
        await _deleteFile(getFileForPlaylist(current.name));
      }
      return;
    }
  });

  List<T> _convertSourceTracks(Iterable<E> tracks, List<T> original, T Function(E, int) convert) {
    final previous = <E, Queue<T>>{};
    for (final item in original) {
      (previous[identifyBy(item)] ??= Queue<T>()).addLast(item);
    }
    var dateAdded = _now;
    final converted = <T>[];
    for (final key in tracks) {
      final queue = previous[key];
      converted.add(queue != null && queue.isNotEmpty ? queue.removeFirst() : convert(key, dateAdded++));
    }
    return converted;
  }

  Future<void> updatePlaylistMetadata(String name, {String? comment, List<String>? moods, List<String>? tags, bool? isPinned}) =>
      updatePlaylistsMetadata({name: PlaylistMetadataEdit(comment: comment, moods: moods, tags: tags, isPinned: isPinned)});

  Future<void> updatePlaylistsMetadata(Map<String, PlaylistMetadataEdit> edits) => _serialize(() async {
    var changed = false;
    for (final entry in edits.entries) {
      final playlist = getPlaylist(entry.key);
      if (playlist == null) continue;
      final edit = entry.value;
      final tags = edit.tags == null ? null : PlaylistTagsFilter.normalizeTags(edit.tags!);
      if ((edit.comment == null || edit.comment == playlist.comment) &&
          (edit.moods == null || listEquals(edit.moods, playlist.moods)) &&
          (tags == null || listEquals(tags, playlist.tags)) &&
          (edit.isPinned == null || edit.isPinned == playlist.isPinned)) {
        continue;
      }
      final updated = playlist.copyWith(
        comment: edit.comment,
        moods: edit.moods,
        tags: tags,
        isPinned: edit.isPinned,
        modifiedDate: getMetadataEditDate(playlist),
      );
      if (await _save(updated, sort: false)) changed = true;
    }
    if (changed) sortPlaylists();
  });

  Map<String, int> computeTagsCounts() => {
    for (final path in tagsFilter.allPaths) path: tagsFilter.playlistsCountOf(path),
  };

  Map<String, int> computeMoodsCounts() {
    final counts = <String, int>{};
    for (final playlist in playlistsMap.value.values) {
      for (final mood in playlist.moods.toSet()) {
        counts.update(mood, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  Future<void> renameTag(String path, String replacement) async {
    final normalized = PlaylistTagsFilter.normalizeTags([replacement]).firstOrNull;
    if (normalized == null || normalized == path) return;
    await _changeTag(path, normalized);
  }

  Future<void> removeTag(String path) => _changeTag(path, null);

  Future<void> _changeTag(String path, String? replacement) async {
    String? remap(String tag) {
      if (tag == path) return replacement;
      if (!tag.startsWith('$path${PlaylistTagsFilter.separator}')) return tag;
      return replacement == null ? null : '$replacement${tag.substring(path.length)}';
    }

    final edits = <String, PlaylistMetadataEdit>{};
    for (final playlist in playlistsMap.value.values) {
      final updated = playlist.tags.map(remap).nonNulls.toSet().toList();
      if (!listEquals(updated, playlist.tags)) {
        edits[playlist.name] = PlaylistMetadataEdit(tags: updated);
      }
    }
    await updatePlaylistsMetadata(edits);
    tagsFilter.remapPaths(remap);
  }

  Future<void> replaceTheseTracksInFavourites(bool Function(T) test, T Function(T) convert) async {
    await _editTracks(PLAYLIST_NAME_FAV, (current, items) {
      if (!items.any(test)) return null;
      return [for (final item in items) test(item) ? convert(item) : item];
    });
  }

  Future<void> replaceTheseTracksInPlaylists(bool Function(T) test, T Function(T) convert) async {
    await replaceTheseTracksInFavourites(test, convert);
    await _serialize(() async {
      final playlists = playlistsMap.value.values.toList();
      for (final playlist in playlists) {
        if (playlist.isReadOnly || !playlist.tracks.any(test)) continue;
        final updated = playlist.copyWithConvertedTracks((item) => test(item) ? convert(item) : item);
        await _save(updated.copyWith(modifiedDate: _nextDate(playlist.modifiedDate)), sort: false, tracksChanged: true);
      }
      sortPlaylists();
    });
  }

  Future<bool> renamePlaylist(String playlistName, String newName, {bool keepModifiedDate = false}) => _serialize(() async {
    final playlist = _editablePlaylist(playlistName);
    if (playlist == null || playlist.isFav || validatePlaylistName(newName) != null) return false;
    final renamedName = newName.trim();
    final updated = playlist.copyWith(modifiedDate: keepModifiedDate ? null : getMetadataEditDate(playlist));
    if (!await renamePlaylistInStorage(updated, renamedName)) return false;
    final renamed = updated.copyWith(name: renamedName);
    if (renamed.m3uPath != null && !await writePlaylistToStorage(renamed)) return false;
    final renamedEntries = {
      for (final entry in playlistsMap.value.entries)
        if (entry.key == playlistName) renamedName: renamed else entry.key: entry.value,
    };
    final order = customIndicesOrderRx.value;
    if (order != null && order.contains(playlistName)) {
      _setCustomOrder(order.map((name) => name == playlistName ? renamedName : name), customOrderModifiedDate);
    }
    playlistsMap.value = renamedEntries;
    _updateLibrary(sort: true);

    final oldArtwork = getArtworkFileForPlaylist(playlistName);
    if (await oldArtwork.exists()) {
      final newArtwork = getArtworkFileForPlaylist(renamedName);
      await oldArtwork.rename(newArtwork.path);
      onArtworkFileChanged(oldArtwork.path);
      onArtworkFileChanged(newArtwork.path);
    }
    return true;
  });

  Future<void> removePlaylist(GeneralPlaylist<T, S> playlist) => removePlaylists([playlist.name]);

  Future<void> removePlaylists(List<String> names, {bool deleteFiles = true}) => _serialize(() async {
    final removed = <String>[];
    for (final name in names) {
      final playlist = playlistsMap.value[name];
      if (playlist == null || !await canRemovePlaylist(playlist)) continue;
      if (deleteFiles) {
        await _deleteFile(getFileForPlaylist(name));
        final artwork = getArtworkFileForPlaylist(name);
        await _deleteFile(artwork);
        onArtworkFileChanged(artwork.path);
      }
      playlistsMap.value.remove(name);
      removed.add(name);
    }
    if (removed.isEmpty) return;
    final order = customIndicesOrderRx.value;
    if (deleteFiles && order != null && removed.any(order.contains)) {
      _setCustomOrder(order.where((name) => !removed.contains(name)), customOrderModifiedDate);
    }
    playlistsMap.refresh();
    onPlaylistRemovedFromMap(removed);
    _updateLibrary(sort: true);
  });

  Future<void> reAddPlaylist(GeneralPlaylist<T, S> playlist, int modifiedDate, {Uint8List? artworkBytes}) async {
    final saved = await importPlaylistForce(playlist.copyWith(modifiedDate: modifiedDate));
    if (saved && artworkBytes != null) {
      await setArtworkForPlaylist(playlist.name, artworkFile: null, artworkBytes: artworkBytes);
    }
  }

  Future<bool> importPlaylistForce(GeneralPlaylist<T, S> playlist, {bool sortPlaylists = true, bool tracksFromNewSource = false}) =>
      _serialize(() async {
        if (_invalidName(playlist.name) != null) return false;
        final updated = tracksFromNewSource ? await ensureNewSourceItemsSorted(playlist) : playlist;
        return _save(updated, sort: sortPlaylists);
      });

  Future<int> importPlaylistsIfNewer(Iterable<GeneralPlaylist<T, S>> playlists) => _serialize(() async {
    var imported = 0;
    for (final playlist in playlists) {
      if (_invalidName(playlist.name) != null) continue;
      final current = playlistsMap.value[playlist.name];
      if (current != null && (current.modifiedDate > playlist.modifiedDate || current.isReadOnly)) continue;
      if (await _save(playlist, sort: false)) imported++;
    }
    if (imported > 0) sortPlaylists();
    return imported;
  });

  Future<List<GeneralPlaylist<T, S>>> renameSyncedPlaylists(
    Iterable<GeneralPlaylist<T, S>> playlists,
    Map<String, String> renamedFromByName,
  ) async {
    final incoming = playlists.toList();
    final incomingNames = incoming.map((playlist) => playlist.name).toSet();
    final result = <GeneralPlaylist<T, S>>[];
    for (final playlist in incoming) {
      final oldName = renamedFromByName[playlist.name];
      final old = getPlaylist(oldName);
      if (old != null &&
          old.canSyncRenames &&
          playlist.canSyncRenames &&
          old.creationDate == playlist.creationDate &&
          !incomingNames.contains(oldName) &&
          !playlistsMap.value.containsKey(playlist.name)) {
        if (old.modifiedDate > playlist.modifiedDate) continue;
        if (!await renamePlaylist(old.name, playlist.name, keepModifiedDate: true)) continue;
      }
      result.add(playlist);
    }
    return result;
  }

  Rxn<List<String>> getCustomIndicesOrderListRx() => _visibleCustomOrder;

  void ensureCustomOrderValid({bool removeNonExistent = false}) {
    final keys = playlistsMap.value.keys;
    final old = customIndicesOrderRx.value;
    final current = old ?? const <String>[];
    final order = [
      ...{
        ...current.where((name) => !removeNonExistent || playlistsMap.value.containsKey(name)),
        ...keys,
      },
    ];
    if (!listEquals(old, order)) {
      _setCustomOrder(order, customOrderModifiedDate);
    } else {
      _updateVisibleOrder(order);
    }
  }

  void onPlaylistReorder(int oldIndex, int newIndex) {
    final order = List<String>.of(_visibleCustomOrder.value!);
    if (newIndex > oldIndex) newIndex--;
    order.insert(newIndex, order.removeAt(oldIndex));
    final reordered = order.iterator;
    final fullOrder = customIndicesOrderRx.value!.map((name) {
      if (!playlistsMap.value.containsKey(name)) return name;
      reordered.moveNext();
      return reordered.current;
    }).toList();
    _setCustomOrder(fullOrder, _nextDate(customOrderModifiedDate));
    sortPlaylists();
  }

  bool importCustomOrderIfNewer(List<String> order, int modifiedDate) {
    if (modifiedDate <= customOrderModifiedDate) return false;
    _setCustomOrder([...order, ...playlistsMap.value.keys], modifiedDate);
    sortPlaylists();
    return true;
  }

  void _setCustomOrder(Iterable<String> names, int date) {
    final order = names.toSet().toList();
    _writeJsonSync(_orderFile(playlistsMetadataDirectory), {'keys': order, '_mt': date});
    _customOrderModifiedDate = date;
    customIndicesOrderRx.value = order;
    _updateVisibleOrder(order);
  }

  void _updateVisibleOrder(List<String> order) {
    final visible = order.where(playlistsMap.value.containsKey).toList();
    if (!listEquals(_visibleCustomOrder.value, visible)) _visibleCustomOrder.value = visible;
  }

  Future<void> mergeMetadataFrom(String directory) => _serialize(() {
    final order = _readJson(_orderFile(directory));
    final keys = (order['keys'] as List?)?.cast<String>();
    if (keys != null) {
      final date = order['_mt'] as int? ?? 0;
      if (customIndicesOrderRx.value == null) {
        _setCustomOrder([...keys, ...playlistsMap.value.keys], date);
        sortPlaylists();
      } else {
        importCustomOrderIfNewer(keys, date);
      }
    }
    final tags = _readJson(_tagsFile(directory));
    if (tags.isNotEmpty) tagsFilter.load(tags, merge: true);
  });
}
