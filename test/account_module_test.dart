import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/app_routes.dart';
import 'package:idcard_flutter/main.dart';
import 'package:idcard_flutter/models/auth_models.dart';
import 'package:idcard_flutter/providers/auth_provider.dart';
import 'package:idcard_flutter/screens/account_screen.dart';
import 'package:idcard_flutter/screens/login_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';

class _AccountApi extends ApiService {
  String? currentPassword;
  String? newPassword;
  ApiException? passwordError;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (passwordError != null) throw passwordError!;
    this.currentPassword = currentPassword;
    this.newPassword = newPassword;
  }

  @override
  Future<void> revokeSession() async {}
}

class _AccountAuthProvider extends AuthProvider {
  _AccountAuthProvider(this.accountApi, {this.hasSchool = true})
    : _user = AuthUser(
        uuid: 'user-1',
        username: 'test.user',
        fullName: 'Test User',
        email: 'test@example.com',
        mobile: '+91 98765 43210',
        designation: 'Teacher',
        isPlatformAdmin: false,
        isActive: true,
        createdAt: DateTime.utc(2025, 1, 2),
        lastLogin: DateTime.utc(2026, 9, 22, 8, 30),
        schoolContexts: const [
          ProfileSchoolContext(
            schoolUuid: 'school-1',
            schoolName: 'Test School',
            role: 'teacher',
          ),
        ],
      ),
      super(api: accountApi);

  final _AccountApi accountApi;
  final bool hasSchool;
  AuthUser _user;
  bool authenticated = true;
  ApiException? profileError;

  @override
  bool get loading => false;

  @override
  bool get isAuthenticated => authenticated;

  @override
  AuthUser get user => _user;

  @override
  SchoolSummary? get selectedSchool => hasSchool
      ? const SchoolSummary(
          uuid: 'school-1',
          code: 'SCH',
          name: 'Test School',
          isActive: true,
        )
      : null;

  @override
  SchoolAccess? get selectedSchoolAccess => hasSchool
      ? const SchoolAccess(
          schoolUuid: 'school-1',
          schoolName: 'Test School',
          role: 'teacher',
        )
      : null;

  @override
  Future<AuthUser> updateSelfProfile({
    required String fullName,
    String? mobile,
  }) async {
    if (profileError != null) throw profileError!;
    _user = AuthUser(
      uuid: _user.uuid,
      username: _user.username,
      fullName: fullName.trim(),
      email: _user.email,
      mobile: mobile?.trim(),
      designation: _user.designation,
      platformRole: _user.platformRole,
      profilePhotoUrl: _user.profilePhotoUrl,
      lastLogin: _user.lastLogin,
      createdAt: _user.createdAt,
      updatedAt: DateTime.now(),
      schoolContexts: _user.schoolContexts,
      isPlatformAdmin: _user.isPlatformAdmin,
      isActive: _user.isActive,
    );
    notifyListeners();
    return _user;
  }

  @override
  Future<void> logout({bool notify = true}) async {
    authenticated = false;
    if (notify) notifyListeners();
  }
}

