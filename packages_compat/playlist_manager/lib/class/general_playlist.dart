import '../module/playlist_id.dart';

mixin PlaylistItemWithDate {
  int get dateAddedMS;
}

class PlaylistRemoteSource {
  final String sourceKey;
  final String remoteId;

  const PlaylistRemoteSource({required this.sourceKey, required this.remoteId});

  static const none = PlaylistRemoteSource(sourceKey: '', remoteId: '');

  factory PlaylistRemoteSource.fromJson(Map<String, dynamic> json) =>
      PlaylistRemoteSource(
        sourceKey: json['sourceKey'] as String,
        remoteId: json['remoteId'] as String,
      );

  Map<String, dynamic> toJson() => {'sourceKey': sourceKey, 'remoteId': remoteId};
}

class PlaylistMetadataEdit {
  final String? comment;
  final List<String>? moods;
  final List<String>? tags;
  final bool? isPinned;

  const PlaylistMetadataEdit({this.comment, this.moods, this.tags, this.isPinned});
}

class GeneralPlaylist<T, S> {
  final String name;
  final List<T> tracks;
  final int creationDate;
  final int modifiedDate;
  final String comment;
  final List<String> moods;
  final List<String> tags;
  final bool isFav;
  final int? pinnedDate;
  final String? m3uPath;
  final List<S>? sortsType;
  final bool sortReverse;
  final List<T>? customOrder;
  final PlaylistRemoteSource? remoteSource;

  GeneralPlaylist({
    required this.name,
    required this.tracks,
    required this.creationDate,
    required this.modifiedDate,
    this.comment = '',
    this.moods = const [],
    this.tags = const [],
    this.isFav = false,
    this.pinnedDate,
    String? m3uPath,
    this.sortsType,
    this.sortReverse = false,
    this.customOrder,
    PlaylistRemoteSource? remoteSource,
  }) : m3uPath = m3uPath == '' ? null : m3uPath,
       remoteSource = remoteSource == PlaylistRemoteSource.none ? null : remoteSource;

  PlaylistID get playlistID => PlaylistID(id: name);
  bool get isPinned => pinnedDate != null;
  bool get isReadOnly => remoteSource != null;
  bool get canSyncRenames => !isFav && m3uPath == null && !isReadOnly && creationDate > 0;

  String toTagsAndMoodsText() => [...tags, ...moods].join(', ');

  factory GeneralPlaylist.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
    List<S> Function(dynamic) sortsFromJson,
  ) {
    List<T>? readItems(Object? value) => (value as List?)
        ?.map((item) => itemFromJson(item as Map<String, dynamic>))
        .toList();
    final creationDate = json['creationDate'] as int? ?? 0;
    final sorts = json['sortsType'];
    final remote = json['remoteSource'] as Map<String, dynamic>?;
    return GeneralPlaylist<T, S>(
      name: json['name'] as String,
      tracks: readItems(json['tracks']) ?? <T>[],
      creationDate: creationDate,
      modifiedDate: json['modifiedDate'] as int? ?? creationDate,
      comment: json['comment'] as String? ?? '',
      moods: (json['moods'] as List?)?.cast<String>() ?? const [],
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      isFav: json['isFav'] == true,
      pinnedDate: json['pinnedDate'] as int? ?? (json['isPinned'] == true ? 0 : null),
      m3uPath: json['m3uPath'] as String?,
      sortsType: sorts == null ? null : sortsFromJson(sorts),
      sortReverse: json['sortReverse'] == true,
      customOrder: readItems(json['customOrder']),
      remoteSource: remote == null ? null : PlaylistRemoteSource.fromJson(remote),
    );
  }

  Map<String, dynamic> toJson(
    Object? Function(T) itemToJson,
    Object? Function(List<S>) sortsToJson, {
    bool includeTracks = true,
  }) {
    final sorts = sortsType;
    final order = customOrder;
    return {
      'name': name,
      if (includeTracks) 'tracks': tracks.map(itemToJson).toList(),
      'creationDate': creationDate,
      'modifiedDate': modifiedDate,
      'comment': comment,
      'moods': moods,
      'tags': tags,
      'isFav': isFav,
      if (pinnedDate != null) 'pinnedDate': pinnedDate,
      if (m3uPath != null) 'm3uPath': m3uPath,
      if (sorts != null) 'sortsType': sortsToJson(sorts),
      'sortReverse': sortReverse,
      if (includeTracks && order != null) 'customOrder': order.map(itemToJson).toList(),
      if (remoteSource != null) 'remoteSource': remoteSource!.toJson(),
    };
  }

  GeneralPlaylist<T, S> copyWith({
    String? name,
    List<T>? tracks,
    int? creationDate,
    int? modifiedDate,
    String? comment,
    List<String>? moods,
    List<String>? tags,
    bool? isFav,
    int? pinnedDate,
    bool? isPinned,
    String? m3uPath,
    List<S>? sortsType,
    bool? sortReverse,
    List<T>? customOrder,
    bool clearCustomOrder = false,
    PlaylistRemoteSource? remoteSource,
  }) => GeneralPlaylist<T, S>(
    name: name ?? this.name,
    tracks: tracks ?? this.tracks,
    creationDate: creationDate ?? this.creationDate,
    modifiedDate: modifiedDate ?? this.modifiedDate,
    comment: comment ?? this.comment,
    moods: moods ?? this.moods,
    tags: tags ?? this.tags,
    isFav: isFav ?? this.isFav,
    pinnedDate: isPinned == false
        ? null
        : pinnedDate ?? this.pinnedDate ?? (isPinned == true ? DateTime.now().millisecondsSinceEpoch : null),
    m3uPath: m3uPath ?? this.m3uPath,
    sortsType: sortsType ?? this.sortsType,
    sortReverse: sortReverse ?? this.sortReverse,
    customOrder: clearCustomOrder ? null : customOrder ?? this.customOrder,
    remoteSource: remoteSource ?? this.remoteSource,
  );

  GeneralPlaylist<T, S> copyWithConvertedTracks(T Function(T) convert) => copyWith(
    tracks: tracks.map(convert).toList(),
    customOrder: customOrder?.map(convert).toList(),
  );
}

extension PinnedPlaylistsOrder<T, S> on List<MapEntry<String, GeneralPlaylist<T, S>>> {
  void movePinnedFirst() {
    final pinned = [
      for (var index = 0; index < length; index++)
        if (this[index].value.isPinned) index,
    ];
    if (pinned.isEmpty) return;
    pinned.sort((a, b) {
      final byDate = this[b].value.pinnedDate!.compareTo(this[a].value.pinnedDate!);
      return byDate == 0 ? a.compareTo(b) : byDate;
    });
    final ordered = [for (final index in pinned) this[index], ...where((entry) => !entry.value.isPinned)];
    setAll(0, ordered);
  }
}
