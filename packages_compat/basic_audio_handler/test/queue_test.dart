import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingHandler extends BasicAudioHandler<String> {
  final selections = <(String, bool)>[];

  @override
  Future<void> onItemPlay(
    String item,
    int index,
    Function skipItem,
    ItemPreparedPlayerInfo<String>? preparedItemInfo,
  ) async {
    selections.add((item, playWhenReady.value));
  }
}

void main() {
  test('queue restore preserves the playback intent supplied before delegation', () async {
    final handler = _RecordingHandler();
    handler.setPlayWhenReady(false);

    await handler.assignNewQueue(playAtIndex: 1, queue: ['first', 'second', 'third']);

    expect(handler.selections, [('second', false)]);
    expect(handler.currentIndex.value, 1);
    expect(handler.queue.value.map((item) => item.id), ['first', 'second', 'third']);

    await handler.skipToNext();
    expect(handler.selections.last, ('third', true));
    await handler.clearQueue();
    expect(handler.currentItem.value, isNull);
    expect(handler.mediaItem.value, isNull);
    expect(handler.queue.value, isEmpty);
    expect(handler.playWhenReady.value, isFalse);
  });

  test('restored shuffle indices retain the selected occurrence after reorder', () async {
    final handler = _RecordingHandler();
    await handler.setQueueShuffled(true);
    await handler.assignNewQueue(
      playAtIndex: 0,
      queue: ['second', 'first', 'third'],
      originalIndices: [1, 0, 2],
    );
    await handler.reorderItems(0, 3);

    expect(handler.currentItem.value, 'second');
    expect(handler.currentIndex.value, 2);
    expect(handler.currentQueue.originalIndices, [0, 2, 1]);

    await handler.setQueueShuffled(false);

    expect(handler.currentQueue.value, ['first', 'second', 'third']);
    expect(handler.currentIndex.value, 1);
    expect(handler.selections, [('second', false)]);
  });
}