Future<_AccountAuthProvider> _pumpAccount(
  WidgetTester tester, {
  String route = AppRoutes.accountProfile,
  bool hasSchool = true,
}) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = _AccountAuthProvider(_AccountApi(), hasSchool: hasSchool);
  await tester.pumpWidget(MyApp(authProvider: provider, initialRoute: route));
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  test('initials are stable for multi-part and single-part names', () {
    const multi = AuthUser(
      uuid: '1',
      username: 'user',
      fullName: 'Ada Lovelace',
      isPlatformAdmin: false,
      isActive: true,
    );
    const single = AuthUser(
      uuid: '2',
      username: 'grace',
      fullName: 'Grace',
      isPlatformAdmin: false,
      isActive: true,
    );
    expect(multi.initials, 'AL');
    expect(single.initials, 'G');
  });

  testWidgets('profile direct route renders global account without school', (
    tester,
  ) async {
    await _pumpAccount(tester, hasSchool: false);

    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.byKey(const Key('profile-avatar-initials')), findsOneWidget);
    expect(find.text('TU'), findsWidgets);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
    expect(find.byKey(const Key('account-avatar-menu')), findsOneWidget);
  });

  testWidgets('profile saves editable name and phone', (tester) async {
    final provider = await _pumpAccount(tester);
    await tester.enterText(
      find.byKey(const Key('profile-full-name')),
      'Updated User',
    );
    await tester.enterText(
      find.byKey(const Key('profile-phone')),
      '+1 202 555 0199',
    );
    await tester.ensureVisible(find.byKey(const Key('profile-save')));
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();

    expect(provider.user.fullName, 'Updated User');
    expect(provider.user.mobile, '+1 202 555 0199');
    expect(find.text('Profile updated.'), findsOneWidget);
  });

  testWidgets('profile leaves email and role read-only and reports errors', (
    tester,
  ) async {
    final provider = await _pumpAccount(tester);
    provider.profileError = const ApiException(
      503,
      'Profile service unavailable.',
    );

    final email = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('profile-email')),
        matching: find.byType(EditableText),
      ),
    );
    final role = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('profile-role')),
        matching: find.byType(EditableText),
      ),
    );
    expect(email.readOnly, isTrue);
    expect(role.readOnly, isTrue);

    await tester.ensureVisible(find.byKey(const Key('profile-save')));
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();
    expect(find.text('Profile service unavailable.'), findsOneWidget);
  });

  testWidgets('security form validates confirmation and password length', (
    tester,
  ) async {
    await _pumpAccount(tester, route: AppRoutes.accountSecurity);
    await tester.enterText(
      find.byKey(const Key('current-password')),
      'old-password',
    );
    await tester.enterText(find.byKey(const Key('new-password')), 'short');
    await tester.enterText(
      find.byKey(const Key('confirm-password')),
      'different',
    );
    await tester.tap(find.byKey(const Key('change-password-submit')));
    await tester.pump();

    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('security shows incorrect-current-password API error', (
    tester,
  ) async {
    final provider = await _pumpAccount(
      tester,
      route: AppRoutes.accountSecurity,
    );
    provider.accountApi.passwordError = const ApiException(
      400,
      'Current password is incorrect.',
    );
    await tester.enterText(
      find.byKey(const Key('current-password')),
      'wrong-password',
    );
    await tester.enterText(
      find.byKey(const Key('new-password')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-password')),
      'new-password',
    );
    await tester.tap(find.byKey(const Key('change-password-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Current password is incorrect.'), findsOneWidget);
  });

  testWidgets('security submits and reports successful password change', (
    tester,
  ) async {
    final provider = await _pumpAccount(
      tester,
      route: AppRoutes.accountSecurity,
    );
    await tester.enterText(
      find.byKey(const Key('current-password')),
      'old-password',
    );
    await tester.enterText(
      find.byKey(const Key('new-password')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-password')),
      'new-password',
    );
    await tester.tap(find.byKey(const Key('change-password-submit')));
    await tester.pumpAndSettle();

    expect(provider.accountApi.currentPassword, 'old-password');
    expect(provider.accountApi.newPassword, 'new-password');
    expect(find.text('Password changed successfully.'), findsOneWidget);
  });

  testWidgets('account menu exposes profile security and logout', (
    tester,
  ) async {
    await _pumpAccount(tester);
    await tester.tap(find.byKey(const Key('account-avatar-menu')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-menu-profile')), findsOneWidget);
    expect(find.byKey(const Key('account-menu-security')), findsOneWidget);
    expect(find.byKey(const Key('account-menu-logout')), findsOneWidget);

    await tester.tap(find.byKey(const Key('account-menu-security')));
    await tester.pumpAndSettle();
    expect(find.text('Change password'), findsWidgets);
  });

  testWidgets('existing logout control still signs out', (tester) async {
    await _pumpAccount(tester);
    await tester.tap(find.byKey(const Key('authenticated-sign-out')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('CampusID'), findsWidgets);
  });
}
