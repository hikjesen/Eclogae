import '../thumbnail.dart';

class UserChannelInfo {
  const UserChannelInfo({required this.id, required this.handler, this.title, this.thumbnails = const [], this.identity = const AccountIdentity()});

  final String id, handler;
  final String? title;
  final List<YoutiPieThumbnail> thumbnails;
  final AccountIdentity identity;
}

class AccountIdentity {
  const AccountIdentity({this.isOwner = true, this.authUser, this.needsMigration = false});

  final bool isOwner, needsMigration;
  final int? authUser;
}
