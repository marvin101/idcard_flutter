import 'package:flutter/material.dart';
import '../app_routes.dart';
import '../navigation/app_navigation.dart';

/// Shared, keyboard-accessible brand link that preserves the current session.
class CampusHomeLink extends StatelessWidget {
  const CampusHomeLink({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'CampusID homepage',
    button: true,
    child: Tooltip(
      message: 'CampusID homepage',
      child: InkWell(
        onTap: () {
          if (ModalRoute.of(context)?.settings.name == AppRoutes.landing) {
            return;
          }
          AppNavigation.navigateToPage<void>(context, AppRoutes.landing);
        },
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: child,
        ),
      ),
    ),
  );
}
