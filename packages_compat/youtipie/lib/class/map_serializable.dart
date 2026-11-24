abstract class MapSerializable {
  const MapSerializable();

  static const timestampKey = '_ts_';
  static const dummyKey = '_dummy_';

  String? get cacheKey => null;
  DateTime? get timestamp => null;

  Map<String, Object?> toMap();
}
