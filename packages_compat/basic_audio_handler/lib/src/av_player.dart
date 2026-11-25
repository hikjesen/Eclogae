part of '../basic_audio_handler.dart';

typedef VideoOptions = VideoSourceOptions;

class ItemPrepareConfig<Q, S extends UriSource> {
  final S source;
  final Q? item;
  final int index;
  final Duration? initialPosition;
  final String? audioTrackId;
  final VideoSourceOptions? videoOptions;
  final bool itemExists;
  final bool keepOldVideoSource;

  const ItemPrepareConfig(
    this.source, {
    this.item,
    required this.index,
    required this.initialPosition,
    required this.audioTrackId,
    required this.videoOptions,
    this.itemExists = true,
    this.keepOldVideoSource = false,
  });
}

class ItemPreparedPlayerInfo<Q> {
  final ItemPrepareConfig<Q, UriSource> config;

  const ItemPreparedPlayerInfo(this.config);
}

abstract interface class AVPlayer {
  Stream<PlaybackEvent> get playbackEventStream;
  Stream<List<AudioTrack>?> get audioTracksStream;
  Stream<List<TextTrack>?> get textTracksStream;
  Stream<String?> get subtitleTextStream;
  Stream<VideoInfoData> get videoInfoStream;
  Stream<Duration> get bufferedPositionStream;
  Stream<ProcessingState> get processingStateStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<double> get volumeStream;
  Stream<double> get speedStream;
  Stream<double> get pitchStream;
  Stream<bool> get playingStream;
  Stream<LiveWindow?> get liveWindowStream;

  bool get rendersSubtitlesInternally;
  int? get androidAudioSessionId;
  ProcessingState get processingState;
  Duration get bufferedPosition;
  Duration get position;
  Duration? get duration;
  double get volume;
  double get speed;
  double get pitch;
  bool get playing;
  LiveWindow? get liveWindow;
  bool get supportsSeamlessSpeedChange;
  UriSource? get audioSource;
  bool get isDisposed;
  bool get hasVideoOptions;

  Future<Duration?> setSource<T>(ItemPrepareConfig<T, UriSource> config);
  Future<void> setVideo(VideoSourceOptions? video);
  Future<void> setAudioTrack(String? trackId);
  Future<void> setTextTrack(String? trackId);
  Future<bool> setExternalSubtitle(String? uri);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration? position);
  Future<void> setLoopOne(bool enabled);
  Future<void> stop();
  Future<void> freePlayer();
  Future<void> dispose();
  Future<void> setSkipSilenceEnabled(bool enabled);
  Future<void> setEqualizer(ParametricEqualizer? equalizer);
  Future<void> setAudioOutput(String? device, {required bool bitPerfect, required bool exclusive, required bool mono});
  Future<void> setLoudnessEnhancerEnabled(bool enabled);
  Future<void> setLoudnessEnhancerGain(double gainDb);
  Future<void> setVolume(double volume);
  Future<void> setPitch(double pitch);
  Future<void> setSpeed(double speed);
  Future<bool> addMediaNext<T>(ItemPrepareConfig<T, UriSource> config);
  Future<void> removeAllMediaNext();
}

class CustomAudioPlayer implements AVPlayer {
  CustomAudioPlayer(this._player, {AndroidLoudnessEnhancer? loudnessEnhancer}) : _loudnessEnhancer = loudnessEnhancer;

  final AudioPlayer _player;
  final AndroidLoudnessEnhancer? _loudnessEnhancer;
  UriSource? _source;
  ConcatenatingSource? _playlist;
  bool _disposed = false;
  bool _loopOne = false;

  @override
  Stream<PlaybackEvent> get playbackEventStream => _player.playbackEventStream;
  @override
  Stream<List<AudioTrack>?> get audioTracksStream => _player.audioTracksStream;
  @override
  Stream<List<TextTrack>?> get textTracksStream => _player.textTracksStream;
  @override
  Stream<String?> get subtitleTextStream => _player.subtitleTextStream;
  @override
  Stream<VideoInfoData> get videoInfoStream => _player.videoInfoStream;
  @override
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  @override
  Stream<ProcessingState> get processingStateStream => _player.processingStateStream;
  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Stream<Duration?> get durationStream => _player.durationStream;
  @override
  Stream<double> get volumeStream => _player.volumeStream;
  @override
  Stream<double> get speedStream => _player.speedStream;
  @override
  Stream<double> get pitchStream => _player.pitchStream;
  @override
  Stream<bool> get playingStream => _player.playingStream;
  @override
  Stream<LiveWindow?> get liveWindowStream => _player.liveWindowStream;

