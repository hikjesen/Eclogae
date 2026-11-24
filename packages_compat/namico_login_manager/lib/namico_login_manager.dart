import 'package:flutter/widgets.dart';

enum SignInDecision { forceSignIn }

final class LoginPageConfiguration {
  const LoginPageConfiguration({
    required this.header,
    required this.popPage,
    required this.pushPage,
  });

  final Widget header;
  final void Function(BuildContext context) popPage;
  final void Function(Widget page, bool opaque) pushPage;
}

abstract final class NamicoLoginManager {
  static set windowsBrowserArguments(String? arguments) {}
}
