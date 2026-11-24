import '../map_serializable.dart';

abstract class YoutubeFeed extends MapSerializable {
  const YoutubeFeed();

  bool get isShortContent => false;
}
