import 'package:flutter/foundation.dart';
import 'package:nampack/reactive/reactive.dart';

import 'general_playlist.dart';

sealed class PlaylistTagKey {
  const PlaylistTagKey();
}

enum PlaylistVirtualTag implements PlaylistTagKey { pinned, untagged, m3u, remote }

final class PlaylistUserTag extends PlaylistTagKey {
  final String path;

  const PlaylistUserTag(this.path);

  @override
  bool operator ==(Object other) => other is PlaylistUserTag && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

enum PlaylistTagFilterState { none, included, excluded }

class PlaylistTagsSelection {
  final Set<PlaylistTagKey> included;
  final Set<PlaylistTagKey> excluded;

  const PlaylistTagsSelection({this.included = const {}, this.excluded = const {}});

  @override
  bool operator ==(Object other) =>
      other is PlaylistTagsSelection && setEquals(included, other.included) && setEquals(excluded, other.excluded);

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(included), Object.hashAllUnordered(excluded));

  factory PlaylistTagsSelection._fromJson(Map<String, dynamic> json) {
    Set<PlaylistTagKey> read(String field) => {
      for (final key in json[field] as List)
        if (key is String) PlaylistUserTag(key) else PlaylistVirtualTag.values.byName((key as Map)['virtual'] as String),
    };

    return PlaylistTagsSelection(included: read('included'), excluded: read('excluded'));
  }

  Map<String, dynamic> _toJson() {
    List<Object> encode(Set<PlaylistTagKey> keys) => [
      for (final key in keys)
        if (key is PlaylistVirtualTag) {'virtual': key.name} else (key as PlaylistUserTag).path,
    ];

    return {'included': encode(included), 'excluded': encode(excluded)};
  }
}

class PlaylistTagInfo {
  final String path;
  final int count;
  final int? color;
  final List<PlaylistTagInfo> nested;

  const PlaylistTagInfo({required this.path, required this.count, this.color, this.nested = const []});
}

class PlaylistTagChip {
  final PlaylistTagKey key;
  final PlaylistTagFilterState state;
  final int count;
  final int depth;
  final String? label;
  final int? color;

  const PlaylistTagChip({
    required this.key,
    required this.state,
    required this.count,
    this.depth = 0,
    this.label,
    this.color,
  });
}

class PlaylistTagSection {
  final PlaylistTagKey key;
  final int? color;
  final List<String> names;

  const PlaylistTagSection({required this.key, required this.names, this.color});
}

class PlaylistTagsFilter {
  static const separator = '/';

  final revision = 0.obs;
  final void Function() _onChanged;
  final void Function(Map<String, dynamic>) _save;
  final _keysByPlaylist = <String, Set<PlaylistTagKey>>{};
  final _counts = <PlaylistTagKey, int>{};
  final _colors = <String, int>{};
  final _topLevelOrder = <String>[];
  final _savedSelections = <PlaylistTagsSelection>[];
  var _selection = const PlaylistTagsSelection();

  PlaylistTagsFilter(this._onChanged, this._save);

  PlaylistTagsSelection get selection => _selection;
  bool get isActive => selection.included.isNotEmpty || selection.excluded.isNotEmpty;
  List<PlaylistTagsSelection> get savedSelections => List.unmodifiable(_savedSelections);
  Iterable<String> get allPaths => _counts.keys.whereType<PlaylistUserTag>().map((key) => key.path);
  Iterable<int> get usedColors => _colors.values.toSet();

  static List<String> normalizeTags(Iterable<String> tags) => {
    for (final path in tags)
      path.split(separator).map((segment) => segment.trim()).where((segment) => segment.isNotEmpty).join(separator),
  }.where((path) => path.isNotEmpty).toList();

  static Set<String> expandTags(Iterable<String> tags) {
    final paths = <String>{};
    for (final tag in normalizeTags(tags)) {
      var path = tag;
      while (paths.add(path)) {
        final split = path.lastIndexOf(separator);
        if (split == -1) break;
        path = path.substring(0, split);
      }
    }
    return paths;
  }

