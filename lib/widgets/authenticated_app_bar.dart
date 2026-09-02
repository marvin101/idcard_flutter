import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../navigation/authenticated_modules.dart';
import '../navigation/app_navigation.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import 'authenticated_shell.dart';

class AuthenticatedAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const AuthenticatedAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
  });

  final Widget title;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(122);

  @override
  Widget build(BuildContext context) {
    try {
      context.read<AuthProvider>();
    } on ProviderNotFoundException {
      return AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: title,
        actions: actions,
        leading: leading,
      );
    }
    final routeName = ModalRoute.of(context)?.settings.name;
    final navigation =
        persistentAuthenticatedNavigationOf(context) ??
        const AuthenticatedNavigationStrip();

    return AppBar(
      automaticallyImplyLeading: false,
      leading:
          leading ??
          (AppNavigation.showsLeadingBack(routeName)
              ? BackButton(
                  key: const Key('authenticated-leading-back'),
                  onPressed: () =>
                      AppNavigation.navigateBack(context, routeName),
                )
              : null),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      title: Row(
        children: [
          Image.asset(
            'assets/images/campusid_logo.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 10),
          Flexible(child: title),
        ],
      ),
      actions: [
        ...actions,
        IconButton(
          key: const Key('authenticated-sign-out'),
          tooltip: 'Sign out',
          onPressed: () async {
            await context.read<AuthProvider>().logout();
            if (!context.mounted) return;
            AppNavigation.resetToPublicRoot(context);
          },
          icon: const Icon(Icons.logout_rounded),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: Container(
          height: 58,
          width: double.infinity,
          color: const Color(0xff172442),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: navigation,
        ),
      ),
    );
  }
}

class AuthenticatedNavigationStrip extends StatefulWidget {
  const AuthenticatedNavigationStrip({super.key});

  @override
  State<AuthenticatedNavigationStrip> createState() =>
      _AuthenticatedNavigationStripState();
}

