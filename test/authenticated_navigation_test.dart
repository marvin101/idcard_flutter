import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/app_routes.dart';
import 'package:idcard_flutter/main.dart';
import 'package:idcard_flutter/models/academic_session.dart';
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/auth_models.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/school_class.dart';
import 'package:idcard_flutter/models/school_profile.dart';
import 'package:idcard_flutter/models/section.dart';
import 'package:idcard_flutter/models/student_field.dart';
import 'package:idcard_flutter/navigation/app_navigation.dart';
import 'package:idcard_flutter/navigation/app_router.dart';
import 'package:idcard_flutter/providers/auth_provider.dart';
import 'package:idcard_flutter/screens/student_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';

class _FakeApi extends ApiService {
  @override
  Future<List<AcademicSession>> getAcademicSessions(String schoolUuid) async =>
      const [];

  @override
  Future<List<SchoolClass>> getClasses(String schoolUuid) async => const [];

  @override
  Future<List<SchoolSection>> getSections({
    required String schoolUuid,
    required String classUuid,
  }) async => const [];

  @override
  Future<List<ApiStudent>> getStudents({
    required String schoolUuid,
    String? admissionNo,
    String? sessionUuid,
    String? classUuid,
    String? sectionUuid,
  }) async => const [];

  @override
  Future<ApiStudentPage> getStudentsPage({
    required String schoolUuid,
    int limit = 100,
    int offset = 0,
    String? search,
    String? sessionUuid,
    String? classUuid,
    String? sectionUuid,
    DateTime? createdFrom,
    DateTime? createdTo,
  }) async => ApiStudentPage(
    items: const [],
    total: 0,
    offset: offset,
    limit: limit,
    hasMore: false,
  );

  @override
  Future<List<StudentFieldDefinition>> getStudentFields(
    String schoolUuid, {
    bool includeInactive = false,
  }) async => const [];

  @override
  Future<CardTemplate> getCardTemplate(String schoolUuid) async =>
      CardTemplate.uploadedDesign;

  @override
  Future<SchoolProfile> getSchoolProfile(String schoolUuid) async =>
      const SchoolProfile(
        uuid: 'school-1',
        schoolCode: 'SCH',
        schoolName: 'Test School',
        isActive: true,
      );
}

class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider._(this.role, this._authenticated, _FakeApi api)
    : super(api: api);

  factory _FakeAuthProvider(String role, {bool authenticated = true}) =>
      _FakeAuthProvider._(role, authenticated, _FakeApi());

  final String role;
  bool _authenticated;

  static const school = SchoolSummary(
    uuid: 'school-1',
    code: 'SCH',
    name: 'Test School',
    isActive: true,
  );

  @override
  bool get loading => false;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  Future<void> login(String username, String password) async {
    _authenticated = true;
    notifyListeners();
  }

  @override
  bool get isPlatformAdmin => role == 'platform_admin';

  @override
  AuthUser get user => AuthUser(
    uuid: 'user-1',
    username: 'admin',
    fullName: 'Test Admin',
    platformRole: isPlatformAdmin ? 'platform_admin' : null,
    isPlatformAdmin: isPlatformAdmin,
    isActive: true,
  );

  @override
  SchoolSummary get selectedSchool => school;

  @override
  List<SchoolSummary> get schools => const [school];

  @override
  SchoolAccess get selectedSchoolAccess => SchoolAccess(
    schoolUuid: school.uuid,
    schoolName: school.name,
    role: role,
  );
}

