part of '../basic_audio_handler.dart';

class BasicAudioHandler<Q extends Object> extends BaseAudioHandler with _QueueManagement<Q> {
  final playWhenReady = Rx<bool>(false);
  final isPlaying = Rx<bool>(false);
  final currentPositionMS = Rx<int>(0);
  final currentSpeed = Rx<double>(1);
  final buffered = Rx<Duration>(Duration.zero);
  final currentState = Rxn<ProcessingState>();
  final loadedDuration = Rxn<Duration>();
  final currentLiveWindow = Rxn<LiveWindow>();
  final audioTracks = Rxn<List<AudioTrack>>();
  final textTracks = Rxn<List<TextTrack>>();
  final subtitleText = Rxn<String>();
  final videoPlayerInfo = Rxn<VideoInfoData>();
  final numberOfRepeats = Rx<int>(1);
  final sleepTimerConfig = Rx<SleepTimerConfig>(const SleepTimerConfig());

  final _playerSubscriptions = <StreamSubscription<dynamic>>[];
  final _sessionSubscriptions = <StreamSubscription<dynamic>>[];
  final _volumeListeners = <String, void Function(double)>{};
  final _ranges = <Object, ({int? start, int? end})>{};
  final _listenTime = RxMap<String, int>({});
  late final Future<void> _listenTimeReady = _loadListenTime();
  AVPlayer? _player;
  Future<AudioSession>? _session;
  int _sessionGeneration = 0;
  Q? _loadedItem;
  int _selection = 0;
  int _sourceRequest = 0;
  int _transportRequest = 0;
  int _metadataRequest = 0;
  int _repeatsLeft = 1;
  bool _loadingSource = false;
  bool _sourceReady = false;
  bool _completing = false;
  bool _stopped = false;
  bool _ducked = false;
  Future<void>? _outgoingFade;
  int _incomingFadeMilliseconds = 0;
  DateTime? _interruptedAt;
  DateTime? _noisyAt;
  DateTime? _mutedAt;
  Timer? _sleepTimer;
  Timer? _listenTimer;
  int _listenedSeconds = 0;
  bool _markedListened = false;
  double _userVolume = 1;
  Duration? liveJoinPosition;
  void Function(Object error, StackTrace stackTrace)? onVideoError;

  late final EqualizerExtended? equalizerExtended = PlayerConfig.isEqualizerSupported ? EqualizerExtended(() => currentPlayer) : null;
  late final LoudnessEnhancerExtended? loudnessEnhancerExtended = PlayerConfig.isLoudnessEnhancerSupported
      ? LoudnessEnhancerExtended(() => currentPlayer, getLoudnessEnhancerEnabledTrackValue)
      : null;

  AVPlayer get currentPlayer => _player ??= _createAndListenToPlayer();
  bool get rendersSubtitlesInternally => _player?.rendersSubtitlesInternally ?? false;
  int? get androidSessionId => _player?.androidAudioSessionId;
  double get userPlayerVolumeForItem => _userVolume;
  bool get isAutoSkipping => _completing;
  RxMap<String, int> get totalListenedTimeInSec {
    unawaited(_listenTimeReady);
    return _listenTime;
  }

  Stream<Duration> get positionStream => currentPlayer.positionStream;
  Stream<Duration?> get durationStream => currentPlayer.durationStream;
  Stream<Duration> get bufferedPositionStream => currentPlayer.bufferedPositionStream;
  Stream<bool> get playingStream => currentPlayer.playingStream;
  Stream<ProcessingState> get processingStateStream => currentPlayer.processingStateStream;

  AudioLoadConfiguration? get defaultAndroidLoadConfig => null;
  bool get publishQueueToMediaBrowser => true;
  bool get defaultShouldStartPlayingOnNextPrev => true;
  bool get playerInfiniyQueueOnNextPrevious => false;
  bool get jumpToFirstItemAfterFinishingQueue => false;
  bool get enableCrossFade => false;
  bool get defaultGaplessEnabled => false;
  int get defaultCrossFadeMilliseconds => 0;
  int get defaultCrossFadeTriggerStartOffsetSeconds => 0;
  bool get enableVolumeFadeOnPlayPause => false;
  int get playerPauseFadeDurInMilli => 0;
  int get playerPlayFadeDurInMilli => 0;
  bool get playerPauseOnVolume0 => false;
  double get replayGainLinearVolumeMultiplierValue => 1;
  bool getLoudnessEnhancerEnabledTrackValue() => false;
  bool getLoudnessEnhancerEnabledTrackValueR() => getLoudnessEnhancerEnabledTrackValue();
  bool get canUseItemPlaybackRange => true;
  int getListenRestartPositionThresholdMS() => 5000;
  int get listenCounterMarkPlayedPercentage => 50;
  int get listenCounterMarkPlayedSeconds => 30;
  int get maximumSleepTimerMins => 120;
  int get maximumSleepTimerItems => 100;
  Duration get defaultInterruptionResumeThreshold => const Duration(minutes: 2);
  Duration get defaultVolume0ResumeThreshold => Duration.zero;
  Duration get defaultConnectWiredResumeThresholdMin => Duration.zero;
  Duration get defaultConnectWirelessResumeThresholdMin => Duration.zero;
  InterruptionAction get onBecomingNoisyEventStream => InterruptionAction.pause;
  InterruptionAction defaultOnInterruption(InterruptionType type) =>
    type == InterruptionType.shouldDuck ? InterruptionAction.duckAudio : InterruptionAction.pause;

  PlayerRepeatMode _repeatMode = PlayerRepeatMode.none;
  PlayerRepeatMode get playerRepeatMode => _repeatMode;
  PlayerRepeatMode get displayRepeatMode => playerRepeatMode;