class _AuthenticatedNavigationStripState
    extends State<AuthenticatedNavigationStrip> {
  static const _motionDuration = Duration(milliseconds: 480);
  static const _motionCurve = Curves.easeInOutCubic;
  static const _navigationBackground = Color(0xff172442);

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _activeItemKey = GlobalKey();
  String? _lastRevealedRoute;
  String? _currentRoute;
  String? _itemSignature;
  double? _lastViewportWidth;
  bool _refreshScheduled = false;
  bool _revealAfterRefresh = false;
  bool _hasOverflow = false;
  bool _canScrollBack = false;
  bool _canScrollForward = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_refreshScrollState);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_refreshScrollState)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.select<AuthProvider, _NavigationAuthState>(
      _NavigationAuthState.from,
    );
    final routeName = ModalRoute.of(context)?.settings.name;
    final items = _navigationItems(authState);
    final itemSignature = items.map((item) => item.route).join('|');
    if (_currentRoute != routeName || _itemSignature != itemSignature) {
      _currentRoute = routeName;
      _itemSignature = itemSignature;
      _lastRevealedRoute = null;
      _scheduleRefresh(revealActive: true);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_lastViewportWidth != constraints.maxWidth) {
          _lastViewportWidth = constraints.maxWidth;
          _scheduleRefresh(revealActive: true);
        }
        return Row(
          children: [
            if (_hasOverflow)
              _NavigationScrollButton(
                key: const Key('top-nav-scroll-left'),
                icon: Icons.chevron_left_rounded,
                tooltip: 'Previous modules',
                onPressed: _canScrollBack ? () => _scrollBy(-1) : null,
              ),
            Expanded(
              child: Stack(
                children: [
                  Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: _hasOverflow,
                    scrollbarOrientation: ScrollbarOrientation.bottom,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      child: Row(
                        children: [
                          for (final item in items) ...[
                            KeyedSubtree(
                              key: _isRouteActive(item.route, routeName)
                                  ? _activeItemKey
                                  : null,
                              child: _NavigationButton(
                                item: item,
                                active: _isRouteActive(item.route, routeName),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _NavigationEdgeFade(
                    alignment: Alignment.centerLeft,
                    visible: _canScrollBack,
                    colors: const [_navigationBackground, Color(0x00172442)],
                  ),
                  _NavigationEdgeFade(
                    alignment: Alignment.centerRight,
                    visible: _canScrollForward,
                    colors: const [Color(0x00172442), _navigationBackground],
                  ),
                ],
              ),
            ),
            if (_hasOverflow)
              _NavigationScrollButton(
                key: const Key('top-nav-scroll-right'),
                icon: Icons.chevron_right_rounded,
                tooltip: 'More modules',
                onPressed: _canScrollForward ? () => _scrollBy(1) : null,
              ),
          ],
        );
      },
    );
  }

  void _scheduleRefresh({required bool revealActive}) {
    _revealAfterRefresh = _revealAfterRefresh || revealActive;
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (!mounted) return;
      final layoutChanged = _refreshScrollState();
      if (_revealAfterRefresh) {
        _revealAfterRefresh = false;
        if (layoutChanged) {
          _scheduleRefresh(revealActive: true);
        } else {
          _revealActiveItem();
        }
      }
    });
  }

  bool _refreshScrollState() {
    if (!mounted || !_scrollController.hasClients) return false;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return false;
    final hasOverflow = position.maxScrollExtent > 1;
    final canScrollBack = hasOverflow && position.pixels > 1;
    final canScrollForward =
        hasOverflow && position.pixels < position.maxScrollExtent - 1;
    if (_hasOverflow == hasOverflow &&
        _canScrollBack == canScrollBack &&
        _canScrollForward == canScrollForward) {
      return false;
    }
    setState(() {
      _hasOverflow = hasOverflow;
      _canScrollBack = canScrollBack;
      _canScrollForward = canScrollForward;
    });
    return true;
  }

  void _revealActiveItem() {
    if (_lastRevealedRoute == _currentRoute) return;
    if (!_scrollController.hasClients) return;
    if (!_scrollController.position.hasContentDimensions) return;
    final renderObject = _activeItemKey.currentContext?.findRenderObject();
    if (renderObject == null) return;
    _lastRevealedRoute = _currentRoute;
    _scrollController.position
        .ensureVisible(
          renderObject,
          alignment: 0.5,
          duration: _motionDuration,
          curve: _motionCurve,
        )
        .then((_) => _refreshScrollState());
  }

  void _scrollBy(int direction) {
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) {
      return;
    }
    final position = _scrollController.position;
    final distance = (position.viewportDimension * 0.72).clamp(240.0, 520.0);
    final target = (position.pixels + (distance * direction))
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _scrollController
        .animateTo(target, duration: _motionDuration, curve: _motionCurve)
        .then((_) => _refreshScrollState());
  }
}

List<_NavigationItem> _navigationItems(_NavigationAuthState auth) {
  final modules = dashboardModulesFor(
    isPlatformAdmin: auth.isPlatformAdmin,
    schoolRole: auth.schoolRole,
    hasSelectedSchool: auth.hasSelectedSchool,
  );
  return [
    const _NavigationItem(
      'Dashboard',
      Icons.dashboard_outlined,
      AppRoutes.dashboard,
    ),
    if (modules.contains(DashboardModuleKind.students))
      const _NavigationItem(
        'Students',
        Icons.people_outline,
        AppRoutes.students,
      ),
    if (modules.contains(DashboardModuleKind.students) &&
        auth.canManageCardData)
      const _NavigationItem(
        'Add Student',
        Icons.person_add_alt,
        AppRoutes.addStudent,
      ),
    if (modules.contains(DashboardModuleKind.studentFields))
      const _NavigationItem(
        'Student Fields',
        Icons.dynamic_form_outlined,
        AppRoutes.studentFields,
      ),
    if (modules.contains(DashboardModuleKind.publicForms))
      const _NavigationItem(
        'Public Forms',
        Icons.public_outlined,
        AppRoutes.publicForms,
      ),
    if (modules.contains(DashboardModuleKind.schoolProfile))
      const _NavigationItem(
        'School Profile',
        Icons.domain_outlined,
        AppRoutes.schoolProfile,
      ),
    if (modules.contains(DashboardModuleKind.academicSessions))
      const _NavigationItem(
        'Academic Sessions',
        Icons.calendar_month_outlined,
        AppRoutes.academicSessions,
      ),
    if (modules.contains(DashboardModuleKind.classesAndSections))
      const _NavigationItem(
        'Classes & Sections',
        Icons.account_tree_outlined,
        AppRoutes.classesSections,
      ),
    if (modules.contains(DashboardModuleKind.users))
      const _NavigationItem(
        'Users',
        Icons.manage_accounts_outlined,
        AppRoutes.users,
      ),
    if (auth.canDesignCards)
      const _NavigationItem('Design', Icons.palette_outlined, AppRoutes.design),
    if (modules.contains(DashboardModuleKind.idCards))
      const _NavigationItem('Cards', Icons.badge_outlined, AppRoutes.cards),
  ];
}

