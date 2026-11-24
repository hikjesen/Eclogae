class CodecInfo {
  const CodecInfo({required this.isAudio, required this.container, required this.codec, this.embeddedAudioInfo});

  final bool isAudio;
  final String container, codec;
  final EmbeddedAudioInfo? embeddedAudioInfo;

  factory CodecInfo.fromMap(Map<Object?, Object?> map) {
    final audioInfo = map['embeddedAudioInfo'] as Map<Object?, Object?>?;
    return CodecInfo(
      isAudio: map['isAudio'] as bool? ?? false,
      container: map['container'] as String? ?? '',
      codec: map['codec'] as String? ?? '',
      embeddedAudioInfo: audioInfo == null ? null : EmbeddedAudioInfo(audioInfo['audioSampleRate'] as int?),
    );
  }

  Map<String, Object?> toMap() => {
    'isAudio': isAudio,
    'container': container,
    'codec': codec,
    if (embeddedAudioInfo != null) 'embeddedAudioInfo': {'audioSampleRate': embeddedAudioInfo!.audioSampleRate},
  };
}

class EmbeddedAudioInfo {
  const EmbeddedAudioInfo(this.audioSampleRate);
  final int? audioSampleRate;
}
