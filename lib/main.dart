import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app_routes.dart';
import 'models/api_student.dart';
import 'models/auth_models.dart';
import 'services/api_service.dart';
import 'navigation/app_navigation.dart';
import 'navigation/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/display_scale_provider.dart';
import 'screens/academic_sessions_screen.dart';
import 'screens/bulk_photo_import_screen.dart';
import 'screens/card_designer_route_screen.dart';
import 'screens/cards_screen.dart';
import 'screens/classes_sections_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/public_information_screens.dart';
import 'screens/register_screen.dart';
import 'screens/school_profile_screen.dart';
import 'screens/school_user_assignment_screen.dart';
import 'screens/student_fields_screen.dart';
import 'screens/student_form.dart';
import 'screens/student_import_screen.dart';
import 'screens/student_history_screen.dart';
import 'screens/public_form_management_screen.dart';
import 'screens/public_student_form_screen.dart';
import 'screens/student_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_scale_viewport.dart';
import 'widgets/authenticated_app_bar.dart';
import 'widgets/authenticated_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.authProvider, this.initialRoute});

  final AuthProvider? authProvider;
  final String? initialRoute;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppRouterDelegate _routerDelegate;
  late final PlatformRouteInformationProvider? _routeInformationProvider;

  @override
  void initState() {
    super.initState();
    _routerDelegate = AppRouterDelegate(_buildRouteWidget);
    _routeInformationProvider = widget.initialRoute == null
        ? null
        : PlatformRouteInformationProvider(
            initialRouteInformation: RouteInformation(
              uri: Uri.parse(widget.initialRoute!),
            ),
          );
  }

  @override
  void dispose() {
    _routeInformationProvider?.dispose();
    _routerDelegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        if (widget.authProvider == null)
          ChangeNotifierProvider(create: (_) => AuthProvider()..initialize())
        else
          ChangeNotifierProvider<AuthProvider>.value(
            value: widget.authProvider!,
          ),
        ChangeNotifierProvider(create: (_) => DisplayScaleProvider()),
      ],
      child: MaterialApp.router(
        title: 'CampusID',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routeInformationProvider: _routeInformationProvider,
        routeInformationParser: const AppRouteInformationParser(),
        routerDelegate: _routerDelegate,
        builder: (context, child) =>
            AppScaleViewport(child: child ?? const SizedBox.shrink()),
      ),
    );
  }

  Widget _buildRouteWidget(String routeName, Object? arguments) {
    return switch (routeName) {
      AppRoutes.landing => const LandingScreen(),
      AppRoutes.privacy => const PrivacyScreen(),
      AppRoutes.terms => const TermsScreen(),
      AppRoutes.support => const SupportScreen(),
      AppRoutes.signIn => const _PublicAuthRoute(
        unauthenticated: LoginScreen(),
      ),
      AppRoutes.register => _RegisterRoute(),
      _ when AppRoutes.isPublicForm(routeName) => PublicStudentFormScreen(
        token: AppRoutes.publicFormToken(routeName)!,
        api: ApiService(),
      ),
      _ when AppRoutes.isProtected(routeName) => _AuthenticatedRoute(
        routeName: routeName,
        arguments: arguments,
      ),
      _ => const LandingScreen(),
    };
  }
}

class _RegisterRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      _PublicAuthRoute(unauthenticated: RegisterScreen(api: ApiService()));
}

class _PublicAuthRoute extends StatelessWidget {
  const _PublicAuthRoute({required this.unauthenticated});

  final Widget unauthenticated;

  @override
  Widget build(BuildContext context) {
    final state = context.select<AuthProvider, (bool, bool)>(
      (auth) => (auth.loading, auth.isAuthenticated),
    );
    if (state.$1) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.$2) {
      return const _AuthenticatedRootRedirect();
    }
    return unauthenticated;
  }
}

class _AuthenticatedRoute extends StatelessWidget {
  const _AuthenticatedRoute({required this.routeName, required this.arguments});

  final String routeName;
  final Object? arguments;

