import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../navigation/authenticated_modules.dart';
import '../navigation/app_navigation.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

class AuthenticatedAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const AuthenticatedAppBar({
    super.key,
    required this.title,
    this.actions = const [],
  });

  final Widget title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(122);

  @override
  Widget build(BuildContext context) {
    AuthProvider auth;
    try {
      auth = context.watch<AuthProvider>();
    } on ProviderNotFoundException {
      return AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: title,
        actions: actions,
      );
    }
    final routeName = ModalRoute.of(context)?.settings.name;
    final modules = dashboardModulesFor(
      isPlatformAdmin: auth.isPlatformAdmin,
      schoolRole: auth.selectedSchoolAccess?.role,
      hasSelectedSchool: auth.selectedSchool != null,
    );

    final items = <_NavigationItem>[
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
        const _NavigationItem(
          'Design',
          Icons.palette_outlined,
          AppRoutes.design,
        ),
      if (modules.contains(DashboardModuleKind.idCards))
        const _NavigationItem('Cards', Icons.badge_outlined, AppRoutes.cards),
    ];

    return AppBar(
      automaticallyImplyLeading: false,
      leading: AppNavigation.showsLeadingBack(routeName)
          ? BackButton(
              key: const Key('authenticated-leading-back'),
              onPressed: () => AppNavigation.navigateBack(context, routeName),
            )
          : null,
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
          child: _AuthenticatedNavigationStrip(
            items: items,
            routeName: routeName,
          ),
        ),
      ),
    );
  }
}

class _AuthenticatedNavigationStrip extends StatefulWidget {
  const _AuthenticatedNavigationStrip({
    required this.items,
    required this.routeName,
  });

  final List<_NavigationItem> items;
  final String? routeName;

  @override
  State<_AuthenticatedNavigationStrip> createState() =>
      _AuthenticatedNavigationStripState();
}

class _AuthenticatedNavigationStripState
    extends State<_AuthenticatedNavigationStrip> {
  static const _scrollStep = 320.0;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _activeItemKey = GlobalKey();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshScrollState();
      _revealActiveItem();
    });

    return Row(
      children: [
        if (_hasOverflow)
          _NavigationScrollButton(
            key: const Key('top-nav-scroll-left'),
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous modules',
            onPressed: _canScrollBack ? () => _scrollBy(-_scrollStep) : null,
          ),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: _hasOverflow,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in widget.items) ...[
                    KeyedSubtree(
                      key: _isRouteActive(item.route, widget.routeName)
                          ? _activeItemKey
                          : null,
                      child: _NavigationButton(
                        item: item,
                        active: _isRouteActive(item.route, widget.routeName),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (_hasOverflow)
          _NavigationScrollButton(
            key: const Key('top-nav-scroll-right'),
            icon: Icons.chevron_right_rounded,
            tooltip: 'More modules',
            onPressed: _canScrollForward ? () => _scrollBy(_scrollStep) : null,
          ),
      ],
    );
  }

  void _refreshScrollState() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    final hasOverflow = position.maxScrollExtent > 1;
    final canScrollBack = hasOverflow && position.pixels > 1;
    final canScrollForward =
        hasOverflow && position.pixels < position.maxScrollExtent - 1;
    if (_hasOverflow == hasOverflow &&
        _canScrollBack == canScrollBack &&
        _canScrollForward == canScrollForward) {
      return;
    }
    setState(() {
      _hasOverflow = hasOverflow;
      _canScrollBack = canScrollBack;
      _canScrollForward = canScrollForward;
    });
  }

  void _revealActiveItem() {
    if (!_scrollController.hasClients) return;
    if (!_scrollController.position.hasContentDimensions) return;
    final renderObject = _activeItemKey.currentContext?.findRenderObject();
    if (renderObject == null) return;
    _scrollController.position
        .ensureVisible(renderObject, alignment: 0.5)
        .then((_) => _refreshScrollState());
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) {
      return;
    }
    final position = _scrollController.position;
    final target = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _scrollController
        .animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        )
        .then((_) => _refreshScrollState());
  }
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
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon),
    color: Colors.white,
    disabledColor: Colors.white38,
    visualDensity: VisualDensity.compact,
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
    style: TextButton.styleFrom(
      foregroundColor: active ? AppColors.primary : Colors.white,
      backgroundColor: active ? Colors.white : Colors.transparent,
      disabledForegroundColor: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      shape: const StadiumBorder(),
    ),
  );
}
