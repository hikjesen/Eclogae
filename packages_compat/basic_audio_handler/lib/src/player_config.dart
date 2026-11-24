part of '../basic_audio_handler.dart';

enum PlayerRepeatMode { none, one, all, allShuffle, forNtimes }

enum InterruptionType { shouldPause, shouldDuck, unknown }

enum InterruptionAction { doNothing, duckAudio, pause }

enum EqualizerChannel { all, left, right }

enum EqualizerBandType {
  peak, lowShelf, highShelf, lowPass, highPass, bandPass, notch, allPass;

  bool get hasGain => this == peak || this == lowShelf || this == highShelf;
  bool get hasOrder => this == lowPass || this == highPass;
}

class EqualizerBand {
  static const kMinFrequency = 20.0;
  static const kMaxFrequency = 20000.0;
  static const kMinGain = -24.0;
  static const kMaxGain = 24.0;
  static const kMinQ = 0.1;
  static const kMaxQ = 20.0;
  static const kDefaultQ = 0.7071067811865476;
  static const kOrders = [2, 4, 6, 8];

  final int id;
  final double frequency;
  final double gain;
  final double q;
  final int order;
  final EqualizerBandType type;
  final EqualizerChannel channel;
  final bool enabled;

  const EqualizerBand({
    required this.id,
    required this.frequency,
    this.gain = 0,
    this.q = kDefaultQ,
    this.order = 2,
    this.type = EqualizerBandType.peak,
    this.channel = EqualizerChannel.all,
    this.enabled = true,
  });

  int get sectionCount => type.hasOrder ? order ~/ 2 : 1;
  double sectionQ(int section) => sectionCount == 1 ? q : 1 / (2 * math.cos((2 * section + 1) * math.pi / (2 * order)));

  EqualizerBand copyWith({
    double? frequency, double? gain, double? q, int? order,
    EqualizerBandType? type, EqualizerChannel? channel, bool? enabled,
  }) => EqualizerBand(
    id: id, frequency: frequency ?? this.frequency, gain: gain ?? this.gain,
    q: q ?? this.q, order: order ?? this.order, type: type ?? this.type,
    channel: channel ?? this.channel, enabled: enabled ?? this.enabled,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'frequency': frequency, 'gain': gain, 'q': q, 'order': order,
    'type': type.name, 'channel': channel.name, 'enabled': enabled,
  };

  factory EqualizerBand.fromMap(Map map) => EqualizerBand(
    id: (map['id'] as num?)?.toInt() ?? 0,
    frequency: (map['frequency'] as num).clamp(kMinFrequency, kMaxFrequency).toDouble(),
    gain: ((map['gain'] as num?) ?? 0.0).clamp(kMinGain, kMaxGain).toDouble(),
    q: ((map['q'] as num?) ?? kDefaultQ).clamp(kMinQ, kMaxQ).toDouble(),
    order: map['order'] is int && kOrders.contains(map['order']) ? map['order'] as int : 2,
    type: _readEnum(EqualizerBandType.values, map['type']) ?? EqualizerBandType.peak,
    channel: _readEnum(EqualizerChannel.values, map['channel']) ?? EqualizerChannel.all,
    enabled: map['enabled'] as bool? ?? true,
  );

  Object get _identity => (id, frequency, gain, q, order, type, channel, enabled);
  @override
  bool operator ==(Object other) => other is EqualizerBand && _identity == other._identity;
  @override
  int get hashCode => _identity.hashCode;
}

T? _readEnum<T extends Enum>(List<T> values, Object? value) {
  if (value is int && value >= 0 && value < values.length) return values[value];
  return values.where((e) => e.name == value).firstOrNull;
}

class ParametricEqualizer {
  static const kMinPreamp = -30.0;
  static const kMaxPreamp = 30.0;
  static const flat = ParametricEqualizer();

