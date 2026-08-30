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
  _FakeAuthProvider._(this.role, _FakeApi api) : super(api: api);

  factory _FakeAuthProvider(String role) =>
      _FakeAuthProvider._(role, _FakeApi());

  final String role;

  static const school = SchoolSummary(
    uuid: 'school-1',
    code: 'SCH',
    name: 'Test School',
    isActive: true,
  );

  @override
  bool get loading => false;

  @override
  bool get isAuthenticated => true;

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
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    final auth = _FakeAuthProvider(role);
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

    await tester.tap(find.byKey(const Key('top-nav-/students/import')));
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
}
