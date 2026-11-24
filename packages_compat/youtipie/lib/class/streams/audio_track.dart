class AudioTrack {
  const AudioTrack({this.langCode, this.displayName, this.id, this.isDefault});

  final String? langCode, displayName, id;
  final bool? isDefault;

  factory AudioTrack.fromMap(Map<Object?, Object?> map) => AudioTrack(
    langCode: map['langCode'] as String?,
    displayName: map['displayName'] as String?,
    id: map['id'] as String?,
    isDefault: map['isDefault'] as bool?,
  );

  Map<String, Object?> toMap() => {'langCode': langCode, 'displayName': displayName, 'id': id, 'isDefault': isDefault};
}