void main() {
  Future<_FakeAuthProvider> pumpApp(
    WidgetTester tester, {
    String initialRoute = AppRoutes.dashboard,
    String role = 'school_admin',
    bool authenticated = true,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final auth = _FakeAuthProvider(role, authenticated: authenticated);
    await tester.pumpWidget(
      MyApp(authProvider: auth, initialRoute: initialRoute),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('Dashboard to Students changes the named route', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('top-nav-/students')));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(StudentsScreen));
    expect(ModalRoute.of(context)?.settings.name, AppRoutes.students);
  });

  testWidgets('Students routes to fields and bulk import URLs', (tester) async {
    await pumpApp(tester, initialRoute: AppRoutes.students);

    await tester.tap(find.byKey(const Key('top-nav-/students/fields')));
    await tester.pumpAndSettle();
    expect(
      ModalRoute.of(
        tester.element(find.text('Student Fields').last),
      )?.settings.name,
      AppRoutes.studentFields,
    );

    await pumpApp(tester, initialRoute: AppRoutes.students);
    await tester.tap(find.text('Bulk Import'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bulk Student Import'), findsWidgets);
    expect(
      ModalRoute.of(
        tester.element(find.textContaining('Bulk Student Import').first),
      )?.settings.name,
      AppRoutes.studentImport,
    );
  });

  testWidgets('Design and Cards named routes resolve', (tester) async {
    await pumpApp(tester, initialRoute: AppRoutes.design);
    expect(find.text('Card designer'), findsWidgets);
    expect(
      ModalRoute.of(
        tester.element(find.text('Card designer').first),
      )?.settings.name,
      AppRoutes.design,
    );

    final cards = find.byKey(const Key('top-nav-/cards'));
    await tester.ensureVisible(cards);
    await tester.tap(cards);
    await tester.pumpAndSettle();
    expect(find.textContaining('ID Cards'), findsWidgets);
    expect(
      ModalRoute.of(
        tester.element(find.textContaining('ID Cards').first),
      )?.settings.name,
      AppRoutes.cards,
    );
  });

  testWidgets('persistent top navigation appears across protected modules', (
    tester,
  ) async {
    for (final route in [
      AppRoutes.students,
      AppRoutes.studentFields,
      AppRoutes.studentImport,
      AppRoutes.schoolProfile,
      AppRoutes.design,
      AppRoutes.cards,
    ]) {
      await pumpApp(tester, initialRoute: route);
      expect(
        find.byKey(const Key('authenticated-sign-out')),
        findsOneWidget,
        reason: 'missing authenticated navigation on $route',
      );
      expect(find.byKey(const Key('top-nav-/dashboard')), findsOneWidget);
    }
  });

  testWidgets(
    'narrow desktop navigation exposes overflow controls and active module',
    (tester) async {
      tester.view.physicalSize = const Size(960, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpApp(tester, initialRoute: AppRoutes.users);

      expect(find.byKey(const Key('top-nav-scroll-left')), findsOneWidget);
      expect(find.byKey(const Key('top-nav-scroll-right')), findsOneWidget);
      expect(
        find.byKey(const Key('top-nav-/users')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('top-nav-/cards')).hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets('active module is highlighted and selected school survives', (
    tester,
  ) async {
    final auth = await pumpApp(tester, initialRoute: AppRoutes.students);
    final selectedBefore = auth.selectedSchool;

    final active = tester.widget<TextButton>(
      find.byKey(const Key('top-nav-/students')),
    );
    expect(active.onPressed, isNull);

    final cards = find.byKey(const Key('top-nav-/cards'));
    await tester.ensureVisible(cards);
    await tester.tap(cards);
    await tester.pumpAndSettle();
    expect(identical(auth.selectedSchool, selectedBefore), isTrue);
  });

  testWidgets('unauthorized modules are hidden', (tester) async {
    await pumpApp(tester, role: 'card_operator');

    expect(find.byKey(const Key('top-nav-/students')), findsOneWidget);
    expect(find.byKey(const Key('top-nav-/cards')), findsOneWidget);
    expect(find.byKey(const Key('top-nav-/users')), findsNothing);
    expect(find.byKey(const Key('top-nav-/students/fields')), findsNothing);
    expect(find.byKey(const Key('top-nav-/design')), findsNothing);
  });

  testWidgets('authenticated direct link restores the requested module', (
    tester,
  ) async {
    await pumpApp(tester, initialRoute: AppRoutes.studentFields);
    expect(find.text('Student Fields'), findsWidgets);
    final active = tester.widget<TextButton>(
      find.byKey(const Key('top-nav-/students/fields')),
    );
    expect(active.onPressed, isNull);
  });

  test('Dashboard and Students are the only arrow-free modules', () {
    for (final route in [AppRoutes.dashboard, AppRoutes.students]) {
      expect(AppNavigation.showsLeadingBack(route), isFalse);
    }

    for (final route in [
      AppRoutes.studentFields,
      AppRoutes.schoolProfile,
      AppRoutes.academicSessions,
      AppRoutes.classesSections,
      AppRoutes.users,
      AppRoutes.design,
      AppRoutes.cards,
    ]) {
      expect(AppNavigation.showsLeadingBack(route), isTrue);
    }
  });

  testWidgets('student workflows show Back and return to Students', (
    tester,
  ) async {
    await pumpApp(tester, initialRoute: AppRoutes.students);
    final add = find.byKey(const Key('top-nav-/students/add'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text('Add student'), findsWidgets);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(StudentsScreen), findsOneWidget);

    const student = ApiStudent(
      uuid: 'student-1',
      sessionUuid: 'session-1',
      classUuid: 'class-1',
      sectionUuid: 'section-1',
      admissionNo: 'A-1',
      fullName: 'Test Student',
      isActive: true,
    );
    final editResult = AppNavigation.navigateToWorkflow<void>(
      tester.element(find.byType(StudentsScreen)),
      AppRoutes.editStudent,
      arguments: student,
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit student'), findsWidgets);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await editResult;
    expect(find.byType(StudentsScreen), findsOneWidget);

    await tester.tap(find.text('Bulk Import'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bulk Student Import'), findsWidgets);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(StudentsScreen), findsOneWidget);
  });

  testWidgets('primary module switching replaces instead of stacking routes', (
    tester,
  ) async {
    await pumpApp(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);

    await tester.tap(find.byKey(const Key('top-nav-/students')));
    await tester.pumpAndSettle();
    expect(find.byType(StudentsScreen), findsOneWidget);
    expect(navigator.canPop(), isFalse);

    final cards = find.byKey(const Key('top-nav-/cards'));
    await tester.ensureVisible(cards);
    await tester.tap(cards);
    await tester.pumpAndSettle();
    expect(find.textContaining('ID Cards'), findsWidgets);
    expect(navigator.canPop(), isFalse);
    expect(
      ModalRoute.of(
        tester.element(find.textContaining('ID Cards').first),
      )?.settings.name,
      AppRoutes.cards,
    );
  });

  testWidgets('login makes Dashboard the only authenticated root', (
    tester,
  ) async {
    await pumpApp(
      tester,
      initialRoute: AppRoutes.landing,
      authenticated: false,
    );

    await tester.tap(find.text('Sign in').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.byType(BackButton), findsNothing);
    expect(navigator.canPop(), isFalse);
    expect(
      ModalRoute.of(
        tester.element(find.text('Dashboard').first),
      )?.settings.name,
      AppRoutes.dashboard,
    );
  });

  testWidgets('platform route changes update both URL state and visible page', (
    tester,
  ) async {
    await pumpApp(tester, initialRoute: AppRoutes.dashboard);
    final router = Router.of<Object>(
      tester.element(find.text('Dashboard').first),
    );
    final delegate = router.routerDelegate as AppRouterDelegate;

    await delegate.setNewRoutePath(const AppRouteState(AppRoutes.students));
    await tester.pumpAndSettle();
    expect(find.byType(StudentsScreen), findsOneWidget);
    expect(delegate.currentConfiguration?.location, AppRoutes.students);
    expect(
      ModalRoute.of(tester.element(find.byType(StudentsScreen)))?.settings.name,
      AppRoutes.students,
    );

    await delegate.setNewRoutePath(const AppRouteState(AppRoutes.dashboard));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.byType(StudentsScreen), findsNothing);
    expect(delegate.currentConfiguration?.location, AppRoutes.dashboard);
  });
}
