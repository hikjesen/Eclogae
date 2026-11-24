import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:playlist_manager/playlist_manager.dart';

void main() {
  late Directory storage;
  late _Manager manager;

  setUp(() async {
    storage = Directory.systemTemp.createTempSync('playlist_manager_test');
    manager = _Manager(storage);
    await manager.prepareDefaultPlaylistsFileAsync();
    await manager.prepareAllPlaylistsFile();
  });

  tearDown(() => storage.deleteSync(recursive: true));

  test('playlist edits, manual order, metadata and favourites survive a reload', () async {
    final created = await manager.addNewPlaylistRaw(
      'mix',
      tracks: ['b', 'a', 'c'],
      convertItem: (id, date, playlistID) => _Item(id, date),
      actionIfAlreadyExists: () => null,
    );
    await manager.reorderTrack(created!, 2, 0);
    await manager.removeTracksFromPlaylist(manager.getPlaylist('mix')!, [1]);
    await manager.updatePropertyInPlaylist('mix', itemsSortType: ['name']);
    await manager.updatePlaylistMetadata('mix', tags: ['Music / Live'], moods: ['Calm'], isPinned: true);
    manager.tagsFilter.setColor('Music', 0xff123456);
    expect(await manager.renamePlaylist('mix', 'renamed'), isTrue);
    expect(manager.toggleTrackFavourite(const _Item('gone', 1)), isTrue);
    expect(manager.toggleTrackFavourite(const _Item('gone', 2)), isFalse);
    expect(manager.toggleTrackFavourite(const _Item('keep', 3)), isTrue);

    final reloaded = _Manager(storage);
    await reloaded.prepareAllPlaylistsFile();
    await reloaded.prepareDefaultPlaylistsFileAsync();
    final playlist = reloaded.getPlaylist('renamed')!;
    expect(reloaded.getPlaylist('mix'), isNull);
    expect(playlist.tracks.map((item) => item.id), ['a', 'c']);
    expect(reloaded.computeCustomOrder(playlist)!.map((item) => item.id), ['c', 'a']);
    expect(playlist.tags, ['Music/Live']);
    expect(playlist.moods, ['Calm']);
    expect(playlist.isPinned, isTrue);
    expect(reloaded.tagsFilter.colorsOf(playlist.tags), [0xff123456]);
    expect(reloaded.favouritesPlaylist.firstItemForSubItem('keep')!.dateAddedMS, 3);
    expect(reloaded.favouritesPlaylist.isSubItemFavourite('gone'), isFalse);
  });

  test('a synchronous favourite toggle survives a concurrent async track sort', () async {
    manager.toggleTrackFavourite(const _Item('b', 1));
    final sortStarted = Completer<void>();
    final finishSort = Completer<void>();
    manager.beforeSort = () async {
      manager.beforeSort = null;
      sortStarted.complete();
      await finishSort.future;
    };

    final sorting = manager.updatePropertyInPlaylist(manager.PLAYLIST_NAME_FAV, itemsSortType: ['name']);
    await sortStarted.future;
    expect(manager.toggleTrackFavourite(const _Item('a', 2)), isTrue);
    finishSort.complete();
    await sorting;
    expect(manager.favouritesPlaylist.value.tracks.map((item) => item.id), ['a', 'b']);
  });
}

class _Item with PlaylistItemWithDate {
  final String id;

  @override
  final int dateAddedMS;

  const _Item(this.id, this.dateAddedMS);

  @override
  bool operator ==(Object other) => other is _Item && other.id == id && other.dateAddedMS == dateAddedMS;

  @override
  int get hashCode => Object.hash(id, dateAddedMS);
}

class _Manager extends PlaylistManager<_Item, String, String> {
  final Directory storage;
  Future<void> Function()? beforeSort;

  _Manager(this.storage);

  @override
  String get playlistsDirectory => p.join(storage.path, 'playlists');
  @override
  String get playlistsArtworksDirectory => p.join(storage.path, 'artworks');
  @override
  String get playlistsMetadataDirectory => p.join(storage.path, 'metadata');
  @override
  String get favouritePlaylistPath => p.join(storage.path, 'favs.json');
  @override
  bool get sortAfterPreparing => true;
  @override
  bool get addTracksAtBeginning => false;
  @override
  RegExp get cleanupFilenameRegex => RegExp(r'[/\\]');
  @override
  String get EMPTY_NAME => 'Empty';
  @override
  String get NAME_CONTAINS_BAD_CHARACTER => 'Invalid characters';
  @override
  String get SAME_NAME_EXISTS => 'Already exists';
  @override
  String get NAME_IS_NOT_ALLOWED => 'Reserved';
  @override
  String get PLAYLIST_NAME_FAV => '_FAVOURITES_';
  @override
  String get PLAYLIST_NAME_HISTORY => '_HISTORY_';
  @override
  String get PLAYLIST_NAME_MOST_PLAYED => '_MOST_PLAYED_';

  @override
  String identifyBy(_Item item) => item.id;
  @override
  Map<String, dynamic> itemToJson(_Item item) => {'id': item.id, 'date': item.dateAddedMS};
  @override
  List<String> sortToJson(List<String> items) => items;
  @override
  bool canRemovePlaylist(GeneralPlaylist<_Item, String> playlist) => true;
  @override
  void sortPlaylists() {}

  @override
  Future<void> onPlaylistItemsSort(List<String> sorts, bool reverse, List<_Item> items) async {
    await beforeSort?.call();
    items.sort((a, b) => reverse ? b.id.compareTo(a.id) : a.id.compareTo(b.id));
  }

  GeneralPlaylist<_Item, String> _read(File file) => GeneralPlaylist.fromJson(
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    (item) => _Item(item['id'] as String, item['date'] as int),
    (sorts) => (sorts as List).cast<String>(),
  );

  @override
  Future<Map<String, GeneralPlaylist<_Item, String>>> prepareAllPlaylistsFunction() async => {
    for (final file in Directory(playlistsDirectory).listSync().whereType<File>())
      if (p.extension(file.path) == '.json') p.basenameWithoutExtension(file.path): _read(file),
  };

  @override
  Future<GeneralPlaylist<_Item, String>?> prepareFavouritePlaylistFunction() async {
    final file = File(favouritePlaylistPath);
    return file.existsSync() ? _read(file) : null;
  }
}
