import '../core/enum.dart';

final class SupabaseSub {
  const SupabaseSub();

  String? get uuid => null;
  String? get email => null;
  String? get name => null;
  DateTime? get availableTill => null;
  DateTime? get lastChecked => null;
  int get days => 0;
  bool get claimed => false;

  MembershipType toMembershipType() => MembershipType.none;
}
