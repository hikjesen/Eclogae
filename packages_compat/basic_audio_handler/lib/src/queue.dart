part of '../basic_audio_handler.dart';

class QueueShuffler<Q> {
  QueueShuffler() : _random = math.Random();

  final math.Random _random;

  void shuffleRange(List<Q> items, List<int>? pairedIndices, int start, int end) {
    for (var last = end - 1; last > start; last--) {
      swap(items, pairedIndices, last, start + _random.nextInt(last - start + 1));
    }
  }

  static void swap<T>(List<T> items, List<int>? pairedIndices, int a, int b) {
    final item = items[a];
    items[a] = items[b];
    items[b] = item;
    if (pairedIndices != null) {
      final index = pairedIndices[a];
      pairedIndices[a] = pairedIndices[b];
      pairedIndices[b] = index;
    }
  }
}

class QueueSnapshot<Q> {
  final List<Q> items;
  final List<int>? originalIndices;
  final int index;

  QueueSnapshot(Iterable<Q> items, List<int>? originalIndices, this.index)
    : items = List.unmodifiable(items),
      originalIndices = originalIndices == null ? null : List.unmodifiable(originalIndices);
}

class PlaybackQueue<Q> {
  final queueRx = Rx<List<Q>>(const <Never>[]);
  List<Q> get value => queueRx.value;
  int get length => value.length;
  List<int>? get originalIndices => _originalIndices;
  List<int>? _originalIndices;

  void _replace(List<Q> items, List<int>? order) {
    _originalIndices = order == null ? null : List.unmodifiable(order);
    queueRx.set(List.unmodifiable(items));
  }
}

