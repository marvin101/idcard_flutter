import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/app_routes.dart';
import 'package:idcard_flutter/models/public_form.dart';
import 'package:idcard_flutter/navigation/authenticated_modules.dart';
import 'package:idcard_flutter/screens/public_student_form_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/widgets/authenticated_shell.dart';
import 'package:image_picker/image_picker.dart';

class _FakePhoto extends XFile {
  _FakePhoto() : super('student.jpg');

  @override
  Future<int> length() async => 3;
}

class _FakeApi extends ApiService {
  _FakeApi(this.form, {this.failure});
  final PublicFormView form;
  final Object? failure;
  Map<String, dynamic>? submitted;
  XFile? submittedPhoto;
  int submitCalls = 0;

  @override
  Future<PublicFormView> getPublicForm(String token) async {
    if (failure != null) throw failure!;
    return form;
  }

  @override
  Future<String> submitPublicForm({
    required String token,
    required Map<String, dynamic> studentData,
    XFile? photo,
  }) async {
    submitCalls += 1;
    if (failure != null) throw failure!;
    submitted = studentData;
    submittedPhoto = photo;
    return 'Submitted successfully.';
  }
}

const _fields = [
  PublicFormField(
    key: 'full_name',
    label: 'Full name',
    dataType: 'text',
    required: true,
    kind: 'system',
  ),
  PublicFormField(
    key: 'bio',
    label: 'About student',
    dataType: 'multiline',
    required: false,
    kind: 'custom',
    fieldUuid: 'field-bio',
  ),
  PublicFormField(
    key: 'score',
    label: 'Score',
    dataType: 'number',
    required: false,
    kind: 'custom',
    fieldUuid: 'field-score',
  ),
  PublicFormField(
    key: 'joined',
    label: 'Joined',
    dataType: 'date',
    required: false,
    kind: 'custom',
    fieldUuid: 'field-joined',
  ),
  PublicFormField(
    key: 'guardian_phone',
    label: 'Guardian phone',
    dataType: 'phone',
    required: false,
    kind: 'custom',
    fieldUuid: 'field-phone',
  ),
];

const _view = PublicFormView(
  schoolName: 'Campus School',
  title: 'Student details',
  instructions: 'Complete this form.',
  fields: _fields,
  allowPhoto: true,
  photoRequired: false,
  maxPhotoSizeBytes: 5242880,
);

const _requiredPhotoView = PublicFormView(
  schoolName: 'Campus School',
  title: 'Student details',
  instructions: 'Complete this form.',
  fields: _fields,
  allowPhoto: true,
  photoRequired: true,
  maxPhotoSizeBytes: 5242880,
);

void main() {
  test('public form route is unauthenticated and outside protected routes', () {
    final route = AppRoutes.publicForm('opaque_token');
    expect(AppRoutes.isPublicForm(route), isTrue);
    expect(AppRoutes.publicFormToken(route), 'opaque_token');
    expect(AppRoutes.isProtected(route), isFalse);
  });

  test('Public Forms module is restricted to administrators', () {
    for (final role in ['school_admin', 'admin']) {
      expect(
        dashboardModulesFor(
          isPlatformAdmin: false,
          schoolRole: role,
          hasSelectedSchool: true,
        ),
        contains(DashboardModuleKind.publicForms),
      );
    }
    expect(
      dashboardModulesFor(
        isPlatformAdmin: true,
        schoolRole: null,
        hasSelectedSchool: true,
      ),
      contains(DashboardModuleKind.publicForms),
    );
    for (final role in ['card_operator', 'teacher', 'staff']) {
      expect(
        dashboardModulesFor(
          isPlatformAdmin: false,
          schoolRole: role,
          hasSelectedSchool: true,
        ),
        isNot(contains(DashboardModuleKind.publicForms)),
      );
    }
  });

  testWidgets(
    'public page renders all supported field types and photo picker',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PublicStudentFormScreen(token: 'token', api: _FakeApi(_view)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AuthenticatedShell), findsNothing);
      for (final key in [
        'full_name',
        'bio',
        'score',
        'joined',
        'guardian_phone',
      ]) {
        expect(find.byKey(Key('public-field-$key')), findsOneWidget);
      }
      expect(find.byKey(const Key('public-photo-picker')), findsOneWidget);
    },
  );

  testWidgets('required validation prevents an empty submission', (
    tester,
  ) async {
    final api = _FakeApi(_view);
    await tester.pumpWidget(
      MaterialApp(
        home: PublicStudentFormScreen(token: 'token', api: api),
      ),
    );
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('submit-public-form'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Full name is required'), findsOneWidget);
    expect(api.submitted, isNull);
  });

  testWidgets('required photo is visibly marked', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PublicStudentFormScreen(
          token: 'token',
          api: _FakeApi(_requiredPhotoView),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choose student photo *'), findsOneWidget);
  });

  testWidgets('missing required photo blocks API submission', (tester) async {
    final api = _FakeApi(_requiredPhotoView);
    await tester.pumpWidget(
      MaterialApp(
        home: PublicStudentFormScreen(token: 'token', api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('public-field-full_name')),
      'Student One',
    );
    final submit = find.byKey(const Key('submit-public-form'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Photo is required.'), findsOneWidget);
    expect(api.submitCalls, 0);
  });

  testWidgets('selected required photo allows submission', (tester) async {
    final api = _FakeApi(_requiredPhotoView);
    final photo = _FakePhoto();
    await tester.pumpWidget(
      MaterialApp(
        home: PublicStudentFormScreen(
          token: 'token',
          api: api,
          pickPhoto: () async => photo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('public-field-full_name')),
      'Student One',
    );
    final picker = find.byKey(const Key('public-photo-picker'));
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    final pickPhoto = tester.widget<OutlinedButton>(picker).onPressed!;
    await tester.runAsync(() async {
      await (pickPhoto as dynamic)();
    });
    await tester.pumpAndSettle();
    expect(find.text('student.jpg'), findsOneWidget);
    final submit = find.byKey(const Key('submit-public-form'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(api.submitCalls, 1);
    expect(api.submittedPhoto?.name, 'student.jpg');
    expect(find.text('Submitted successfully.'), findsOneWidget);
  });

  testWidgets(
    'successful submission sends configured values and shows success',
    (tester) async {
      final api = _FakeApi(_view);
      await tester.pumpWidget(
        MaterialApp(
          home: PublicStudentFormScreen(token: 'token', api: api),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('public-field-full_name')),
        'Student One',
      );
      final submit = find.byKey(const Key('submit-public-form'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.submitted?['full_name'], 'Student One');
      expect(api.submitCalls, 1);
      expect(api.submittedPhoto, isNull);
      expect(api.submitted?['custom_fields'], isEmpty);
      expect(find.text('Submitted successfully.'), findsOneWidget);
      expect(find.textContaining('Pending review'), findsOneWidget);
    },
  );

  testWidgets('inactive or missing form has a safe unavailable state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PublicStudentFormScreen(
          token: 'bad',
          api: _FakeApi(_view, failure: const ApiException(404, 'Not found')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This form is unavailable.'), findsOneWidget);
    expect(find.byKey(const Key('submit-public-form')), findsNothing);
  });
}
