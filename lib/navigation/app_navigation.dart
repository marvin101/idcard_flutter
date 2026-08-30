import 'package:flutter/material.dart';

import '../app_routes.dart';

abstract final class AppNavigation {
  static const primaryModuleRoutes = <String>{
    AppRoutes.dashboard,
    AppRoutes.students,
    AppRoutes.studentFields,
    AppRoutes.schoolProfile,
    AppRoutes.academicSessions,
    AppRoutes.classesSections,
    AppRoutes.users,
    AppRoutes.design,
    AppRoutes.cards,
  };

  static const nestedWorkflowRoutes = <String>{
    AppRoutes.addStudent,
    AppRoutes.editStudent,
    AppRoutes.studentImport,
  };

  static bool isPrimaryModule(String? routeName) =>
      routeName != null && primaryModuleRoutes.contains(routeName);

  static bool isNestedWorkflow(String? routeName) =>
      routeName != null && nestedWorkflowRoutes.contains(routeName);

  static void navigateToModule(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    assert(primaryModuleRoutes.contains(routeName));
    if (ModalRoute.of(context)?.settings.name == routeName) return;
    Navigator.of(context).pushReplacementNamed(routeName, arguments: arguments);
  }

  static Future<T?> navigateToWorkflow<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    assert(nestedWorkflowRoutes.contains(routeName));
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  }

  static void resetToAuthenticatedRoot(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.dashboard, (route) => false);
  }

  static void resetToPublicRoot(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.landing, (route) => false);
  }
}
