import 'package:namico_login_manager/namico_login_manager.dart';
import 'package:nampack/reactive/reactive.dart';

import '../class/youtipie_feed/user_channel_info.dart';

enum YoutiLoginProgress { canceled, failed }
enum AccountCookiesValidity { invalid }

typedef YoutiLoginProgressCallback = void Function(YoutiLoginProgress progress, [AccountCookiesValidity? cookiesValidity]);

class YoutiAccountManager {
  final signedInAccounts = Rx<Set<UserChannelInfo>>(const {});
  final activeAccountChannel = Rxn<UserChannelInfo>();

  bool canAddMultiAccounts = false;
  bool get canAuthorizeRequests => false;

  static Future<UserChannelInfo?> signIn({
    required LoginPageConfiguration pageConfig,
    required YoutiLoginProgressCallback onProgress,
    required bool forceSignIn,
  }) async => null;

  bool isSessionExpired(UserChannelInfo account) => false;
  void signOut(UserChannelInfo account) {}
  void setAccount(UserChannelInfo account) {}
  void setAnonymous() {}

  void addOnAccountChanged(void Function() listener) => activeAccountChannel.addListener(listener);
  void removeOnAccountChanged(void Function() listener) => activeAccountChannel.removeListener(listener);
}