  void rebuild(Iterable<GeneralPlaylist<Object?, Object?>> playlists) {
    _keysByPlaylist.clear();
    _counts.clear();
    for (final playlist in playlists) {
      final keys = <PlaylistTagKey>{
        for (final path in expandTags(playlist.tags)) PlaylistUserTag(path),
        if (playlist.tags.isEmpty) PlaylistVirtualTag.untagged,
        if (playlist.isPinned) PlaylistVirtualTag.pinned,
        if (playlist.m3uPath != null) PlaylistVirtualTag.m3u,
        if (playlist.isReadOnly) PlaylistVirtualTag.remote,
      };
      _keysByPlaylist[playlist.name] = keys;
      for (final key in keys) {
        _counts.update(key, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    _notify();
  }

  List<String> apply(Iterable<String> names) {
    if (!isActive) return names.toList();
    return names.where((name) {
      final keys = _keysByPlaylist[name] ?? const <PlaylistTagKey>{};
      return keys.containsAll(selection.included) && !selection.excluded.any(keys.contains);
    }).toList();
  }

  int playlistsCountOf(String path) => _counts[PlaylistUserTag(path)] ?? 0;
  int? colorOf(String path) => _colors[path];
  List<int> colorsOf(Iterable<String> tags) =>
      expandTags(tags).map(colorOf).nonNulls.toSet().toList();

  void setColor(String path, int? color) {
    if (color == null) {
      _colors.remove(path);
    } else {
      _colors[path] = color;
    }
    _persist();
  }

  void applySelection(PlaylistTagsSelection selection) {
    _selection = selection;
    _notify();
  }

  void clear() => applySelection(const PlaylistTagsSelection());

  void toggleIncluded(PlaylistTagKey key) => _toggle(key, include: true);
  void toggleExcluded(PlaylistTagKey key) => _toggle(key, include: false);

  void _toggle(PlaylistTagKey key, {required bool include}) {
    final included = {...selection.included};
    final excluded = {...selection.excluded};
    final target = include ? included : excluded;
    (include ? excluded : included).remove(key);
    if (!target.remove(key)) target.add(key);
    applySelection(PlaylistTagsSelection(included: included, excluded: excluded));
  }

  void saveCurrentSelection() {
    if (!isActive || _savedSelections.contains(selection)) return;
    _savedSelections.add(selection);
    _persist();
  }

  void removeSavedSelection(PlaylistTagsSelection selection) {
    if (_savedSelections.remove(selection)) _persist();
  }

  List<String> _orderedTopLevelPaths() {
    final paths = allPaths.where((path) => !path.contains(separator)).toList()..sort();
    final available = paths.toSet();
    return [..._topLevelOrder.where(available.remove), ...paths.where(available.contains)];
  }

  List<PlaylistTagInfo> listTopLevelTags() {
    final paths = allPaths.toList()..sort();
    return [
      for (final root in _orderedTopLevelPaths())
        PlaylistTagInfo(
          path: root,
          count: playlistsCountOf(root),
          color: colorOf(root),
          nested: [
            for (final path in paths)
              if (path.startsWith('$root$separator'))
                PlaylistTagInfo(path: path, count: playlistsCountOf(path), color: colorOf(path)),
          ],
        ),
    ];
  }

  void reorderTopLevelTag(int oldIndex, int newIndex) {
    final order = _orderedTopLevelPaths();
    if (newIndex > oldIndex) newIndex--;
    order.insert(newIndex, order.removeAt(oldIndex));
    _topLevelOrder
      ..clear()
      ..addAll(order);
    _persist();
  }

  List<PlaylistTagChip> computeChips() {
    final keys = <PlaylistTagKey>{
      ...PlaylistVirtualTag.values.where(_counts.containsKey),
      for (final root in listTopLevelTags()) ...[PlaylistUserTag(root.path), ...root.nested.map((tag) => PlaylistUserTag(tag.path))],
      ...selection.included,
      ...selection.excluded,
    };
    return [
      for (final key in keys)
        PlaylistTagChip(
          key: key,
          state: selection.included.contains(key)
              ? PlaylistTagFilterState.included
              : selection.excluded.contains(key)
              ? PlaylistTagFilterState.excluded
              : PlaylistTagFilterState.none,
          count: _counts[key] ?? 0,
          depth: key is PlaylistUserTag ? key.path.split(separator).length - 1 : 0,
          label: key is PlaylistUserTag ? key.path.split(separator).last : null,
          color: key is PlaylistUserTag ? colorOf(key.path) : null,
        ),
    ];
  }

  List<PlaylistTagSection> groupByTopLevelTag(Iterable<String> names) {
    final groups = <PlaylistTagKey, List<String>>{
      for (final path in _orderedTopLevelPaths()) PlaylistUserTag(path): [],
      PlaylistVirtualTag.untagged: [],
    };
    for (final name in names) {
      final keys = _keysByPlaylist[name] ?? const <PlaylistTagKey>{};
      var grouped = false;
      for (final key in keys.whereType<PlaylistUserTag>()) {
        if (key.path.contains(separator)) continue;
        groups[key]!.add(name);
        grouped = true;
      }
      if (!grouped) groups[PlaylistVirtualTag.untagged]!.add(name);
    }
    return [
      for (final entry in groups.entries)
        if (entry.value.isNotEmpty)
          PlaylistTagSection(
            key: entry.key,
            names: entry.value,
            color: entry.key is PlaylistUserTag ? colorOf((entry.key as PlaylistUserTag).path) : null,
          ),
    ];
  }

  void remapPaths(String? Function(String) remap) {
    PlaylistTagsSelection convert(PlaylistTagsSelection selection) {
      Set<PlaylistTagKey> keys(Set<PlaylistTagKey> original) {
        final result = <PlaylistTagKey>{};
        for (final key in original) {
          if (key is PlaylistUserTag) {
            final path = remap(key.path);
            if (path != null) result.add(PlaylistUserTag(path));
          } else {
            result.add(key);
          }
        }
        return result;
      }
      return PlaylistTagsSelection(included: keys(selection.included), excluded: keys(selection.excluded));
    }

    final colors = <String, int>{};
    for (final entry in _colors.entries) {
      final path = remap(entry.key);
      if (path != null) colors[path] = entry.value;
    }
    final order = _topLevelOrder.map(remap).nonNulls.where((path) => !path.contains(separator)).toSet();
    final saved = _savedSelections.map(convert).where((value) => value.included.isNotEmpty || value.excluded.isNotEmpty).toSet();
    _colors
      ..clear()
      ..addAll(colors);
    _topLevelOrder
      ..clear()
      ..addAll(order);
    _savedSelections
      ..clear()
      ..addAll(saved);
    _selection = convert(selection);
    _persist();
  }

  void load(Map<String, dynamic> json, {bool merge = false}) {
    if (!merge) {
      _colors.clear();
      _topLevelOrder.clear();
      _savedSelections.clear();
    }
    _colors.addAll((json['colors'] as Map?)?.cast<String, int>() ?? const {});
    _topLevelOrder.addAll(((json['order'] as List?)?.cast<String>() ?? const <String>[]).where((path) => !_topLevelOrder.contains(path)));
    final saved = (json['savedSelections'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    for (final entry in saved) {
      final selection = PlaylistTagsSelection._fromJson(entry);
      if (!_savedSelections.contains(selection)) _savedSelections.add(selection);
    }
    if (merge) _persist();
  }

  void _persist() {
    _save({
      'colors': _colors,
      'order': _topLevelOrder,
      'savedSelections': _savedSelections.map((value) => value._toJson()).toList(),
    });
    _notify();
  }

  void _notify() {
    revision.value++;
    _onChanged();
  }
}
