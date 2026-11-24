import '../core/enum.dart';

final class SupportTier {
  const SupportTier();

  String? get userName => null;
  String? get imageUrl => null;
  num? get ammountUSD => null;
  DateTime? get createdAt => null;
  DateTime? get declinedSince => null;
  DateTime? get lastChecked => null;

  MembershipType toMembershipType() => MembershipType.none;
}
