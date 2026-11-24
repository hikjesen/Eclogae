import 'dart:async';

import 'package:namico_login_manager/namico_login_manager.dart';

import 'class/supabase_sub.dart';
import 'class/support_tier.dart';

abstract final class NamicoSubscriptionManager {
  static const patreon = PatreonSubscriptions._();
  static const supabase = SupabaseSubscriptions._();
  static const cacheManager = SubscriptionCacheManager._();

  static set onError(void Function(String message, Object? error, StackTrace? stackTrace)? callback) {}

  static Future<void> initialize({
    required String dataDirectory,
    required String encryptionKey,
    required bool isNewKey,
  }) async {}
}

final class PatreonSubscriptions {
  const PatreonSubscriptions._();

  Future<SupportTier?> getUserSupportTierInCacheValid() async => null;

  Future<SupportTier?> getUserSupportTierWithoutLogin() async => null;

  Future<SupportTier?> getUserSupportTier({
    required Completer<String?> redirectUrlCompleter,
    required LoginPageConfiguration pageConfig,
    required SignInDecision signIn,
  }) async => null;
}

final class SupabaseSubscriptions {
  const SupabaseSubscriptions._();

  Future<SupabaseSub?> getUserSubValidCache() async => null;

  Future<SupabaseSub?> getUserSubInCache() async => null;

  Future<SupabaseSub> fetchUserValid({
    required String uuid,
    required String email,
    required String? deviceId,
  }) async => const SupabaseSub();

  Future<SupabaseSub> claimSubscription({
    required String uuid,
    required String email,
    required String? deviceId,
  }) async => throw UnsupportedError('Coupon claims are disabled in Namida LX.');

  Future<void> requestMove({
    required String uuid,
    required String email,
    required String? deviceId,
  }) async => throw UnsupportedError('Coupon resets are disabled in Namida LX.');

  Future<SupabaseSub> confirmMove({
    required String uuid,
    required String email,
    required String? deviceId,
    required String moveCode,
  }) async => throw UnsupportedError('Coupon resets are disabled in Namida LX.');
}

final class PatreonToken {
  const PatreonToken({required this.accessToken});

  final String accessToken;
}

final class SubscriptionCacheManager {
  const SubscriptionCacheManager._();

  Future<PatreonToken?> getPatreonTokenCache() async => null;

  void deletePatreonCache() {}

  void deleteSupabaseCache() {}
}

final class SubscriptionAlreadyClaimedException implements Exception {
  const SubscriptionAlreadyClaimedException({this.canReset});

  final bool? canReset;
}