  PlayerConfig getDefaultPlayerConfig(Q? item) => const PlayerConfig();
  Future<PlayerConfig?> getPlayerConfigForItem(Q? item, AVPlayer player) async => null;
  FutureOr<void> ensureReplayGainVolumeUpdated(Q? item, {covariant Object? streamsResult}) {}
  FutureOr<ItemPrepareConfig<Q, UriSource>?> prepareItem(Q item, int index) =>
    item is UriSource ? ItemPrepareConfig<Q, UriSource>(
      item, item: item, index: index, initialPosition: null, audioTrackId: null, videoOptions: null,
    ) : null;

  Future<void> onItemPlay(Q item, int index, Function skipItem, ItemPreparedPlayerInfo<Q>? preparedItemInfo) async {
    final config = preparedItemInfo?.config ?? await prepareItem(item, index);
    if (config != null) await setAudioSource(config);
  }

  Future<MediaItem> itemToMediaItem(Q item) async => MediaItem(id: itemToMediaItemId(item), title: item.toString());
  String itemToMediaItemId(Q item) => identifyBy(item).toString();
  FutureOr<int> itemToDurationInSeconds(Q item) => loadedDuration.value?.inSeconds ?? 0;
  String? itemToTotalListenTimeKey(Q? item) => null;
  Future<Map<String, int>> prepareTotalListenTime() async => {};
  void onTotalListenTimeIncrease(Map<String, int> totalTimeInSeconds, String key) {}
  FutureOr<void> onItemMarkedListened(Q item, int listenedSeconds, double listenedPercentage) {}
  Future<void> onItemLastPositionReport(Q? currentItem, int currentPositionMs) async {}
  void onSleepTimerEnd() {}
  void onFavouriteRatingRequested(Q item, bool favourite) {}
  void toggleItemFavourite(Q item) {}

  AVPlayer createPlayerInstance() {
    final enhancer = loudnessEnhancerExtended?.androidAudioEffect;
    return CustomAudioPlayer(
      AudioPlayer(
        handleInterruptions: false,
        audioLoadConfiguration: defaultAndroidLoadConfig,
        audioPipeline: AudioPipeline(androidAudioEffects: [?enhancer]),
      ),
      loudnessEnhancer: enhancer,
    );
  }

  AVPlayer _createAndListenToPlayer() {
    final player = createPlayerInstance();
    _playerSubscriptions.addAll([
      player.playbackEventStream.listen(_onPlayerEvent, onError: _onPlayerError),
      player.positionStream.listen(_onPosition),
      player.durationStream.listen((value) => loadedDuration.value = value),
      player.bufferedPositionStream.listen((value) => buffered.value = value),
      player.playingStream.listen((value) {
        isPlaying.value = value;
        _publishPlayerState();
      }),
      player.speedStream.listen((value) {
        currentSpeed.value = value;
        _publishPlayerState();
      }),
      player.volumeStream.listen((volume) {
        for (final listener in _volumeListeners.values.toList()) {
          listener(volume);
        }
      }),
      player.liveWindowStream.listen((window) {
        currentLiveWindow.value = window;
        if (window != null) liveJoinPosition ??= player.position;
      }),
      player.audioTracksStream.listen((tracks) => audioTracks.value = tracks),
      player.textTracksStream.listen((tracks) => textTracks.value = tracks),
      player.subtitleTextStream.listen((text) => subtitleText.value = text),
      player.videoInfoStream.listen((info) => videoPlayerInfo.value = info, onError: _handleVideoError),
    ]);
    return player;
  }

  void _onPlayerEvent(PlaybackEvent event) {
    currentState.value = event.processingState;
    onPlaybackEventStream(event);
    if (event.processingState == ProcessingState.completed) _startCompletion();
  }

  void _onPosition(Duration position) {
    currentPositionMS.value = position.inMilliseconds;
    final end = getCurrentItemEndMS();
    if (end != null && position.inMilliseconds >= end && isPlaying.value) _startCompletion();
  }

  void _startCompletion() {
    if (_completing || _loadingSource || !_sourceReady || !playWhenReady.value) return;
    _completing = true;
    unawaited(onPlaybackCompleted().whenComplete(() => _completing = false));
  }

