import 'package:flutter/material.dart';

import '../app_routes.dart';
import 'app_router.dart';

class AppNavigationGuard extends InheritedWidget {
  const AppNavigationGuard({
    super.key,
    required this.onNavigateAway,
    required super.child,
  });

  final Future<bool> Function() onNavigateAway;

  static AppNavigationGuard? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppNavigationGuard>();

  @override
  bool updateShouldNotify(AppNavigationGuard oldWidget) =>
      oldWidget.onNavigateAway != onNavigateAway;
}

abstract final class AppNavigation {
  static const primaryModuleRoutes = <String>{
    AppRoutes.dashboard,
    AppRoutes.students,
    AppRoutes.studentFields,
    AppRoutes.publicForms,
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
    AppRoutes.bulkPhotoImport,
    AppRoutes.studentGrid,
  };

  static bool isPrimaryModule(String? routeName) =>
      routeName != null && primaryModuleRoutes.contains(routeName);

  static bool isNestedWorkflow(String? routeName) =>
      routeName != null &&
      (nestedWorkflowRoutes.contains(routeName) ||
          AppRoutes.isStudentHistory(routeName));

  static bool showsLeadingBack(String? routeName) =>
      AppRoutes.isProtected(routeName) &&
      routeName != AppRoutes.dashboard &&
      routeName != AppRoutes.students;

  static void navigateToModule(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    assert(primaryModuleRoutes.contains(routeName));
    final guard = AppNavigationGuard.maybeOf(context);
    if (guard != null) {
      guard.onNavigateAway().then((allowed) {
        if (allowed && context.mounted) {
          _navigateToModuleUnchecked(context, routeName, arguments);
        }
      });
      return;
    }
    _navigateToModuleUnchecked(context, routeName, arguments);
  }

  static void _navigateToModuleUnchecked(
    BuildContext context,
    String routeName,
    Object? arguments,
  ) {
    final delegate = _delegate(context);
    if (delegate != null) {
      if (delegate.currentLocation == routeName) return;
      Router.neglect(
        context,
        () => delegate.go(routeName, arguments: arguments),
      );
      return;
    }
    if (ModalRoute.of(context)?.settings.name == routeName) return;
    Navigator.of(context).pushReplacementNamed(routeName, arguments: arguments);
  }

  static Future<T?> navigateToWorkflow<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    assert(nestedWorkflowRoutes.contains(routeName));
    return _navigateToWorkflowGuarded<T>(context, routeName, arguments);
  }

  static Future<T?> _navigateToWorkflowGuarded<T>(
    BuildContext context,
    String routeName,
    Object? arguments,
  ) async {
    final guard = AppNavigationGuard.maybeOf(context);
    if (guard != null && !await guard.onNavigateAway()) return null;
    if (!context.mounted) return null;
    final delegate = _delegate(context);
    if (delegate != null) {
      late Future<T?> result;
      Router.navigate(context, () {
        result = delegate.pushWorkflow<T>(routeName, arguments: arguments);
      });
      return result;
    }
    return Navigator.of(
      context,
    ).pushNamed(routeName, arguments: arguments).then((value) => value as T?);
  }

  static void navigateBack<T>(
    BuildContext context,
    String? routeName, {
    T? result,
  }) {
    final guard = AppNavigationGuard.maybeOf(context);
    if (guard != null) {
      guard.onNavigateAway().then((allowed) {
        if (allowed && context.mounted) {
          _navigateBackUnchecked(context, routeName, result);
        }
      });
      return;
    }
    _navigateBackUnchecked(context, routeName, result);
  }

  static void _navigateBackUnchecked<T>(
    BuildContext context,
    String? routeName,
    T? result,
  ) {
    final delegate = _delegate(context);
    if (isNestedWorkflow(routeName) || (delegate?.canPop ?? false)) {
      if (delegate != null) {
        delegate.popCurrent<T>(result);
      } else {
        Navigator.of(context).maybePop(result);
      }
      return;
    }

    final destination = routeName == AppRoutes.studentFields
        ? AppRoutes.students
        : AppRoutes.dashboard;
    _navigateToModuleUnchecked(context, destination, null);
  }

  static Future<T?> navigateToPage<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    final guard = AppNavigationGuard.maybeOf(context);
    if (guard != null && !await guard.onNavigateAway()) return null;
    if (!context.mounted) return null;
    final delegate = _delegate(context);
    if (delegate != null) {
      return delegate.pushPage<T>(routeName, arguments: arguments);
    }
    return Navigator.of(
      context,
    ).pushNamed(routeName, arguments: arguments).then((value) => value as T?);
  }

  static void resetToAuthenticatedRoot(BuildContext context) {
    final delegate = _delegate(context);
    if (delegate != null) {
      Router.neglect(context, () => delegate.go(AppRoutes.dashboard));
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.dashboard, (route) => false);
  }

  static void resetToPublicRoot(BuildContext context) {
    final delegate = _delegate(context);
    if (delegate != null) {
      Router.neglect(context, () => delegate.go(AppRoutes.landing));
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.landing, (route) => false);
  }

  static Future<T?> navigateToPublicRoute<T>(
    BuildContext context,
    String routeName, {
    bool replace = false,
  }) {
    final delegate = _delegate(context);
    if (delegate != null) {
      if (replace) {
        Router.neglect(context, () => delegate.go(routeName));
        return Future<T?>.value();
      } else {
        return delegate.pushPage<T>(routeName);
      }
    }
    final result = replace
        ? Navigator.of(context).pushReplacementNamed(routeName)
        : Navigator.of(context).pushNamed(routeName);
    return result.then((value) => value as T?);
  }

  static AppRouterDelegate? _delegate(BuildContext context) {
    final router = Router.maybeOf<Object>(context);
    final delegate = router?.routerDelegate;
    return delegate is AppRouterDelegate ? delegate : null;
  }
}