  @override
  bool get rendersSubtitlesInternally => false;
  @override
  int? get androidAudioSessionId => _player.androidAudioSessionId;
  @override
  ProcessingState get processingState => _player.processingState;
  @override
  Duration get bufferedPosition => _player.bufferedPosition;
  @override
  Duration get position => _player.position;
  @override
  Duration? get duration => _player.duration;
  @override
  double get volume => _player.volume;
  @override
  double get speed => _player.speed;
  @override
  double get pitch => _player.pitch;
  @override
  bool get playing => _player.playing;
  @override
  LiveWindow? get liveWindow => _player.liveWindow;
  @override
  bool get supportsSeamlessSpeedChange => true;
  @override
  UriSource? get audioSource {
    final playlist = _playlist;
    final index = _player.currentIndex;
    return playlist != null && index != null && index < playlist.children.length ? playlist.children[index] as UriSource : _source;
  }

  @override
  bool get isDisposed => _disposed;
  @override
  bool get hasVideoOptions => _player.videoOptions != null;

  @override
  Future<Duration?> setSource<T>(ItemPrepareConfig<T, UriSource> config) async {
    // Reapply native single-track repeat in case ExoPlayer rebuilt its internal player.
    if (_loopOne) await _player.setLoopMode(LoopMode.one);
    _source = config.source;
    // A playlist can accept a preloaded next audio-only item without reloading this one.
    final playlist = config.videoOptions == null && !config.keepOldVideoSource
        ? ConcatenatingSource(children: [config.source])
        : null;
    _playlist = playlist;
    return _player.setSource(
      playlist ?? config.source,
      initialPosition: config.initialPosition,
      audioTrackId: config.audioTrackId,
      videoOptions: config.videoOptions,
      keepOldVideoSource: config.keepOldVideoSource,
    );
  }

  @override
  Future<void> setVideo(VideoSourceOptions? video) => _player.setVideo(video);
  @override
  Future<void> setAudioTrack(String? trackId) => _player.setAudioTrack(trackId);
  @override
  Future<void> setTextTrack(String? trackId) => _player.setTextTrack(trackId);
  @override
  Future<bool> setExternalSubtitle(String? uri) async => false;
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration? position) => _player.seek(position);
  @override
  Future<void> setLoopOne(bool enabled) async {
    _loopOne = enabled;
    await _player.setLoopMode(enabled ? LoopMode.one : LoopMode.off);
  }

  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> freePlayer() async {
    _playlist = null;
    _source = null;
    await _player.freePlayer();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _player.dispose();
  }

  @override
  Future<void> setSkipSilenceEnabled(bool enabled) => _player.setSkipSilenceEnabled(enabled);

  @override
  Future<void> setEqualizer(ParametricEqualizer? equalizer) async {
    if (Platform.isAndroid) await AndroidAudioOutput.setParametricEqualizer(_equalizerMessage(equalizer));
  }

  @override
  Future<void> setAudioOutput(String? device, {required bool bitPerfect, required bool exclusive, required bool mono}) async {
    // Android output routing is global and is managed by the app's output controller.
  }

  @override
  Future<void> setLoudnessEnhancerEnabled(bool enabled) async => await _loudnessEnhancer?.setEnabled(enabled);
  @override
  Future<void> setLoudnessEnhancerGain(double gainDb) async => await _loudnessEnhancer?.setTargetGain(gainDb);
  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);
  @override
  Future<void> setPitch(double pitch) => _player.setPitch(pitch);
  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<bool> addMediaNext<T>(ItemPrepareConfig<T, UriSource> config) async {
    final playlist = _playlist;
    if (playlist == null || hasVideoOptions || config.videoOptions != null || config.audioTrackId != null || (config.initialPosition ?? Duration.zero) > Duration.zero) return false;
    await removeAllMediaNext();
    if (!identical(playlist, _playlist)) return false;
    await playlist.add(config.source);
    return true;
  }

  @override
  Future<void> removeAllMediaNext() async {
    final playlist = _playlist;
    if (playlist == null) return;
    final index = _player.currentIndex ?? 0;
    if (playlist.children.length > index + 1) await playlist.removeRange(index + 1, playlist.children.length);
    if (index > 0 && identical(playlist, _playlist)) await playlist.removeRange(0, index);
  }
}