  void _onPlayerError(Object error, StackTrace stackTrace) {
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.error,
      playing: false,
      errorCode: error is PlayerException ? error.code : -1,
      errorMessage: error.toString(),
    ));
    if (!_loadingSource) onPlaybackError(error, stackTrace);
  }

  void onPlaybackError(Object error, StackTrace stackTrace) {}

  void _handleVideoError(Object error, StackTrace stackTrace) {
    final callback = onVideoError;
    if (callback == null) {
      Zone.current.handleUncaughtError(error, stackTrace);
    } else {
      callback(error, stackTrace);
    }
  }

  void onPlaybackEventStream(PlaybackEvent event) {
    playbackState.add(transformEvent(event, currentIndex.value, [
      MediaControl.skipToPrevious,
      if (playWhenReady.value) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
    ], const [0, 1, 2]));
  }

  void _publishPlayerState() {
    final player = _player;
    if (player == null || currentItem.value == null) {
      playbackState.add(PlaybackState());
      return;
    }
    onPlaybackEventStream(PlaybackEvent(
      processingState: currentState.value ?? ProcessingState.idle,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      duration: player.duration,
    ));
  }

  PlaybackState transformEvent(PlaybackEvent event, int itemIndex, List<MediaControl> controls, List<int> compactIndices) {
    final player = _player;
    final processing = _stopped ? ProcessingState.idle : currentState.value ?? event.processingState;
    return PlaybackState(
      controls: controls,
      androidCompactActionIndices: compactIndices,
      systemActions: const {MediaAction.seek, MediaAction.skipToQueueItem, MediaAction.setRepeatMode, MediaAction.setShuffleMode, MediaAction.setRating, MediaAction.setSpeed},
      processingState: AudioProcessingState.values.byName(processing.name),
      playing: !_stopped && playWhenReady.value && currentItem.value != null,
      updatePosition: _sourceReady ? player?.position ?? event.updatePosition : Duration(milliseconds: currentPositionMS.value),
      bufferedPosition: _sourceReady ? player?.bufferedPosition ?? event.bufferedPosition : Duration.zero,
      speed: player?.speed ?? currentSpeed.value,
      queueIndex: currentItem.value == null ? null : itemIndex,
      repeatMode: _mediaRepeatMode,
      shuffleMode: _mediaShuffleMode,
    );
  }

  AudioServiceRepeatMode get _mediaRepeatMode => switch (displayRepeatMode) {
    PlayerRepeatMode.none => AudioServiceRepeatMode.none,
    PlayerRepeatMode.one || PlayerRepeatMode.forNtimes => AudioServiceRepeatMode.one,
    PlayerRepeatMode.all || PlayerRepeatMode.allShuffle => AudioServiceRepeatMode.all,
  };

  AudioServiceShuffleMode get _mediaShuffleMode =>
    isQueueShuffled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none;

  void refreshPlaybackStateModes() => playbackState.add(playbackState.value.copyWith(repeatMode: _mediaRepeatMode, shuffleMode: _mediaShuffleMode));

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    onRepeatModeChange(switch (repeatMode) {
      AudioServiceRepeatMode.none => PlayerRepeatMode.none,
      AudioServiceRepeatMode.one => PlayerRepeatMode.one,
      AudioServiceRepeatMode.all || AudioServiceRepeatMode.group => PlayerRepeatMode.all,
    });
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    onShuffleModeChange(shuffleMode != AudioServiceShuffleMode.none);
  }

  void onRepeatModeChange(PlayerRepeatMode repeatMode) {
    _repeatMode = repeatMode;
    _repeatsLeft = numberOfRepeats.value;
    refreshPlaybackStateModes();
  }

  void onShuffleModeChange(bool shuffled) => unawaited(setQueueShuffled(shuffled));

  PlayerRepeatMode userCycleRepeatMode() {
    final values = PlayerRepeatMode.values;
    final next = values[(displayRepeatMode.index + 1) % values.length];
    onRepeatModeChange(next);
    return next;
  }

  void updateNumberOfRepeats(int value) {
    numberOfRepeats.value = math.max(0, value);
    _repeatsLeft = numberOfRepeats.value;
  }

  @override
  Future<void> setRating(Rating rating, [Map<String, dynamic>? extras]) async {
    final item = currentItem.value;
    if (item != null && rating.getRatingStyle() == RatingStyle.heart && rating.isRated()) {
      onFavouriteRatingRequested(item, rating.hasHeart());
    }
  }

  @override
  Future<void> onQueueChanged() async {
    refreshPlaybackStateModes();
    final request = ++_metadataRequest;
    final items = currentQueue.value;
    final item = currentItem.value;
    if (item == null) {
      queue.add([]);
      mediaItem.add(null);
      return;
    }

    if (publishQueueToMediaBrowser) {
      final media = await Future.wait(items.map(itemToMediaItem));
      if (request != _metadataRequest || !identical(items, currentQueue.value)) return;
      queue.add(media);
    } else {
      queue.add([]);
    }
    if (mediaItem.value?.id != itemToMediaItemId(item)) await _publishMediaItem(item);
  }

  Future<void> _publishMediaItem(Q item) async {
    final media = await itemToMediaItem(item);
    if (identical(currentItem.value, item) && mediaItem.value?.id != media.id) mediaItem.add(media);
  }

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) async =>
    publishQueueToMediaBrowser && parentMediaId == AudioService.browsableRootId
      ? Future.wait(currentQueue.value.map(itemToMediaItem))
      : [];

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    for (final item in currentQueue.value) {
      if (itemToMediaItemId(item) == mediaId) return itemToMediaItem(item);
    }
    return null;
  }

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    final index = currentQueue.value.indexWhere((item) => itemToMediaItemId(item) == mediaId);
    if (index >= 0) {
      setPlayWhenReady(true);
      await skipToQueueItem(index);
    }
  }

  @override
  Future<void>? beforeSkippingToItem() async {
    await super.beforeSkippingToItem();
    final item = _loadedItem;
    if (item != null) await onItemLastPositionReport(item, currentPositionMS.value);
  }

  @override
  Future<void> _playQueueIndex(int index) async {
    final item = currentQueue.value[index];
    final selection = ++_selection;
    _sourceRequest++;
    final player = _player;
    _transportRequest++;
    _outgoingFade = null;
    _incomingFadeMilliseconds = 0;
    _sourceReady = false;
    _loadingSource = false;
    _stopped = false;
    _listenTimer?.cancel();
    _repeatsLeft = numberOfRepeats.value;
    currentPositionMS.value = 0;
    currentState.value = ProcessingState.loading;
    loadedDuration.value = null;
    buffered.value = Duration.zero;
    currentLiveWindow.value = null;
    liveJoinPosition = null;
    _select(index);
    unawaited(_publishMediaItem(item));
    _publishPlayerState();
    beginEarlyCrossFadeOutIfRequired();
    if (_outgoingFade == null) {
      _loadedItem = null;
      await player?.pause();
    }
    if (selection != _selection) return;
    await onItemPlay(item, currentIndex.value, () async {
      if (selection == _selection && !isLastItem) await skipToNext(isManualSkip: false);
    }, null);
    if (selection != _selection) return;
    await _finishOutgoingFade();
    if (selection != _selection) return;
    if (_sourceReady && playWhenReady.value && !currentPlayer.playing) {
      await onPlayRaw(attemptFixVolume: false);
    } else if (!_sourceReady && currentState.value == ProcessingState.loading) {
      currentState.value = ProcessingState.idle;
      _publishPlayerState();
    }
  }

  @override
  Future<void> skipToQueueItem(int index, {bool isManualSkip = true}) async {
    final items = currentQueue.value;
    if (index < 0 || index >= items.length) return;
    final queueItem = items[index];
    if (index == currentIndex.value && _sourceReady) {
      await _restartCurrentItem(resume: playWhenReady.value);
      return;
    }
    final request = ++_queueNavigationRequest;
    await beforeSkippingToItem();
    if (request != _queueNavigationRequest) return;
    if (identical(items, currentQueue.value)) {
      await _playQueueIndex(index);
    } else {
      final moved = currentQueue.value.indexWhere((item) => identical(item, queueItem));
      if (moved >= 0) await _playQueueIndex(moved);
    }
  }

  @override
  Future<void> skipToNext({bool? andPlay, bool isManualSkip = true}) async {
    final length = currentQueue.value.length;
    if (length == 0) return;
    final wrap = isManualSkip
      ? playerInfiniyQueueOnNextPrevious
      : playerRepeatMode == PlayerRepeatMode.all || playerRepeatMode == PlayerRepeatMode.allShuffle;
    final next = currentIndex.value + 1;
    if (next >= length && !wrap) return;
    setPlayWhenReady(andPlay ?? (playWhenReady.value || (isManualSkip && defaultShouldStartPlayingOnNextPrev)));
    await skipToQueueItem(next % length, isManualSkip: isManualSkip);
  }

  @override
  Future<void> skipToPrevious({bool isManualSkip = true}) async {
    final length = currentQueue.value.length;
    if (length == 0 || (currentIndex.value == 0 && !playerInfiniyQueueOnNextPrevious)) return;
    setPlayWhenReady(playWhenReady.value || (isManualSkip && defaultShouldStartPlayingOnNextPrev));
    await skipToQueueItem((currentIndex.value - 1) % length, isManualSkip: isManualSkip);
  }

  Future<void> onPlaybackCompleted() async {
    final timer = sleepTimerConfig.value;
    if (timer.enableSleepAfterItems) {
      final remaining = timer.sleepAfterItems - 1;
      if (remaining <= 0) {
        await _endSleepTimer();
        return;
      }
      updateSleepTimerValues(sleepAfterItems: remaining);
    }

    final mode = playerRepeatMode;
    if (mode == PlayerRepeatMode.one || (mode == PlayerRepeatMode.forNtimes && _repeatsLeft > 0)) {
      if (mode == PlayerRepeatMode.forNtimes) {
        _repeatsLeft--;
        numberOfRepeats.value = _repeatsLeft;
        if (_repeatsLeft == 0) onRepeatModeChange(PlayerRepeatMode.none);
      }
      await _restartCurrentItem(resume: true);
      return;
    }

    if (!isLastItem || mode == PlayerRepeatMode.all || mode == PlayerRepeatMode.allShuffle) {
      if (isLastItem && mode == PlayerRepeatMode.allShuffle) {
        await shuffleAllItems();
        await skipToQueueItem(0, isManualSkip: false);
      } else {
        await skipToNext(andPlay: true, isManualSkip: false);
      }
      return;
    }

    await pause(isUserInitiated: false, awaitLastPositionReport: true);
    if (jumpToFirstItemAfterFinishingQueue && currentQueue.value.isNotEmpty) {
      await skipToQueueItem(0, isManualSkip: false);
    }
  }

  Future<Duration?> setAudioSource(ItemPrepareConfig<Q, UriSource> config) async {
    final item = config.item ?? currentItem.value;
    if (item != currentItem.value) return null;
    final player = currentPlayer;
    final request = ++_sourceRequest;
    final sourceChangingItem = !_sourceReady || !identical(_loadedItem, item);
    _loadingSource = true;
    _sourceReady = false;
    try {
      await _finishOutgoingFade();
      if (request != _sourceRequest) return null;
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        final session = await (_session ??= _configureSession(++_sessionGeneration));
        if (request != _sourceRequest) return null;
        if (Platform.isAndroid && player is CustomAudioPlayer) {
          final attributes = session.configuration?.androidAudioAttributes;
          if (attributes != null) await player._player.setAndroidAudioAttributes(attributes);
        }
      }
      if (request != _sourceRequest) return null;
      if (sourceChangingItem) {
        final settings = await getPlayerConfigForItem(item, player) ?? getDefaultPlayerConfig(item);
        if (request != _sourceRequest) return null;
        await _applyConfig(player, settings);
      }
      if (request != _sourceRequest) return null;
      final duration = await player.setSource(config);
      if (request != _sourceRequest) return null;
      _loadedItem = item;
      _sourceReady = true;
      _stopped = false;
      loadedDuration.value = duration;
      currentPositionMS.value = player.position.inMilliseconds;
      currentState.value = player.processingState;
      _publishPlayerState();
      _setPublishedDuration(item, duration);
      return duration;
    } on PlayerInterruptedException {
      if (request == _sourceRequest) rethrow;
      return null;
    } finally {
      if (request == _sourceRequest) _loadingSource = false;
    }
  }

  void _setPublishedDuration(Q? item, Duration? duration) {
    final published = mediaItem.value;
    if (item != null && duration != null && published != null && published.id == itemToMediaItemId(item) && published.duration != duration) {
      mediaItem.add(published.copyWith(duration: duration));
    }
  }

  Future<void> refreshCurrentItemPlayerConfig() async {
    final player = _player;
    if (player == null) return;
    final item = currentItem.value;
    final config = await getPlayerConfigForItem(item, player) ?? getDefaultPlayerConfig(item);
    if (identical(player, _player) && identical(item, currentItem.value)) await _applyConfig(player, config);
  }

  Future<void> _applyConfig(AVPlayer player, PlayerConfig config) async {
    _userVolume = config.volume;
    await player.setVolume(_effectiveVolume(_userVolume));
    await player.setSpeed(config.speed);
    await player.setPitch(config.pitch);
    await player.setSkipSilenceEnabled(config.skipSilence);
    await player.setEqualizer(config.equalizerEnabled ? config.equalizer : null);
    final enhancer = loudnessEnhancerExtended;
    if (enhancer != null) {
      enhancer._gainUser = config.loudnessEnhancer;
      await enhancer.setEnabledUser(config.loudnessEnhancerEnabled);
    }
  }

  void setPlayWhenReady(bool value) {
    playWhenReady.value = value;
    _publishPlayerState();
  }

  @override
  Future<void> play({bool checkIfPlaybackEnded = true}) async {
    final item = currentItem.value;
    if (item == null) return;
    setPlayWhenReady(true);
    if (!_sourceReady) {
      if (!_loadingSource && _loadedItem == null && currentState.value != ProcessingState.loading) {
        await _playQueueIndex(currentIndex.value);
      }
      return;
    }
    if (checkIfPlaybackEnded && currentState.value == ProcessingState.completed) {
      await _restartCurrentItem(resume: true);
      return;
    }
    await onPlayRaw();
  }

  Future<void> _restartCurrentItem({required bool resume}) async {
    final player = _player;
    final item = currentItem.value;
    final index = currentIndex.value;
    final selection = _selection;
    if (player == null || item == null) return;
    if (!_sourceReady) {
      if (index >= 0 && index < currentQueue.value.length) await _playQueueIndex(index);
      return;
    }

    await onPauseRaw();
    if (selection != _selection || !identical(item, currentItem.value)) return;
    try {
      await seekToItemStart().timeout(const Duration(seconds: 5));
    } catch (_) {
      if (selection == _selection && identical(item, currentItem.value)) {
        final reloadIndex = currentIndex.value;
        if (reloadIndex >= 0 && reloadIndex < currentQueue.value.length) await _playQueueIndex(reloadIndex);
      }
      return;
    }
    if (selection != _selection || !identical(item, currentItem.value)) return;

    var state = player.processingState;
    if (state == ProcessingState.completed || state == ProcessingState.buffering) {
      try {
        state = await player.processingStateStream
            .where((s) => s == ProcessingState.ready || s == ProcessingState.idle)
            .timeout(const Duration(milliseconds: 500))
            .first;
      } catch (_) {
        state = player.processingState;
      }
    }
    if (selection != _selection || !identical(item, currentItem.value)) return;
    if (state != ProcessingState.ready) {
      final reloadIndex = currentIndex.value;
      if (reloadIndex >= 0 && reloadIndex < currentQueue.value.length) await _playQueueIndex(reloadIndex);
      return;
    }
    if (resume && playWhenReady.value) {
      await onPlayRaw(attemptFixVolume: false, allowFade: false);
    }
  }

  Future<void> onPlayRaw({bool attemptFixVolume = true, bool allowFade = true}) async {
    final player = _player;
    if (player == null || !_sourceReady) return;
    final request = ++_transportRequest;
    _stopped = false;
    _interruptedAt = null;
    _noisyAt = null;
    if (player is! CustomAudioPlayer && _session != null) {
      final session = await _session!;
      final activated = await session.setActive(true);
      if (request != _transportRequest) return;
      if (!activated) {
        setPlayWhenReady(false);
        return;
      }
    }
    if (request != _transportRequest || !identical(player, _player)) return;
    final fade = allowFade && !player.playing
        ? math.max(_incomingFadeMilliseconds, enableVolumeFadeOnPlayPause ? playerPlayFadeDurInMilli : 0)
        : 0;
    _incomingFadeMilliseconds = 0;
    final volume = _effectiveVolume(_userVolume);
    if (fade > 0) {
      await player.setVolume(0);
    } else if (attemptFixVolume) {
      await player.setVolume(volume);
    }
    if (request != _transportRequest) return;
    // Android's play response can stay pending until playback pauses or ends.
    unawaited(_startPlayback(player, request));
    if (fade > 0) {
      await _fadeVolume(player, volume, fade, request);
    }
    if (request == _transportRequest) _publishPlayerState();
  }

  Future<void> _startPlayback(AVPlayer player, int request) async {
    try {
      await player.play();
    } catch (error, stackTrace) {
      if (request != _transportRequest) rethrow;
      setPlayWhenReady(false);
      _onPlayerError(error, stackTrace);
      return;
    }
    if (request == _transportRequest) {
      if (!player.playing) setPlayWhenReady(false);
      _publishPlayerState();
    }
  }

  @override
  Future<void> pause({int? pauseFadeMillis, bool awaitLastPositionReport = false, bool isUserInitiated = true}) async {
    if (isUserInitiated) {
      _interruptedAt = null;
      _noisyAt = null;
      _mutedAt = null;
    }
    setPlayWhenReady(false);
    final player = _player;
    final fade = pauseFadeMillis ?? (enableVolumeFadeOnPlayPause ? playerPauseFadeDurInMilli : 0);
    if (player != null && player.playing && fade > 0) {
      final request = ++_transportRequest;
      await _fadeVolume(player, 0, fade, request);
      if (request != _transportRequest) return;
    }
    await onPauseRaw();
    if (player != null && fade > 0 && !player.playing) await player.setVolume(_effectiveVolume(_userVolume));
    final item = _loadedItem;
    if (item != null) {
      final report = onItemLastPositionReport(item, currentPositionMS.value);
      if (awaitLastPositionReport) await report;
    }
  }

  Future<void> onPauseRaw() async {
    _transportRequest++;
    await _player?.pause();
    _publishPlayerState();
  }

  Future<void> togglePlayPause() => playWhenReady.value ? pause() : play();

  @override
  Future<void> stop() async {
    await pause(isUserInitiated: true, awaitLastPositionReport: true);
    _stopped = true;
    await _player?.stop();
    if (_session != null) await (await _session!).setActive(false);
    await super.stop();
  }

  @override
  Future<void> _stopForEmptyQueue() => _disposePlayer();

  Future<void> onDispose() => _disposePlayer();

  Future<void> _disposePlayer() async {
    final player = _player;
    _player = null;
    _selection++;
    _sourceRequest++;
    _transportRequest++;
    _queueNavigationRequest++;
    _sessionGeneration++;
    _loadedItem = null;
    _outgoingFade = null;
    _incomingFadeMilliseconds = 0;
    _sourceReady = false;
    _loadingSource = false;
    _stopped = true;
    _listenTimer?.cancel();
    resetSleepTimer();
    setPlayWhenReady(false);
    final subscriptions = [..._playerSubscriptions, ..._sessionSubscriptions];
    _playerSubscriptions.clear();
    _sessionSubscriptions.clear();
    final session = _session;
    _session = null;
    await Future.wait(subscriptions.map((s) => s.cancel()));
    await player?.dispose();
    if (session != null && _session == null) await (await session).setActive(false);
    if (_player != null) return;
    isPlaying.value = false;
    currentState.value = null;
    currentPositionMS.value = 0;
    loadedDuration.value = null;
    buffered.value = Duration.zero;
    audioTracks.value = null;
    textTracks.value = null;
    subtitleText.value = null;
    videoPlayerInfo.value = null;
    currentLiveWindow.value = null;
    liveJoinPosition = null;
    mediaItem.add(null);
    playbackState.add(PlaybackState());
  }

  @override
  Future<void> seek(Duration position) async {
    final player = _player;
    if (player == null || !_sourceReady) return;
    final start = currentLiveWindow.value?.start.inMilliseconds ?? getCurrentItemStartMS() ?? 0;
    final end = currentLiveWindow.value?.edge.inMilliseconds ?? getCurrentItemEndMS() ?? player.duration?.inMilliseconds;
    final ms = math.max(start, end == null ? position.inMilliseconds : math.min(position.inMilliseconds, end));
    await player.seek(Duration(milliseconds: ms));
    currentPositionMS.value = player.position.inMilliseconds;
    _publishPlayerState();
  }

  Future<void> seekToItemStart() => seek(Duration(milliseconds: getCurrentItemStartMS() ?? 0));

  Future<void> seekToLiveEdge() async {
    final edge = currentLiveWindow.value?.edge;
    if (edge != null) await _player?.seek(edge);
  }

  int? getCurrentItemStartMS() => _currentRange?.start;
  int? getCurrentItemEndMS() => _currentRange?.end;

  ({int? start, int? end})? get _currentRange {
    final item = currentItem.value;
    return canUseItemPlaybackRange && item != null ? _ranges[identifyBy(item)] : null;
  }

  void setItemPlaybackRange(Q item, {int? startMS, int? endMS}) {
    final key = identifyBy(item);
    if (startMS == null && endMS == null) {
      _ranges.remove(key);
    } else {
      _ranges[key] = (start: startMS, end: endMS);
    }
  }

  @override
  Future<void> setSpeed(double speed) => setPlayerSpeed(speed);
  Future<void> setPlayerSpeed(double speed) async => await _player?.setSpeed(speed);
  Future<void> setPitch(double pitch) => setPlayerPitch(pitch);
  Future<void> setPlayerPitch(double pitch) async => await _player?.setPitch(pitch);
  Future<void> setVolume(double volume) => setUserVolumeForItem(volume);
  Future<void> setSkipSilenceEnabled(bool enabled) async => await _player?.setSkipSilenceEnabled(enabled);

  Future<void> setUserVolumeForItem(double volume) async {
    _userVolume = volume.clamp(0.0, 1.0).toDouble();
    await setVolumeWithMultiplier(_userVolume);
    if (!playerPauseOnVolume0) return;
    if (_userVolume == 0 && playWhenReady.value) {
      _mutedAt = DateTime.now();
      await pause(isUserInitiated: false);
    } else if (_userVolume > 0) {
      final muted = _mutedAt;
      _mutedAt = null;
      if (_withinThreshold(muted, defaultVolume0ResumeThreshold)) await play();
    }
  }

  double _effectiveVolume(double volume) =>
    (volume * replayGainLinearVolumeMultiplierValue * (_ducked ? 0.2 : 1)).clamp(0.0, 1.0).toDouble();

  Future<void> setVolumeWithMultiplier(double volume) async => await _player?.setVolume(_effectiveVolume(volume));
  void refreshVolumeForReplayGain() => unawaited(setVolumeWithMultiplier(_userVolume));

  void onVolumeChangeAddListener(String key, void Function(double) fn) => _volumeListeners[key] = fn;
  void onVolumeChangeRemoveListener(String key) => _volumeListeners.remove(key);

  Future<void> executeOnPlayers(Future<void> Function(AVPlayer) action) async {
    final player = _player;
    if (player != null) await action(player);
  }

  Future<void> executeWithPausedOutput(Future<void> Function() action) async {
    final player = _player;
    final resume = player?.playing ?? false;
    if (resume) await onPauseRaw();
    try {
      await action();
    } finally {
      if (resume && playWhenReady.value && identical(player, _player)) await onPlayRaw(attemptFixVolume: false);
    }
  }

  Future<void> setVideo(VideoSourceOptions? options) async {
    final player = _player;
    if (player == null) return;
    try {
      if (options == null) videoPlayerInfo.value = null;
      await player.setVideo(options);
    } catch (error, stackTrace) {
      _handleVideoError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> setAudioTrack(String? trackId) async => await _player?.setAudioTrack(trackId);
  Future<void> setTextTrack(String? trackId) async => await _player?.setTextTrack(trackId);
  Future<bool> setExternalSubtitle(String? uri) async => await _player?.setExternalSubtitle(uri) ?? false;

  void refreshRxVariables() {
    currentIndex.refresh();
    currentItem.refresh();
    currentQueue.queueRx.refresh();
    currentPositionMS.refresh();
    currentSpeed.refresh();
    currentState.refresh();
    isPlaying.refresh();
    playWhenReady.refresh();
  }

  Future<AudioSession> _configureSession(int generation) async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    if (generation != _sessionGeneration) return session;
    _sessionSubscriptions.addAll([
      session.interruptionEventStream.listen((event) => unawaited(_onInterruption(event))),
      session.becomingNoisyEventStream.listen((_) async {
        if (!playWhenReady.value) return;
        if (onBecomingNoisyEventStream == InterruptionAction.pause) _noisyAt = DateTime.now();
        await _applyInterruption(onBecomingNoisyEventStream);
      }),
      session.devicesChangedEventStream.listen(_onDeviceChange),
    ]);
    return session;
  }

  Future<void> _onInterruption(AudioInterruptionEvent event) async {
    if (event.begin) {
      if (!playWhenReady.value) return;
      final type = switch (event.type) {
        AudioInterruptionType.duck => InterruptionType.shouldDuck,
        AudioInterruptionType.pause => InterruptionType.shouldPause,
        AudioInterruptionType.unknown => InterruptionType.unknown,
      };
      final action = defaultOnInterruption(type);
      if (action == InterruptionAction.pause) {
        _interruptedAt = type == InterruptionType.unknown ? null : DateTime.now();
      }
      await _applyInterruption(action);
    } else {
      if (_ducked) {
        _ducked = false;
        await setVolumeWithMultiplier(_userVolume);
      }
      final interruption = _interruptedAt;
      _interruptedAt = null;
      if (_withinThreshold(interruption, defaultInterruptionResumeThreshold)) await play();
    }
  }

  Future<void> _applyInterruption(InterruptionAction action) async {
    switch (action) {
      case InterruptionAction.doNothing:
        return;
      case InterruptionAction.duckAudio:
        _ducked = true;
        await setVolumeWithMultiplier(_userVolume);
      case InterruptionAction.pause:
        await pause(isUserInitiated: false, pauseFadeMillis: 0);
    }
  }

  void _onDeviceChange(AudioDevicesChangedEvent event) {
    for (final device in event.devicesAdded) {
      final threshold = switch (device.type) {
        AudioDeviceType.wiredHeadphones || AudioDeviceType.wiredHeadset || AudioDeviceType.usbAudio => defaultConnectWiredResumeThresholdMin,
        AudioDeviceType.bluetoothA2dp || AudioDeviceType.bluetoothSco || AudioDeviceType.bluetoothLe => defaultConnectWirelessResumeThresholdMin,
        _ => Duration.zero,
      };
      if (device.isOutput && _withinThreshold(_noisyAt, threshold)) {
        _noisyAt = null;
        unawaited(play());
        return;
      }
    }
  }

  bool _withinThreshold(DateTime? time, Duration threshold) =>
    time != null && threshold > Duration.zero && DateTime.now().difference(time) <= threshold;

  void updateSleepTimerValues({bool? enableSleepAfterItems, bool? enableSleepAfterMins, int? sleepAfterMin, int? sleepAfterItems, bool? isAnchoredToItem}) {
    final old = sleepTimerConfig.value;
    final minutes = (sleepAfterMin ?? old.sleepAfterMin).clamp(0, maximumSleepTimerMins).toInt();
    final items = (sleepAfterItems ?? old.sleepAfterItems).clamp(0, maximumSleepTimerItems).toInt();
    final config = SleepTimerConfig(
      enableSleepAfterItems: items > 0 && (enableSleepAfterItems ?? old.enableSleepAfterItems),
      enableSleepAfterMins: minutes > 0 && (enableSleepAfterMins ?? old.enableSleepAfterMins),
      sleepAfterItems: items,
      sleepAfterMin: minutes,
      isAnchoredToItem: isAnchoredToItem ?? old.isAnchoredToItem,
    );
    sleepTimerConfig.value = config;
    if (enableSleepAfterMins != null || sleepAfterMin != null) {
      _sleepTimer?.cancel();
      if (config.enableSleepAfterMins) _sleepTimer = Timer(Duration(minutes: minutes), () => unawaited(_endSleepTimer()));
    }
  }

  void resetSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepTimerConfig.value = const SleepTimerConfig();
  }

  Future<void> _endSleepTimer() async {
    resetSleepTimer();
    await pause(isUserInitiated: false);
    onSleepTimerEnd();
  }

  Future<void> _loadListenTime() async {
    final saved = await prepareTotalListenTime();
    for (final entry in saved.entries) {
      _listenTime.value[entry.key] = math.max(_listenTime.value[entry.key] ?? 0, entry.value);
    }
    _listenTime.refresh();
  }

  void startCounterToAListen(Q item) {
    _listenTimer?.cancel();
    _listenedSeconds = 0;
    _markedListened = false;
    unawaited(_listenTimeReady);
    _listenTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sourceReady && identical(item, currentItem.value) && isPlaying.value && currentState.value == ProcessingState.ready) {
        _listenedSeconds++;
        final key = itemToTotalListenTimeKey(item);
        if (key != null) {
          final totals = _listenTime.value;
          totals[key] = (totals[key] ?? 0) + 1;
          _listenTime.refresh();
          onTotalListenTimeIncrease(totals, key);
        }
        final duration = loadedDuration.value?.inMilliseconds ?? 0;
        final percentage = duration > 0 ? math.min(100.0, _listenedSeconds * 100000 / duration) : 0.0;
        if (!_markedListened && (_listenedSeconds >= listenCounterMarkPlayedSeconds || percentage >= listenCounterMarkPlayedPercentage)) {
          _markedListened = true;
          unawaited(Future<void>.sync(() => onItemMarkedListened(item, _listenedSeconds, percentage)));
        }
      }
    });
  }

  CrossfadeTransition<Q> _crossfadeTransition = DefaultCrossfadeTransition<Q>();
  void setCrossfadeTransition(CrossfadeTransition<Q> transition) => _crossfadeTransition = transition;

  void beginEarlyCrossFadeOutIfRequired() {
    final player = _player;
    final item = _loadedItem;
    if (!enableCrossFade || defaultGaplessEnabled || _outgoingFade != null || _sourceReady || player == null || !player.playing || item == null) return;
    final milliseconds = _crossfadeTransition.fadeOutMilliseconds(item, defaultCrossFadeMilliseconds);
    if (milliseconds <= 0) return;
    _incomingFadeMilliseconds = milliseconds;
    _outgoingFade = _fadeVolume(player, 0, milliseconds, ++_transportRequest);
  }

  Future<void> _finishOutgoingFade() async {
    final fade = _outgoingFade;
    if (fade == null) return;
    await fade;
    if (!identical(_outgoingFade, fade)) return;
    _outgoingFade = null;
    _loadedItem = null;
    await _player?.pause();
  }

  Future<void> _fadeVolume(AVPlayer player, double target, int milliseconds, int request) async {
    final first = player.volume;
    final clock = Stopwatch()..start();
    while (request == _transportRequest && identical(player, _player)) {
      final progress = (clock.elapsedMilliseconds / milliseconds).clamp(0.0, 1.0).toDouble();
      await player.setVolume(first + (target - first) * progress);
      if (progress == 1) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> resetGaplessPlaybackData() async => await _player?.removeAllMediaNext();
}

class SleepTimerConfig {
  final bool enableSleepAfterItems;
  final bool enableSleepAfterMins;
  final int sleepAfterItems;
  final int sleepAfterMin;
  final bool isAnchoredToItem;

  const SleepTimerConfig({
    this.enableSleepAfterItems = false, this.enableSleepAfterMins = false,
    this.sleepAfterItems = 0, this.sleepAfterMin = 0, this.isAnchoredToItem = false,
  });
}

class CrossFadeCurve {
  const CrossFadeCurve.equalPower();
  double transform(double progress) => math.sin(math.pi * progress / 2);
}

class ItemTiming {
  final int audibleStartMS;
  final int audibleEndMS;
  final int fadeOutStartMS;
  const ItemTiming({required this.audibleStartMS, required this.audibleEndMS, required this.fadeOutStartMS});
}

class BeatGrid {
  final double bpm;
  final double beatOffsetMS;
  const BeatGrid({required this.bpm, required this.beatOffsetMS});
}

abstract class CrossfadeTransition<Q> {
  const CrossfadeTransition();
  int fadeOutMilliseconds(Q item, int fallback);
}

class DefaultCrossfadeTransition<Q> extends CrossfadeTransition<Q> {
  const DefaultCrossfadeTransition();
  @override
  int fadeOutMilliseconds(Q item, int fallback) => fallback;
}

class SmartCrossfadeTransition<Q> extends CrossfadeTransition<Q> {
  final ItemTiming? Function(Q) timingOf;
  const SmartCrossfadeTransition({required this.timingOf});
  @override
  int fadeOutMilliseconds(Q item, int fallback) {
    final timing = timingOf(item);
    if (timing == null || timing.fadeOutStartMS <= 0) return fallback;
    return math.max(0, math.min(fallback, timing.audibleEndMS - timing.fadeOutStartMS));
  }
}

class BeatMatchedCrossfadeTransition<Q> extends SmartCrossfadeTransition<Q> {
  final BeatGrid? Function(Q) gridOf;
  const BeatMatchedCrossfadeTransition({required super.timingOf, required this.gridOf});
  @override
  int fadeOutMilliseconds(Q item, int fallback) {
    final duration = super.fadeOutMilliseconds(item, fallback);
    final grid = gridOf(item);
    if (grid == null || grid.bpm <= 0) return duration;
    final beat = 60000 / grid.bpm;
    return duration < beat ? duration : (duration ~/ beat * beat).round();
  }
}