  @override
  Widget build(BuildContext context) {
    final authState = context.select<AuthProvider, _AuthenticatedRouteState>(
      _AuthenticatedRouteState.from,
    );
    if (authState.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!authState.isAuthenticated) return const LoginScreen();
    if (routeName == AppRoutes.dashboard) {
      return const AuthenticatedShell(child: DashboardScreen());
    }

    final school = authState.selectedSchool;
    if (school == null) {
      return const _AuthenticatedRootRedirect();
    }

    final auth = context.read<AuthProvider>();

    final modules = dashboardModulesFor(
      isPlatformAdmin: authState.isPlatformAdmin,
      schoolRole: authState.schoolRole,
      hasSelectedSchool: true,
    );
    bool has(DashboardModuleKind module) => modules.contains(module);

    final page = switch (routeName) {
      AppRoutes.students when has(DashboardModuleKind.students) =>
        StudentsScreen(
          schoolUuid: school.uuid,
          schoolName: school.name,
          api: auth.api,
          canEdit: auth.canManageCardData,
          canDelete: auth.canDeleteStudents,
          canVerify: auth.canVerifyStudents,
          canViewHistory: auth.canViewStudentHistory,
          canMarkPrinted: auth.canMarkStudentsPrinted,
        ),
      AppRoutes.addStudent
          when has(DashboardModuleKind.students) && auth.canManageCardData =>
        StudentFormScreen(schoolUuid: school.uuid, api: auth.api),
      AppRoutes.editStudent
          when has(DashboardModuleKind.students) &&
              auth.canManageCardData &&
              arguments is ApiStudent =>
        StudentFormScreen(
          schoolUuid: school.uuid,
          api: auth.api,
          student: arguments as ApiStudent,
        ),
      AppRoutes.studentFields when has(DashboardModuleKind.studentFields) =>
        StudentFieldsScreen(
          schoolUuid: school.uuid,
          schoolName: school.name,
          api: auth.api,
        ),
      AppRoutes.publicForms when has(DashboardModuleKind.publicForms) =>
        PublicFormManagementScreen(
          schoolUuid: school.uuid,
          schoolName: school.name,
          api: auth.api,
        ),
      AppRoutes.studentImport
          when has(DashboardModuleKind.students) && auth.canManageCardData =>
        StudentImportScreen(
          schoolUuid: school.uuid,
          schoolName: school.name,
          api: auth.api,
        ),
      AppRoutes.bulkPhotoImport
          when has(DashboardModuleKind.students) && auth.canManageCardData =>
        BulkPhotoImportScreen(
          schoolUuid: school.uuid,
          schoolName: school.name,
          api: auth.api,
        ),
      AppRoutes.schoolProfile when has(DashboardModuleKind.schoolProfile) =>
        SchoolProfileScreen(
          schoolUuid: school.uuid,
          schoolName: school.name,
          api: auth.api,
          canEdit: auth.canManageSchoolProfile,
          onSaved: auth.applySchoolProfile,
        ),
      AppRoutes.academicSessions
          when has(DashboardModuleKind.academicSessions) =>
        AcademicSessionsScreen(
          schoolUuid: school.uuid,
          schoolName: school.name,
          api: auth.api,
          canManage: auth.canManageAcademicSessions,
        ),
      AppRoutes.classesSections
          when has(DashboardModuleKind.classesAndSections) =>
        ClassesSectionsScreen(
          schoolUuid: school.uuid,
          schoolName: school.name,
          api: auth.api,
          canManage: auth.canManageClasses,
        ),
      AppRoutes.users when has(DashboardModuleKind.users) =>
        SchoolUserAssignmentScreen(
          schoolUuid: school.uuid,
          schoolName: school.name,
          api: auth.api,
          canManageElevatedRoles: auth.isPlatformAdmin,
        ),
      AppRoutes.design when auth.canDesignCards =>
        const CardDesignerRouteScreen(),
      AppRoutes.cards when has(DashboardModuleKind.idCards) => CardsScreen(
        schoolUuid: school.uuid,
        schoolName: school.name,
        api: auth.api,
        canEdit: auth.canManageCardData,
        canDesign: auth.canDesignCards,
        canPrint: auth.canPrintCards,
        canVerify: auth.canVerifyStudents,
        canMarkPrinted: auth.canMarkStudentsPrinted,
      ),
      _
          when AppRoutes.isStudentHistory(routeName) &&
              auth.canViewStudentHistory =>
        StudentHistoryScreen(
          schoolUuid: school.uuid,
          studentUuid: AppRoutes.studentUuidFromHistory(routeName)!,
          api: auth.api,
        ),
      AppRoutes.editStudent => const _ProtectedRouteMessage(
        title: 'Student unavailable',
        message: 'Return to Students and choose a student to edit.',
        icon: Icons.person_search_outlined,
      ),
      _ => const _ProtectedRouteMessage(
        title: 'Access denied',
        message: 'This module is not available for your current school role.',
        icon: Icons.lock_outline,
      ),
    };
    return AuthenticatedShell(child: page);
  }
}

