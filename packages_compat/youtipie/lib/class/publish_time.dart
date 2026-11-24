import 'map_serializable.dart';

class PublishTime extends MapSerializable {
  const PublishTime(this.date, {this.isApproximate = false});
  const PublishTime.unknown() : this(null);

  final DateTime? date;
  final bool isApproximate;
  DateTime? get accurateDate => isApproximate ? null : date;

  factory PublishTime.fromMap(Map<Object?, Object?> map) {
    final date = map['date'];
    return PublishTime(
      switch (date) {
        int value => DateTime.fromMillisecondsSinceEpoch(value),
        String value => DateTime.tryParse(value),
        _ => null,
      },
      isApproximate: map['isApproximate'] as bool? ?? false,
    );
  }

  @override
  Map<String, Object?> toMap() => {'date': date?.millisecondsSinceEpoch, 'isApproximate': isApproximate};
}
