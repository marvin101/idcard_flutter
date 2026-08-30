import 'package:flutter/material.dart';

import 'authenticated_app_bar.dart';

class AuthenticatedShell extends StatefulWidget {
  const AuthenticatedShell({super.key, required this.child});

  final Widget child;

  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  late final Widget _navigation = AuthenticatedNavigationStrip(
    key: GlobalKey(debugLabel: 'persistent-authenticated-navigation'),
  );

  @override
  Widget build(BuildContext context) =>
      _AuthenticatedShellScope(navigation: _navigation, child: widget.child);
}

class _AuthenticatedShellScope extends InheritedWidget {
  const _AuthenticatedShellScope({
    required this.navigation,
    required super.child,
  });

  final Widget navigation;

  static Widget? navigationOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_AuthenticatedShellScope>()
      ?.navigation;

  @override
  bool updateShouldNotify(_AuthenticatedShellScope oldWidget) => false;
}

Widget? persistentAuthenticatedNavigationOf(BuildContext context) =>
    _AuthenticatedShellScope.navigationOf(context);