class _NavigationAuthState {
  const _NavigationAuthState({
    required this.isPlatformAdmin,
    required this.schoolRole,
    required this.hasSelectedSchool,
    required this.canManageCardData,
    required this.canDesignCards,
  });

  factory _NavigationAuthState.from(AuthProvider auth) => _NavigationAuthState(
    isPlatformAdmin: auth.isPlatformAdmin,
    schoolRole: auth.selectedSchoolAccess?.role,
    hasSelectedSchool: auth.selectedSchool != null,
    canManageCardData: auth.canManageCardData,
    canDesignCards: auth.canDesignCards,
  );

  final bool isPlatformAdmin;
  final String? schoolRole;
  final bool hasSelectedSchool;
  final bool canManageCardData;
  final bool canDesignCards;

  @override
  bool operator ==(Object other) =>
      other is _NavigationAuthState &&
      other.isPlatformAdmin == isPlatformAdmin &&
      other.schoolRole == schoolRole &&
      other.hasSelectedSchool == hasSelectedSchool &&
      other.canManageCardData == canManageCardData &&
      other.canDesignCards == canDesignCards;

  @override
  int get hashCode => Object.hash(
    isPlatformAdmin,
    schoolRole,
    hasSelectedSchool,
    canManageCardData,
    canDesignCards,
  );
}

class _NavigationEdgeFade extends StatelessWidget {
  const _NavigationEdgeFade({
    required this.alignment,
    required this.visible,
    required this.colors,
  });

  final Alignment alignment;
  final bool visible;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Positioned(
    left: alignment == Alignment.centerLeft ? 0 : null,
    right: alignment == Alignment.centerRight ? 0 : null,
    top: 0,
    bottom: 4,
    child: IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        child: Container(
          width: 34,
          decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
        ),
      ),
    ),
  );
}

class _NavigationScrollButton extends StatelessWidget {
  const _NavigationScrollButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: onPressed == null ? 0 : 1),
    duration: const Duration(milliseconds: 240),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Transform.scale(
      scale: 0.9 + (value * 0.1),
      child: Opacity(opacity: 0.38 + (value * 0.62), child: child),
    ),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: Colors.white,
      disabledColor: Colors.white,
      visualDensity: VisualDensity.compact,
    ),
  );
}

bool _isRouteActive(String itemRoute, String? currentRoute) {
  if (itemRoute == AppRoutes.addStudent &&
      currentRoute == AppRoutes.editStudent) {
    return true;
  }
  return itemRoute == currentRoute;
}

class _NavigationItem {
  const _NavigationItem(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({required this.item, required this.active});

  final _NavigationItem item;
  final bool active;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: Key('top-nav-${item.route}'),
    onPressed: active
        ? null
        : () {
            if (AppNavigation.isPrimaryModule(item.route)) {
              AppNavigation.navigateToModule(context, item.route);
            } else {
              AppNavigation.navigateToWorkflow<void>(context, item.route);
            }
          },
    icon: Icon(item.icon, size: 18),
    label: Text(item.label),
    style:
        TextButton.styleFrom(
          foregroundColor: active ? AppColors.primary : Colors.white,
          backgroundColor: active ? Colors.white : Colors.transparent,
          disabledForegroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          shape: const StadiumBorder(),
        ).copyWith(
          animationDuration: const Duration(milliseconds: 300),
          overlayColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: 0.12),
          ),
        ),
  );
}
