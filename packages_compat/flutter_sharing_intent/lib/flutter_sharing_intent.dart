final class SharedFile {
  const SharedFile({this.value, this.realPath});

  final String? value;
  final String? realPath;
}

final class FlutterSharingIntent {
  const FlutterSharingIntent._();

  static const instance = FlutterSharingIntent._();

  Future<List<SharedFile>> getInitialSharing() async => const [];

  Stream<List<SharedFile>> getMediaStream() => const Stream.empty();
}