  static const graphic5Frequencies = <double>[60, 250, 1000, 4000, 16000];
  static const graphic10Frequencies = <double>[31.5, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
  static const graphic15Frequencies = <double>[25, 40, 63, 100, 160, 250, 400, 630, 1000, 1600, 2500, 4000, 6300, 10000, 16000];
  static const graphic31Frequencies = <double>[
    20, 25, 31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630,
    800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000,
    12500, 16000, 20000,
  ];

  final List<EqualizerBand> bands;
  final double preamp;
  final bool autoPreamp;
  final bool limiter;

  const ParametricEqualizer({this.bands = const [], this.preamp = 0, this.autoPreamp = false, this.limiter = false});

  static ParametricEqualizer graphic(Iterable<double> frequencies) => fromLegacyGains({for (final f in frequencies) f: 0});
  static ParametricEqualizer fromLegacyGains(Map<double, double> gains) {
    var id = 0;
    return ParametricEqualizer(bands: [for (final e in gains.entries) EqualizerBand(id: id++, frequency: e.key, gain: e.value)]);
  }

  factory ParametricEqualizer.fromMap(Map? map) {
    if (map == null) return flat;
    final rawBands = map['bands'];
    if (rawBands is! List) {
      final gains = <double, double>{};
      for (final e in map.entries) {
        final frequency = double.tryParse('${e.key}');
        if (frequency != null && e.value is num) gains[frequency] = (e.value as num).toDouble();
      }
      return fromLegacyGains(gains);
    }
    return ParametricEqualizer(
      bands: [for (final band in rawBands.whereType<Map>()) if (band['frequency'] is num) EqualizerBand.fromMap(band)],
      preamp: (map['preamp'] as num?)?.toDouble() ?? 0,
      autoPreamp: map['autoPreamp'] as bool? ?? false,
      limiter: map['limiter'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'bands': bands.map((band) => band.toMap()).toList(),
    'preamp': preamp, 'autoPreamp': autoPreamp, 'limiter': limiter,
  };

  ParametricEqualizer copyWith({List<EqualizerBand>? bands, double? preamp, bool? autoPreamp, bool? limiter}) =>
    ParametricEqualizer(bands: bands ?? this.bands, preamp: preamp ?? this.preamp, autoPreamp: autoPreamp ?? this.autoPreamp, limiter: limiter ?? this.limiter);

  int getNextBandId() => bands.fold(0, (next, band) => math.max(next, band.id + 1));

  ParametricEqualizer withBand(EqualizerBand band) {
    final updated = bands.toList();
    final index = updated.indexWhere((b) => b.id == band.id);
    if (index < 0) {
      updated.add(band);
    } else {
      updated[index] = band;
    }
    return copyWith(bands: updated);
  }

  ParametricEqualizer withoutBand(int id) => copyWith(bands: bands.where((band) => band.id != id).toList());
  List<EqualizerBand> getActiveBands() => bands.where((band) => band.enabled && (!band.type.hasGain || band.gain != 0)).toList();
  bool hasChannelSpecificBands() => bands.any((band) => band.enabled && band.channel != EqualizerChannel.all);

  static List<double> logFrequencies(double minimum, double maximum, int count) =>
    List.generate(count, (i) => minimum * math.pow(maximum / minimum, i / math.max(count - 1, 1)));

  static final _preampFrequencies = logFrequencies(20, 20000, 120);

  double computeEffectivePreamp() {
    if (!autoPreamp) return preamp;
    var peak = 0.0;
    for (final frequency in _preampFrequencies) {
      peak = math.max(peak, _bandResponse(frequency, EqualizerChannel.left));
      peak = math.max(peak, _bandResponse(frequency, EqualizerChannel.right));
    }
    return (-peak).clamp(kMinPreamp, kMaxPreamp).toDouble();
  }

  double responseDb(double frequency, {EqualizerChannel channel = EqualizerChannel.left}) =>
    computeEffectivePreamp() + _bandResponse(frequency, channel);

  List<double> responseCurve(Iterable<double> frequencies, {EqualizerChannel channel = EqualizerChannel.left}) {
    final gain = computeEffectivePreamp();
    return [for (final frequency in frequencies) gain + _bandResponse(frequency, channel)];
  }

  double _bandResponse(double frequency, EqualizerChannel channel) {
    var result = 0.0;
    for (final band in bands) {
      if (!band.enabled || (band.channel != EqualizerChannel.all && band.channel != channel)) continue;
      for (var i = 0; i < band.sectionCount; i++) {
        result += _biquadResponse(band, frequency, band.sectionQ(i));
      }
    }
    return result;
  }

  static double _biquadResponse(EqualizerBand band, double frequency, double q) {
    const sampleRate = 48000;
    final angle = 2 * math.pi * band.frequency / sampleRate;
    final c = math.cos(angle);
    final alpha = math.sin(angle) / (2 * q);
    final a = math.pow(10, band.gain / 40).toDouble();
    final shelf = 2 * math.sqrt(a) * alpha;
    final (b0, b1, b2, a0, a1, a2) = switch (band.type) {
      EqualizerBandType.peak => (1 + alpha * a, -2 * c, 1 - alpha * a, 1 + alpha / a, -2 * c, 1 - alpha / a),
      EqualizerBandType.lowPass => ((1 - c) / 2, 1 - c, (1 - c) / 2, 1 + alpha, -2 * c, 1 - alpha),
      EqualizerBandType.highPass => ((1 + c) / 2, -(1 + c), (1 + c) / 2, 1 + alpha, -2 * c, 1 - alpha),
      EqualizerBandType.bandPass => (alpha, 0.0, -alpha, 1 + alpha, -2 * c, 1 - alpha),
      EqualizerBandType.notch => (1.0, -2 * c, 1.0, 1 + alpha, -2 * c, 1 - alpha),
      EqualizerBandType.allPass => (1 - alpha, -2 * c, 1 + alpha, 1 + alpha, -2 * c, 1 - alpha),
      EqualizerBandType.lowShelf => (
        a * (a + 1 - (a - 1) * c + shelf), 2 * a * (a - 1 - (a + 1) * c), a * (a + 1 - (a - 1) * c - shelf),
        a + 1 + (a - 1) * c + shelf, -2 * (a - 1 + (a + 1) * c), a + 1 + (a - 1) * c - shelf,
      ),
      EqualizerBandType.highShelf => (
        a * (a + 1 + (a - 1) * c + shelf), -2 * a * (a - 1 + (a + 1) * c), a * (a + 1 + (a - 1) * c - shelf),
        a + 1 - (a - 1) * c + shelf, 2 * (a - 1 - (a + 1) * c), a + 1 - (a - 1) * c - shelf,
      ),
    };
    final w = 2 * math.pi * frequency / sampleRate;
    double squaredMagnitude(num x, num y, num z) {
      final real = x + y * math.cos(w) + z * math.cos(2 * w);
      final imaginary = y * math.sin(w) + z * math.sin(2 * w);
      return (real * real + imaginary * imaginary).toDouble();
    }
    return 10 * math.log(math.max(1e-12, squaredMagnitude(b0, b1, b2) / squaredMagnitude(a0, a1, a2))) / math.ln10;
  }

  String toEqualizerApo() {
    final output = StringBuffer()..writeln('Preamp: ${computeEffectivePreamp().toStringAsFixed(6)} dB');
    var channel = EqualizerChannel.all;
    var filterNumber = 0;
    for (final band in bands) {
      if (band.channel != channel) {
        channel = band.channel;
        final name = switch (channel) {
          EqualizerChannel.all => 'all',
          EqualizerChannel.left => 'L',
          EqualizerChannel.right => 'R',
        };
        output.writeln('Channel: $name');
      }

      final type = switch (band.type) {
        EqualizerBandType.peak => 'PK',
        EqualizerBandType.lowShelf => 'LSC',
        EqualizerBandType.highShelf => 'HSC',
        EqualizerBandType.lowPass => 'LPQ',
        EqualizerBandType.highPass => 'HPQ',
        EqualizerBandType.bandPass => 'BP',
        EqualizerBandType.notch => 'NO',
        EqualizerBandType.allPass => 'AP',
      };
      final state = band.enabled ? 'ON' : 'OFF';
      final gain = band.type.hasGain ? ' Gain ${band.gain.toStringAsFixed(6)} dB' : '';
      for (var section = 0; section < band.sectionCount; section++) {
        output.writeln('Filter ${++filterNumber}: $state $type Fc ${band.frequency} Hz$gain Q ${band.sectionQ(section)}');
      }
    }
    return output.toString();
  }

  static ParametricEqualizer? fromEqualizerApo(String input) {
    final bands = <EqualizerBand>[];
    var preamp = 0.0;
    var hasPreamp = false;
    var channel = EqualizerChannel.all;
    final filter = RegExp(r'^Filter\s*\d*:\s*(ON|OFF)\s+(\w+)\s+Fc\s+([\d.]+)\s+Hz(?:\s+Gain\s+([-+\d.]+)\s+dB)?(?:\s+Q\s+([\d.]+))?', caseSensitive: false);
    final preampLine = RegExp(r'^Preamp:\s*([-+\d.]+)\s*dB', caseSensitive: false);
    final channelLine = RegExp(r'^Channel:\s*(all|L|R)$', caseSensitive: false);
    const types = {
      'PK': EqualizerBandType.peak,
      'LS': EqualizerBandType.lowShelf, 'LSC': EqualizerBandType.lowShelf,
      'HS': EqualizerBandType.highShelf, 'HSC': EqualizerBandType.highShelf,
      'LP': EqualizerBandType.lowPass, 'LPQ': EqualizerBandType.lowPass,
      'HP': EqualizerBandType.highPass, 'HPQ': EqualizerBandType.highPass,
      'BP': EqualizerBandType.bandPass, 'NO': EqualizerBandType.notch, 'AP': EqualizerBandType.allPass,
    };
    for (final raw in input.split('\n')) {
      final line = raw.trim();
      final channelName = channelLine.firstMatch(line)?[1];
      if (channelName != null) {
        channel = switch (channelName.toUpperCase()) {
          'L' => EqualizerChannel.left,
          'R' => EqualizerChannel.right,
          _ => EqualizerChannel.all,
        };
        continue;
      }
      final gain = double.tryParse(preampLine.firstMatch(line)?.group(1) ?? '');
      if (gain != null) {
        preamp = gain.clamp(kMinPreamp, kMaxPreamp).toDouble();
        hasPreamp = true;
      }
      final match = filter.firstMatch(line);
      if (match == null) continue;
      final type = types[match[2]!.toUpperCase()];
      final frequency = double.tryParse(match[3]!);
      if (type == null || frequency == null) continue;
      bands.add(EqualizerBand(
        id: bands.length, frequency: frequency.clamp(EqualizerBand.kMinFrequency, EqualizerBand.kMaxFrequency).toDouble(),
        type: type, channel: channel, enabled: match[1]!.toUpperCase() == 'ON',
        gain: (double.tryParse(match[4] ?? '') ?? 0.0).clamp(EqualizerBand.kMinGain, EqualizerBand.kMaxGain).toDouble(),
        q: (double.tryParse(match[5] ?? '') ?? EqualizerBand.kDefaultQ).clamp(EqualizerBand.kMinQ, EqualizerBand.kMaxQ).toDouble(),
      ));
    }
    return bands.isEmpty && !hasPreamp ? null : ParametricEqualizer(bands: bands, preamp: preamp);
  }

  @override
  bool operator ==(Object other) => other is ParametricEqualizer &&
    preamp == other.preamp && autoPreamp == other.autoPreamp && limiter == other.limiter &&
    bands.length == other.bands.length && Iterable<int>.generate(bands.length).every((i) => bands[i] == other.bands[i]);
  @override
  int get hashCode => Object.hash(preamp, autoPreamp, limiter, Object.hashAll(bands));
}

class EqualizerPreset {
  final String name;
  final ParametricEqualizer equalizer;
  const EqualizerPreset({required this.name, required this.equalizer});

  static const allDefaults = [EqualizerPreset(name: 'Flat', equalizer: ParametricEqualizer.flat)];

  static EqualizerPreset? fromMap(Map? map) {
    final name = map?['name'];
    if (name is! String) return null;
    return EqualizerPreset(name: name, equalizer: ParametricEqualizer.fromMap(map!['equalizer'] as Map?));
  }

  Map<String, dynamic> toMap() => {'name': name, 'equalizer': equalizer.toMap()};
  EqualizerPreset copyWith({String? name, ParametricEqualizer? equalizer}) =>
    EqualizerPreset(name: name ?? this.name, equalizer: equalizer ?? this.equalizer);

  @override
  bool operator ==(Object other) => other is EqualizerPreset && name == other.name && equalizer == other.equalizer;
  @override
  int get hashCode => Object.hash(name, equalizer);
}

const _unset = Object();

enum PlayerConfigModificationScale { none, main, alt }

class PlayerConfig {
  final bool skipSilence;
  final bool loudnessEnhancerEnabled;
  final double loudnessEnhancer;
  final bool equalizerEnabled;
  final ParametricEqualizer equalizer;
  final EqualizerPreset? preset;
  final double speed;
  final double volume;
  final double pitch;

  const PlayerConfig({
    this.skipSilence = false, this.loudnessEnhancerEnabled = false, this.loudnessEnhancer = 0,
    this.equalizerEnabled = false, this.equalizer = ParametricEqualizer.flat,
    this.preset, this.speed = 1, this.volume = 1, this.pitch = 1,
  });

  static bool get isSkipSilenceSupported => Platform.isAndroid || Platform.isLinux || Platform.isWindows || Platform.isMacOS || Platform.isIOS;
  static bool get isEqualizerSupported => isSkipSilenceSupported;
  static bool get isLoudnessEnhancerSupported => isSkipSilenceSupported;

  PlayerConfigModificationScale getModificationScale() {
    if (speed != 1 || pitch != 1 || volume != 1) return PlayerConfigModificationScale.main;
    if (skipSilence || equalizerEnabled || loudnessEnhancerEnabled) return PlayerConfigModificationScale.alt;
    return PlayerConfigModificationScale.none;
  }

  factory PlayerConfig.fromMap(Map<String, dynamic> map) => PlayerConfigOverrides.fromMap(map).resolve(const PlayerConfig());

  Map<String, dynamic> toMap() => {
    'skipSilence': skipSilence, 'loudnessEnhancerEnabled': loudnessEnhancerEnabled, 'loudnessEnhancer': loudnessEnhancer,
    'equalizerEnabled': equalizerEnabled, 'equalizer': equalizer.toMap(), 'preset': preset?.toMap(),
    'speed': speed, 'volume': volume, 'pitch': pitch,
  };

  PlayerConfig copyWith({
    bool? skipSilence, bool? loudnessEnhancerEnabled, double? loudnessEnhancer,
    bool? equalizerEnabled, ParametricEqualizer? equalizer, Object? preset = _unset,
    double? speed, double? volume, double? pitch,
  }) => PlayerConfig(
    skipSilence: skipSilence ?? this.skipSilence,
    loudnessEnhancerEnabled: loudnessEnhancerEnabled ?? this.loudnessEnhancerEnabled,
    loudnessEnhancer: loudnessEnhancer ?? this.loudnessEnhancer,
    equalizerEnabled: equalizerEnabled ?? this.equalizerEnabled, equalizer: equalizer ?? this.equalizer,
    preset: identical(preset, _unset) ? this.preset : preset as EqualizerPreset?,
    speed: speed ?? this.speed, volume: volume ?? this.volume, pitch: pitch ?? this.pitch,
  );

  Object get _identity => (skipSilence, loudnessEnhancerEnabled, loudnessEnhancer, equalizerEnabled, equalizer, preset, speed, volume, pitch);
  @override
  bool operator ==(Object other) => other is PlayerConfig && _identity == other._identity;
  @override
  int get hashCode => _identity.hashCode;
}

class PlayerConfigOverrides {
  final bool? skipSilence;
  final bool? loudnessEnhancerEnabled;
  final double? loudnessEnhancer;
  final bool? equalizerEnabled;
  final ParametricEqualizer? equalizer;
  final EqualizerPreset? preset;
  final double? speed;
  final double? volume;
  final double? pitch;
  final int modifiedDate;

  const PlayerConfigOverrides({
    this.skipSilence, this.loudnessEnhancerEnabled, this.loudnessEnhancer,
    this.equalizerEnabled, this.equalizer, this.preset, this.speed, this.volume, this.pitch,
    this.modifiedDate = 0,
  });

  static const none = PlayerConfigOverrides();

  bool get isEmpty => skipSilence == null && loudnessEnhancerEnabled == null && loudnessEnhancer == null &&
    equalizerEnabled == null && equalizer == null && preset == null && speed == null && volume == null && pitch == null;

  factory PlayerConfigOverrides.fromMap(Map<String, dynamic> map) => PlayerConfigOverrides(
    skipSilence: map['skipSilence'] as bool?, loudnessEnhancerEnabled: map['loudnessEnhancerEnabled'] as bool?,
    loudnessEnhancer: (map['loudnessEnhancer'] as num?)?.toDouble(), equalizerEnabled: map['equalizerEnabled'] as bool?,
    equalizer: map['equalizer'] is Map ? ParametricEqualizer.fromMap(map['equalizer'] as Map) : null,
    preset: EqualizerPreset.fromMap(map['preset'] as Map?),
    speed: (map['speed'] as num?)?.toDouble(), volume: (map['volume'] as num?)?.toDouble(),
    pitch: (map['pitch'] as num?)?.toDouble(), modifiedDate: (map['modifiedDate'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    if (skipSilence != null) 'skipSilence': skipSilence,
    if (loudnessEnhancerEnabled != null) 'loudnessEnhancerEnabled': loudnessEnhancerEnabled,
    if (loudnessEnhancer != null) 'loudnessEnhancer': loudnessEnhancer,
    if (equalizerEnabled != null) 'equalizerEnabled': equalizerEnabled,
    if (equalizer != null) 'equalizer': equalizer!.toMap(),
    if (preset != null) 'preset': preset!.toMap(),
    if (speed != null) 'speed': speed,
    if (volume != null) 'volume': volume,
    if (pitch != null) 'pitch': pitch,
    'modifiedDate': modifiedDate,
  };

  PlayerConfig resolve(PlayerConfig defaults) => defaults.copyWith(
    skipSilence: skipSilence, loudnessEnhancerEnabled: loudnessEnhancerEnabled, loudnessEnhancer: loudnessEnhancer,
    equalizerEnabled: equalizerEnabled, equalizer: equalizer,
    preset: equalizer == null && preset == null ? defaults.preset : preset,
    speed: speed, volume: volume, pitch: pitch,
  );

  PlayerConfigOverrides copyWith({
    bool? skipSilence, bool? loudnessEnhancerEnabled, double? loudnessEnhancer,
    bool? equalizerEnabled, ParametricEqualizer? equalizer, Object? preset = _unset,
    double? speed, double? volume, double? pitch, int? modifiedDate,
  }) => PlayerConfigOverrides(
    skipSilence: skipSilence ?? this.skipSilence,
    loudnessEnhancerEnabled: loudnessEnhancerEnabled ?? this.loudnessEnhancerEnabled,
    loudnessEnhancer: loudnessEnhancer ?? this.loudnessEnhancer,
    equalizerEnabled: equalizerEnabled ?? this.equalizerEnabled, equalizer: equalizer ?? this.equalizer,
    preset: identical(preset, _unset) ? this.preset : preset as EqualizerPreset?,
    speed: speed ?? this.speed, volume: volume ?? this.volume, pitch: pitch ?? this.pitch,
    modifiedDate: modifiedDate ?? this.modifiedDate,
  );

  PlayerConfigOverrides copyWithEqualizer(ParametricEqualizer equalizer, EqualizerPreset? preset) =>
    copyWith(equalizer: equalizer, preset: preset);

  PlayerConfigOverrides clear({bool volume = false, bool speed = false, bool pitch = false, bool loudnessEnhancer = false}) => PlayerConfigOverrides(
    skipSilence: skipSilence,
    loudnessEnhancerEnabled: loudnessEnhancerEnabled,
    loudnessEnhancer: loudnessEnhancer ? null : this.loudnessEnhancer,
    equalizerEnabled: equalizerEnabled,
    equalizer: equalizer,
    preset: preset,
    speed: speed ? null : this.speed,
    volume: volume ? null : this.volume,
    pitch: pitch ? null : this.pitch,
    modifiedDate: modifiedDate,
  );
}

ParametricEqualizerMessage _equalizerMessage(ParametricEqualizer? equalizer) => ParametricEqualizerMessage(
  enabled: equalizer != null,
  preamp: equalizer?.computeEffectivePreamp() ?? 0,
  limiter: equalizer?.limiter ?? false,
  bands: [
    for (final band in equalizer?.getActiveBands() ?? const <EqualizerBand>[])
      ParametricEqualizerBandMessage(
        id: band.id, type: ParametricEqualizerBandTypeMessage.values.byName(band.type.name),
        frequency: band.frequency, gain: band.gain, q: band.q, order: band.order,
        channel: ParametricEqualizerChannelMessage.values.byName(band.channel.name),
      ),
  ],
);

class EqualizerExtended {
  final AVPlayer Function() _player;
  EqualizerExtended(this._player);

  // The fork applies the parametric equalizer through AndroidAudioOutput.
  AndroidAudioEffect? get androidAudioEffect => null;

  Future<void> apply(bool enabled, ParametricEqualizer equalizer) => _player().setEqualizer(enabled ? equalizer : null);
}

class LoudnessEnhancerExtended {
  static const kMinGain = -30.0;
  static const kMaxGain = 30.0;

  final AVPlayer Function() _player;
  final bool Function() _trackGainEnabled;
  LoudnessEnhancerExtended(this._player, this._trackGainEnabled);

  final AndroidLoudnessEnhancer? androidAudioEffect = Platform.isAndroid ? AndroidLoudnessEnhancer() : null;
  final targetGainTrack = Rx<double>(0);
  bool _enabledUser = false;
  double _gainUser = 0;

  double getActualGainFromUser(bool enabled, double gain) =>
    ((enabled ? gain : 0.0) + (_trackGainEnabled() ? targetGainTrack.value : 0.0)).clamp(kMinGain, kMaxGain).toDouble();

  Future<void> setEnabledUser(bool enabled) {
    _enabledUser = enabled;
    return _apply();
  }

  Future<void> setTargetGainUser(double gain) {
    _gainUser = gain;
    return _apply();
  }

  Future<void> setTargetGainTrack(double gain) {
    targetGainTrack.value = gain;
    return _apply();
  }

  Future<void> refreshEnabled() => _apply();

  Future<void> _apply() async {
    final gain = getActualGainFromUser(_enabledUser, _gainUser);
    final enabled = _enabledUser || _trackGainEnabled();
    final player = _player();
    final effect = androidAudioEffect;
    if (player is CustomAudioPlayer && effect != null) {
      await effect.setTargetGain(gain);
      await effect.setEnabled(enabled);
    } else {
      await player.setLoudnessEnhancerGain(gain);
      await player.setLoudnessEnhancerEnabled(enabled);
    }
  }
}