mixin _QueueManagement<Q extends Object> on BaseAudioHandler {
  final currentQueue = PlaybackQueue<Q>();
  final currentIndex = Rx<int>(0);
  final currentItem = Rxn<Q>();
  final _defaultShuffler = QueueShuffler<Q>();
  int latestInsertedIndex = -1;
  Completer<void>? _queueModifyLock;
  int _queueNavigationRequest = 0;
  bool _shuffle = false;

  bool get isQueueShuffled => _shuffle;
  bool get isShuffleEnabled => _shuffle;
  bool get isLastItem => currentIndex.value >= currentQueue.value.length - 1;
  bool get isModifyingQueue => _queueModifyLock != null;

  QueueShuffler<Q> get queueShuffler => _defaultShuffler;
  Object identifyBy(Q item) => item;
  void onIndexChanged(int newIndex, Q newItem) {}
  Future<void> onQueueChanged() async {}
  Future<void> onReorderItems(int currentIndex, Q itemDragged) async {}
  FutureOr<void> beforeQueueAddOrInsert(Iterable<Q> items) {}
  Future<void>? beforeSkippingToItem() => _queueModifyLock?.future;

  void setPlayWhenReady(bool value);
  Future<void> _playQueueIndex(int index);
  Future<void> _stopForEmptyQueue();

  void invokeQueueModifyLock() => _queueModifyLock ??= Completer<void>();

  void invokeQueueModifyLockRelease({bool isCanceled = false}) {
    final lock = _queueModifyLock;
    _queueModifyLock = null;
    lock?.complete();
  }

  bool isSameAsOriginalQueue(List<Q> items) => _sameQueue(items, original: true);

  bool _sameQueue(List<Q> items, {bool original = false}) {
    final current = currentQueue.value;
    if (items.length != current.length) return false;
    final order = original ? currentQueue.originalIndices : null;
    for (var i = 0; i < items.length; i++) {
      if (identifyBy(items[order?[i] ?? i]) != identifyBy(current[i])) return false;
    }
    return true;
  }

  Future<void> assignNewQueue<Id>({
    required int playAtIndex,
    required Iterable<Q> queue,
    bool shuffle = false,
    bool shuffleKeepingItem = false,
    List<int>? originalIndices,
    covariant bool? startPlaying,
    int? maximumItems,
    void Function()? onQueueEmpty,
    void Function()? onIndexAndQueueSame,
    void Function(List<Q> finalizedQueue, List<int>? originalIndices)? onQueueDifferent,
    void Function(Q currentItem)? onAssigningCurrentItem,
    bool Function(Q? currentItem, Q itemToPlay)? canRestructureQueueOnly,
    void Function(QueueSnapshot<Q>? previousQueue)? onRestructuringQueue,
    Id Function(Q currentItem)? duplicateRemover,
  }) async {
    final items = queue.toList();
    if (items.isEmpty || maximumItems == 0) {
      onQueueEmpty?.call();
      return;
    }

    var index = playAtIndex.clamp(0, items.length - 1).toInt();
    final selected = items[index];
    // Persisted indices map displayed positions back to their original order.
    var order = originalIndices != null &&
        originalIndices.length == items.length &&
        originalIndices.toSet().length == items.length &&
        originalIndices.every((i) => i >= 0 && i < items.length)
        ? originalIndices.toList()
        : null;
    if (duplicateRemover != null) {
      final seen = <Id>{};
      final selectedId = duplicateRemover(selected);
      for (var i = 0; i < items.length; i++) {
        final id = duplicateRemover(items[i]);
        if ((id == selectedId && i != index) || !seen.add(id)) {
          items.removeAt(i);
          order?.removeAt(i);
          if (i < index) index--;
          i--;
        }
      }
    }

    if (maximumItems != null && maximumItems > 0 && items.length > maximumItems) {
      final start = math.max(0, index - maximumItems + 1);
      items.setAll(0, items.sublist(start, start + maximumItems));
      items.length = maximumItems;
      order = order?.sublist(start, start + maximumItems);
      index -= start;
    }
    if (order != null) order = _normalizeOrder(order);

    if (shuffle || shuffleKeepingItem || (_shuffle && order == null)) {
      order ??= List.generate(items.length, (i) => i);
      final selectedOriginalIndex = order[index];
      if (shuffleKeepingItem || !shuffle) {
        QueueShuffler.swap(items, order, 0, index);
        queueShuffler.shuffleRange(items, order, 1, items.length);
        index = order.indexOf(selectedOriginalIndex);
      } else {
        queueShuffler.shuffleRange(items, order, 0, items.length);
        index = 0;
      }
    }

    final sameQueue = _sameQueue(items);
    if (sameQueue && currentIndex.value == index) {
      onIndexAndQueueSame?.call();
      return;
    }

    final request = ++_queueNavigationRequest;
    final oldItems = currentQueue.value;
    final previous = oldItems.isEmpty ? null : QueueSnapshot(oldItems, currentQueue.originalIndices, currentIndex.value);
    final next = items[index];
    final restructure = canRestructureQueueOnly?.call(currentItem.value, next) ?? false;
    if (!restructure && oldItems.isNotEmpty) await beforeSkippingToItem();
    if (request != _queueNavigationRequest) return;
    // Namida sets its playback intent before delegating without this argument.
    if (startPlaying != null) setPlayWhenReady(startPlaying);
    if (!sameQueue) onQueueDifferent?.call(items, order);
    latestInsertedIndex = -1;
    onAssigningCurrentItem?.call(next);

    _setQueue(items, order, index);
    if (restructure && !sameQueue) onRestructuringQueue?.call(previous);
    await Future.wait([onQueueChanged(), if (!restructure) _playQueueIndex(index)]);
  }

  Future<void> restoreQueue(QueueSnapshot<Q> snapshot) => assignNewQueue(
    playAtIndex: snapshot.index,
    queue: snapshot.items,
    originalIndices: snapshot.originalIndices,
    canRestructureQueueOnly: (current, next) => current != null && identifyBy(current) == identifyBy(next),
  );

  FutureOr<void> clearQueue() async {
    final request = ++_queueNavigationRequest;
    invokeQueueModifyLockRelease();
    if (currentQueue.value.isNotEmpty) await beforeSkippingToItem();
    if (request != _queueNavigationRequest) return;
    latestInsertedIndex = -1;
    _setQueue([], null, 0);
    await _stopForEmptyQueue();
    await onQueueChanged();
  }

  Future<void> setQueueShuffled(bool shuffled) async {
    if (_shuffle == shuffled) return;
    _shuffle = shuffled;
    final items = currentQueue.value.toList();
    if (items.isEmpty) return;
    final index = currentIndex.value;
    final order = currentQueue.originalIndices?.toList();
    if (shuffled) {
      final indices = order ?? List.generate(items.length, (i) => i);
      final selected = indices[index];
      queueShuffler.shuffleRange(items, indices, 0, items.length);
      _setQueue(items, indices, indices.indexOf(selected));
    } else {
      if (order == null) return;
      final byOriginalIndex = {for (var i = 0; i < order.length; i++) order[i]: items[i]};
      final original = List.generate(items.length, (i) => byOriginalIndex[i]!);
      _setQueue(original, null, order[index]);
    }
    latestInsertedIndex = -1;
    await onQueueChanged();
  }

  Future<void> shuffleAllItems() => _shuffleItems(0);
  Future<void> shuffleNextItems() => _shuffleItems(currentIndex.value + 1);

  Future<void> _shuffleItems(int start) async {
    final items = currentQueue.value.toList();
    if (items.length - start < 2) return;
    final order = currentQueue.originalIndices?.toList() ?? List.generate(items.length, (i) => i);
    final selected = order[currentIndex.value];
    queueShuffler.shuffleRange(items, order, start, items.length);
    _setQueue(items, order, order.indexOf(selected));
    latestInsertedIndex = -1;
    await onQueueChanged();
  }

  int? shuffleNextIndex() => isShuffleEnabled && !isLastItem ? currentIndex.value + 1 : null;
  int? shufflePeekPreviousIndex() => isShuffleEnabled && currentIndex.value > 0 ? currentIndex.value - 1 : null;

  Future<void> addToQueue(Iterable<Q> items, {bool insertNext = false, bool insertAfterLatest = false}) =>
    _insert(items, () {
      if (insertAfterLatest && latestInsertedIndex >= currentIndex.value) return latestInsertedIndex + 1;
      if (insertNext || insertAfterLatest) return currentIndex.value + 1;
      return currentQueue.value.length;
    });

  Future<void> insertInQueue(Iterable<Q> items, int index) => _insert(items, () => index);

  Future<void> _insert(Iterable<Q> items, int Function() insertionIndex) async {
    final additions = items.toList();
    if (additions.isEmpty) return;
    final lock = _queueModifyLock;
    if (lock != null) await lock.future;
    await beforeQueueAddOrInsert(additions);
    final previous = currentQueue.value;
    final index = insertionIndex().clamp(0, previous.length).toInt();
    final itemsWithInsertions = previous.toList()..insertAll(index, additions);
    final order = currentQueue.originalIndices?.toList()
      ?..insertAll(index, List.generate(additions.length, (i) => previous.length + i));
    latestInsertedIndex = index + additions.length - 1;
    final current = currentIndex.value;
    _setQueue(itemsWithInsertions, order, previous.isNotEmpty && index <= current ? current + additions.length : current);
    await Future.wait([onQueueChanged(), if (previous.isEmpty) _playQueueIndex(0)]);
  }

  Future<void> reorderItems(int oldIndex, int newIndex) async {
    try {
      final length = currentQueue.value.length;
      if (oldIndex < 0 || oldIndex >= length || newIndex < 0 || newIndex > length) return;
      final destination = newIndex > oldIndex ? newIndex - 1 : newIndex;
      if (oldIndex != destination) await _moveIndices([oldIndex], destination);
    } finally {
      invokeQueueModifyLockRelease();
    }
  }

  Future<bool> moveToNext(int index) => moveItemsToNext([index]);
  Future<bool> moveToLast(int index) => moveItemsToLast([index]);
  Future<bool> moveToAfterLatestInserted(int index) {
    if (index < 0 || index >= currentQueue.value.length || index == currentIndex.value) return Future.value(false);
    final anchor = math.max(currentIndex.value, latestInsertedIndex);
    final destination = index <= anchor ? anchor : anchor + 1;
    return _moveIndices([index], destination);
  }

  Future<bool> moveItemsToNext(List<int> indices) {
    final sorted = _movableIndices(indices);
    final index = currentIndex.value;
    return _moveIndices(sorted, index + 1 - sorted.where((i) => i < index).length);
  }

  Future<bool> moveItemsToLast(List<int> indices) {
    final sorted = _movableIndices(indices);
    return _moveIndices(sorted, currentQueue.value.length - sorted.length);
  }

  List<int> _movableIndices(List<int> indices) =>
    indices.where((i) => i >= 0 && i < currentQueue.value.length && i != currentIndex.value).toSet().toList()..sort();

  Future<bool> _moveIndices(List<int> indices, int destination) async {
    if (indices.isEmpty) return false;
    final items = currentQueue.value;
    final order = currentQueue.originalIndices;
    final positions = List.generate(items.length, (i) => i)
      ..removeWhere(indices.contains)
      ..insertAll(destination, indices);
    if (Iterable<int>.generate(positions.length).every((i) => positions[i] == i)) return false;
    final index = positions.indexOf(currentIndex.value);
    latestInsertedIndex = positions.indexOf(latestInsertedIndex);
    _setQueue(positions.map((i) => items[i]).toList(), order == null ? null : positions.map((i) => order[i]).toList(), index);
    await onReorderItems(index, items[indices.first]);
    await onQueueChanged();
    return true;
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= currentQueue.value.length) return;
    await _removeIndices({index});
  }

  int removeRangeFromQueue(int start, int end) {
    final count = currentQueue.value.length;
    final lower = start.clamp(0, count).toInt();
    final upper = end.clamp(lower, count).toInt();
    unawaited(_removeIndices({for (var i = lower; i < upper; i++) i}));
    return upper - lower;
  }

  int removeAllPrevious() => removeRangeFromQueue(0, currentIndex.value);
  int removeAllNext() => removeRangeFromQueue(currentIndex.value + 1, currentQueue.value.length);
  int removeAllExceptCurrent() {
    final index = currentIndex.value;
    final remove = {for (var i = 0; i < currentQueue.value.length; i++) if (i != index) i};
    unawaited(_removeIndices(remove));
    return remove.length;
  }

  int removeDuplicatesFromQueue() {
    final items = currentQueue.value;
    if (items.isEmpty) return 0;
    final index = currentIndex.value;
    final seen = {identifyBy(items[index])};
    final remove = <int>{};
    for (var i = 0; i < items.length; i++) {
      if (i != index && !seen.add(identifyBy(items[i]))) remove.add(i);
    }
    unawaited(_removeIndices(remove));
    return remove.length;
  }

  Future<void> _removeIndices(Set<int> remove) async {
    if (remove.isEmpty) return;
    final old = currentQueue.value;
    if (remove.length == old.length) {
      await clearQueue();
      return;
    }

    final previous = currentIndex.value;
    final removingCurrent = remove.contains(previous);
    if (removingCurrent) {
      await beforeSkippingToItem();
      if (!identical(old, currentQueue.value)) return;
    }
    final order = currentQueue.originalIndices;
    final positions = [for (var i = 0; i < old.length; i++) if (!remove.contains(i)) i];
    final next = positions.indexWhere((i) => i >= previous);
    final index = next < 0 ? positions.length - 1 : next;
    latestInsertedIndex = positions.indexOf(latestInsertedIndex);
    _setQueue(positions.map((i) => old[i]).toList(), order == null ? null : _normalizeOrder(positions.map((i) => order[i]).toList()), index);
    await Future.wait([onQueueChanged(), if (removingCurrent) _playQueueIndex(index)]);
  }

  Future<void> replaceAllItemsInQueue(Q oldItem, Q newItem) =>
    replaceWhereInQueue((item) => identifyBy(item) == identifyBy(oldItem), (_) => newItem);

  Future<void> replaceWhereInQueue(bool Function(Q) test, Q Function(Q) replace) async {
    final items = currentQueue.value.toList();
    var changed = false;
    for (var i = 0; i < items.length; i++) {
      if (test(items[i])) {
        items[i] = replace(items[i]);
        changed = true;
      }
    }
    if (changed) {
      _setQueue(items, currentQueue.originalIndices, currentIndex.value);
      await onQueueChanged();
    }
  }

  static List<int> _normalizeOrder(List<int> order) {
    final sorted = order.toList()..sort();
    final ranks = {for (var i = 0; i < sorted.length; i++) sorted[i]: i};
    return [for (final i in order) ranks[i]!];
  }

  void _setQueue(List<Q> items, List<int>? order, int index) {
    currentQueue._replace(items, order);
    if (items.isEmpty) {
      _updateSelection(0, null);
    } else {
      _select(index);
    }
    currentQueue.queueRx.refresh();
  }

  void _select(int index) {
    final item = currentQueue.value[index];
    if (_updateSelection(index, item)) onIndexChanged(index, item);
  }

  bool _updateSelection(int index, Q? item) {
    final indexChanged = currentIndex.value != index;
    final itemChanged = !identical(currentItem.value, item);
    currentItem.set(item);
    currentIndex.set(index);
    if (itemChanged) currentItem.refresh();
    if (indexChanged) currentIndex.refresh();
    return itemChanged || indexChanged;
  }
}
