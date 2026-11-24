import '../execute_details.dart';
import '../items_sort.dart';
import '../map_serializable.dart';

class YoutiPieListWrapper<T extends MapSerializable> extends MapSerializable {
  const YoutiPieListWrapper({required this.items, this.cacheKey, this.continuation});

  final List<T> items;
  @override
  final String? cacheKey;
  final String? continuation;

  int get length => items.length;
  bool get isEmpty => items.isEmpty;
  bool get canFetchNext => false;

  Future<bool> fetchNext() => fetchNextFunction(null);
  Future<bool> fetchNextFunction(ExecuteDetails? details) async => false;
  YoutiPieFetchAllRes? fetchAll({void Function()? onProgress, ExecuteDetails? details}) => null;

  Map<String, Object?> toMapRaw() => {
    'items': items.map((item) => item.toMap()).toList(),
    'cacheKey': cacheKey,
    'continuation': continuation,
  };

  @override
  Map<String, Object?> toMap() => toMapRaw();
}

mixin YoutiPieListSorterMixin<T extends MapSerializable> on YoutiPieListWrapper<T> {
  List<YoutiPieItemsSort> get itemsSort => const [];
  YoutiPieItemsSort? get customSort => null;

  Future<bool> fetchWithNewSort({required YoutiPieItemsSort sort, ExecuteDetails? details}) async => false;
}

enum YoutiPieFetchAllResType { alreadyDone, success, fail, inProgress, alreadyCanceled }

class YoutiPieFetchAllRes {
  const YoutiPieFetchAllRes();

  bool get isExecuting => false;
  Future<YoutiPieFetchAllResType> get result async => YoutiPieFetchAllResType.alreadyDone;
  void cancel() {}
}