class _AuthenticatedRouteState {
  const _AuthenticatedRouteState({
    required this.loading,
    required this.isAuthenticated,
    required this.selectedSchool,
    required this.isPlatformAdmin,
    required this.schoolRole,
    required this.canManageCardData,
    required this.canDeleteStudents,
    required this.canManageSchoolProfile,
    required this.canManageAcademicSessions,
    required this.canManageClasses,
    required this.canDesignCards,
    required this.canPrintCards,
  });

  factory _AuthenticatedRouteState.from(AuthProvider auth) =>
      _AuthenticatedRouteState(
        loading: auth.loading,
        isAuthenticated: auth.isAuthenticated,
        selectedSchool: auth.selectedSchool,
        isPlatformAdmin: auth.isPlatformAdmin,
        schoolRole: auth.selectedSchoolAccess?.role,
        canManageCardData: auth.canManageCardData,
        canDeleteStudents: auth.canDeleteStudents,
        canManageSchoolProfile: auth.canManageSchoolProfile,
        canManageAcademicSessions: auth.canManageAcademicSessions,
        canManageClasses: auth.canManageClasses,
        canDesignCards: auth.canDesignCards,
        canPrintCards: auth.canPrintCards,
      );

  final bool loading;
  final bool isAuthenticated;
  final SchoolSummary? selectedSchool;
  final bool isPlatformAdmin;
  final String? schoolRole;
  final bool canManageCardData;
  final bool canDeleteStudents;
  final bool canManageSchoolProfile;
  final bool canManageAcademicSessions;
  final bool canManageClasses;
  final bool canDesignCards;
  final bool canPrintCards;

  @override
  bool operator ==(Object other) =>
      other is _AuthenticatedRouteState &&
      other.loading == loading &&
      other.isAuthenticated == isAuthenticated &&
      other.selectedSchool?.uuid == selectedSchool?.uuid &&
      other.selectedSchool?.name == selectedSchool?.name &&
      other.isPlatformAdmin == isPlatformAdmin &&
      other.schoolRole == schoolRole &&
      other.canManageCardData == canManageCardData &&
      other.canDeleteStudents == canDeleteStudents &&
      other.canManageSchoolProfile == canManageSchoolProfile &&
      other.canManageAcademicSessions == canManageAcademicSessions &&
      other.canManageClasses == canManageClasses &&
      other.canDesignCards == canDesignCards &&
      other.canPrintCards == canPrintCards;

  @override
  int get hashCode => Object.hash(
    loading,
    isAuthenticated,
    selectedSchool?.uuid,
    selectedSchool?.name,
    isPlatformAdmin,
    schoolRole,
    canManageCardData,
    canDeleteStudents,
    canManageSchoolProfile,
    canManageAcademicSessions,
    canManageClasses,
    canDesignCards,
    canPrintCards,
  );
}

class _ProtectedRouteMessage extends StatelessWidget {
  const _ProtectedRouteMessage({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AuthenticatedAppBar(title: Text(title)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

class _AuthenticatedRootRedirect extends StatefulWidget {
  const _AuthenticatedRootRedirect();

  @override
  State<_AuthenticatedRootRedirect> createState() =>
      _AuthenticatedRootRedirectState();
}

class _AuthenticatedRootRedirectState
    extends State<_AuthenticatedRootRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppNavigation.resetToAuthenticatedRoot(context);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
