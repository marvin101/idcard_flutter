import 'dart:async';

import 'package:flutter/material.dart';

import '../app_routes.dart';

class AppRouteState {
  const AppRouteState(this.location, {this.arguments});

  final String location;
  final Object? arguments;
}

class AppRouteInformationParser extends RouteInformationParser<AppRouteState> {
  const AppRouteInformationParser();

  @override
  Future<AppRouteState> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;
    final fragment = uri.fragment;
    final location = fragment.startsWith('/') ? fragment : uri.path;
    return AppRouteState(
      _knownLocation(location),
      arguments: routeInformation.state,
    );
  }

  @override
  RouteInformation restoreRouteInformation(AppRouteState configuration) =>
      RouteInformation(uri: Uri.parse(configuration.location));

  String _knownLocation(String location) {
    final normalized = location.isEmpty ? AppRoutes.landing : location;
    if (normalized == AppRoutes.landing ||
        normalized == AppRoutes.signIn ||
        normalized == AppRoutes.register ||
        normalized == AppRoutes.privacy ||
        normalized == AppRoutes.terms ||
        normalized == AppRoutes.support ||
        AppRoutes.isProtected(normalized)) {
      return normalized;
    }
    return AppRoutes.landing;
  }
}

typedef AppRouteWidgetBuilder =
    Widget Function(String location, Object? arguments);

class AppRouterDelegate extends RouterDelegate<AppRouteState>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRouteState> {
  AppRouterDelegate(this._routeBuilder);

  final AppRouteWidgetBuilder _routeBuilder;
  final List<_AppRouteEntry> _entries = [];
  int _nextEntryId = 0;
  static const _authenticatedShellPageKey = ValueKey<String>(
    'authenticated-shell-page',
  );

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  AppRouteState? get currentConfiguration {
    if (_entries.isEmpty) return null;
    final current = _entries.last;
    return AppRouteState(current.location, arguments: current.arguments);
  }

  String? get currentLocation =>
      _entries.isEmpty ? null : _entries.last.location;

  bool get canPop => _entries.length > 1;

  @override
  Future<void> setNewRoutePath(AppRouteState configuration) async {
    _replaceWithLocation(configuration.location, configuration.arguments);
  }

  void go(String location, {Object? arguments}) {
    if (currentLocation == location) return;
    _replaceWithLocation(location, arguments);
  }

  Future<T?> pushWorkflow<T>(String location, {Object? arguments}) {
    if (_entries.isEmpty) {
      _entries.add(_entry(AppRoutes.students));
    }
    return pushPage<T>(location, arguments: arguments);
  }

  Future<T?> pushPage<T>(String location, {Object? arguments}) {
    final completer = Completer<Object?>();
    _entries.add(_entry(location, arguments, completer));
    notifyListeners();
    return completer.future.then((value) => value as T?);
  }

  void popCurrent<T>([T? result]) {
    if (_entries.length <= 1) return;
    final removed = _entries.removeLast();
    _complete(removed, result);
    notifyListeners();
  }

  @override
  Future<bool> popRoute() async {
    if (_entries.length <= 1) return false;
    popCurrent<void>();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) {
      _entries.add(_entry(AppRoutes.landing));
    }
    final current = _entries.last;
    return Navigator(
      key: navigatorKey,
      pages: AppRoutes.isProtected(current.location)
          ? [_authenticatedPageFor(current)]
          : [for (final entry in _entries) _pageFor(entry)],
      onDidRemovePage: (page) {
        if (page.key == _authenticatedShellPageKey) return;
        final index = _entries.indexWhere((entry) => entry.key == page.key);
        if (index < 0) return;
        final removed = _entries.removeAt(index);
        _complete(removed, null);
        notifyListeners();
      },
    );
  }

  Page<dynamic> _authenticatedPageFor(_AppRouteEntry entry) {
    void onPopInvoked(bool didPop, Object? result) {
      if (!didPop || _entries.length <= 1) return;
      final removed = _entries.removeLast();
      _complete(removed, result);
      notifyListeners();
    }

    return MaterialPage<dynamic>(
      key: _authenticatedShellPageKey,
      name: entry.location,
      arguments: entry.arguments,
      onPopInvoked: onPopInvoked,
      child: _routeBuilder(entry.location, entry.arguments),
    );
  }

  Page<dynamic> _pageFor(_AppRouteEntry entry) {
    void onPopInvoked(bool didPop, Object? result) {
      if (!didPop) return;
      final index = _entries.indexWhere((item) => item.key == entry.key);
      if (index < 0) return;
      final removed = _entries.removeAt(index);
      _complete(removed, result);
      notifyListeners();
    }

    final child = _routeBuilder(entry.location, entry.arguments);
    if (entry.location == AppRoutes.studentImport) {
      return MaterialPage<bool>(
        key: entry.key,
        name: entry.location,
        arguments: entry.arguments,
        onPopInvoked: onPopInvoked,
        child: child,
      );
    }
    return MaterialPage<dynamic>(
      key: entry.key,
      name: entry.location,
      arguments: entry.arguments,
      onPopInvoked: onPopInvoked,
      child: child,
    );
  }

  void _replaceWithLocation(String location, Object? arguments) {
    for (final entry in _entries) {
      _complete(entry, null);
    }
    _entries
      ..clear()
      ..addAll(
        _isNestedWorkflow(location)
            ? [_entry(AppRoutes.students), _entry(location, arguments)]
            : [_entry(location, arguments)],
      );
    notifyListeners();
  }

  _AppRouteEntry _entry(
    String location, [
    Object? arguments,
    Completer<Object?>? completer,
  ]) => _AppRouteEntry(
    key: ValueKey('app-route-${_nextEntryId++}-$location'),
    location: location,
    arguments: arguments,
    completer: completer,
  );

  bool _isNestedWorkflow(String location) =>
      location == AppRoutes.addStudent ||
      location == AppRoutes.editStudent ||
      location == AppRoutes.studentImport;

  void _complete(_AppRouteEntry entry, Object? result) {
    final completer = entry.completer;
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }
}

class _AppRouteEntry {
  const _AppRouteEntry({
    required this.key,
    required this.location,
    required this.arguments,
    required this.completer,
  });

  final LocalKey key;
  final String location;
  final Object? arguments;
  final Completer<Object?>? completer;
}
