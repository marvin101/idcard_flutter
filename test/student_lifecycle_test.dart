import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/app_routes.dart';
import 'package:idcard_flutter/models/academic_session.dart';
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/school_class.dart';
import 'package:idcard_flutter/screens/cards_screen.dart';
import 'package:idcard_flutter/screens/student_history_screen.dart';
import 'package:idcard_flutter/screens/student_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/widgets/student_lifecycle_badge.dart';

ApiStudent _student({
  String status = 'pending',
  String lifecycle = 'pending',
  int printCount = 0,
}) => ApiStudent(
  uuid: 'student-1',
  sessionUuid: 'session-1',
  classUuid: 'class-1',
  sectionUuid: 'section-1',
  admissionNo: 'A-1',
  fullName: 'Asha Singh',
  isActive: true,
  verificationStatus: status,
  lifecycleStatus: lifecycle,
  printCount: printCount,
  verifiedAt: status == 'verified' ? DateTime.utc(2026, 9, 1, 8) : null,
  verifiedByName: status == 'verified' ? 'School Admin' : null,
  printedAt: printCount > 0 ? DateTime.utc(2026, 9, 1, 9) : null,
);

class _LifecycleApi extends ApiService {
  _LifecycleApi({ApiStudent? student}) : student = student ?? _student();

  ApiStudent student;
  int verifyCalls = 0;
  int correctionCalls = 0;
  int printCalls = 0;

  @override
  Future<List<AcademicSession>> getAcademicSessions(String schoolUuid) async =>
      const [];

  @override
  Future<List<SchoolClass>> getClasses(String schoolUuid) async => const [];

  @override
  Future<List<ApiStudent>> getStudents({
    required String schoolUuid,
    String? admissionNo,
    String? sessionUuid,
    String? classUuid,
    String? sectionUuid,
    String? verificationStatus,
    bool? printed,
  }) async => [student];

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
    String? verificationStatus,
    bool? printed,
  }) async => ApiStudentPage(
    items: [student],
    total: 1,
    offset: offset,
    limit: limit,
    hasMore: false,
  );

  @override
  Future<CardTemplate> getCardTemplate(String schoolUuid) async =>
      CardTemplate.uploadedDesign;

  @override
  Future<ApiStudent> updateStudentVerification({
    required String schoolUuid,
    required String studentUuid,
    required String status,
    String? note,
  }) async {
    if (status == 'verified') verifyCalls++;
    if (status == 'needs_correction') correctionCalls++;
    return student;
  }

  @override
  Future<ApiStudent> markStudentPrinted({
    required String schoolUuid,
    required String studentUuid,
  }) async {
    printCalls++;
    return student;
  }

  @override
  Future<List<StudentAuditEvent>> getStudentHistory({
    required String schoolUuid,
    required String studentUuid,
  }) async => [
    StudentAuditEvent(
      uuid: 'event-1',
      eventType: 'verification_status_changed',
      fieldName: 'verification_status',
      oldValue: 'pending',
      newValue: 'verified',
      note: 'Approved',
      actorName: 'School Admin',
      createdAt: DateTime.utc(2026, 9, 1, 8),
    ),
  ];
}

void main() {
  test('lifecycle model parses verification, actor, and print metadata', () {
    final student = ApiStudent.fromJson({
      'uuid': 'student-1',
      'session_uuid': 'session-1',
      'class_uuid': 'class-1',
      'section_uuid': 'section-1',
      'admission_no': 'A-1',
      'roll_no': null,
      'stream': null,
      'full_name': 'Asha Singh',
      'father_name': null,
      'mother_name': null,
      'dob': null,
      'gender': null,
      'blood_group': null,
      'mobile': null,
      'aadhaar': null,
      'address': null,
      'photo_path': null,
      'is_active': true,
      'verification_status': 'verified',
      'lifecycle_status': 'printed',
      'verified_at': '2026-09-01T08:00:00Z',
      'verified_by_name': 'School Admin',
      'printed_at': '2026-09-01T09:00:00Z',
      'print_count': 2,
    });
    expect(student.isVerified, isTrue);
    expect(student.isPrinted, isTrue);
    expect(student.printCount, 2);
    expect(student.verifiedByName, 'School Admin');
  });

  testWidgets('status badges render all lifecycle labels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Wrap(
          children: [
            StudentLifecycleBadge(status: 'pending'),
            StudentLifecycleBadge(status: 'needs_correction'),
            StudentLifecycleBadge(status: 'verified'),
            StudentLifecycleBadge(status: 'printed'),
          ],
        ),
      ),
    );
    for (final label in [
      'Pending',
      'Needs Correction',
      'Verified',
      'Printed',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets(
    'students expose filters, verify, correction validation, and print',
    (tester) async {
      final api = _LifecycleApi(
        student: _student(status: 'verified', lifecycle: 'ready_for_print'),
      );
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: StudentsScreen(
            schoolUuid: 'school-1',
            schoolName: 'Test School',
            api: api,
            canEdit: false,
            canDelete: false,
            canVerify: true,
            canViewHistory: true,
            canMarkPrinted: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Verification Status'), findsOneWidget);
      expect(find.text('Printed'), findsWidgets);
      expect(find.byType(StudentLifecycleBadge), findsOneWidget);

      await tester.ensureVisible(find.byType(PopupMenuButton<String>));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();
      expect(api.verifyCalls, 1);

      await tester.ensureVisible(find.byType(PopupMenuButton<String>));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Needs Correction'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-correction-note')));
      await tester.pump();
      expect(find.text('Correction note is required'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('correction-note-field')),
        'Retake photo',
      );
      await tester.tap(find.byKey(const Key('save-correction-note')));
      await tester.pumpAndSettle();
      expect(api.correctionCalls, 1);

      await tester.ensureVisible(find.byType(PopupMenuButton<String>));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark Printed'));
      await tester.pumpAndSettle();
      expect(api.printCalls, 1);
    },
  );

  testWidgets('history renders newest-first event details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentHistoryScreen(
          schoolUuid: 'school-1',
          studentUuid: 'student-1',
          api: _LifecycleApi(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('student-history-timeline')), findsOneWidget);
    expect(find.text('Verification Status Changed'), findsOneWidget);
    expect(find.textContaining('pending → verified'), findsOneWidget);
    expect(find.textContaining('School Admin'), findsOneWidget);
    expect(find.text('Note: Approved'), findsOneWidget);
  });

  test('history route is meaningful and round-trips the student UUID', () {
    final route = AppRoutes.studentHistory('student-1');
    expect(route, '/students/student-1/history');
    expect(AppRoutes.isProtected(route), isTrue);
    expect(AppRoutes.studentUuidFromHistory(route), 'student-1');
  });

  testWidgets(
    'cards show lifecycle filters and explicit mark printed control',
    (tester) async {
      final api = _LifecycleApi(
        student: _student(status: 'verified', lifecycle: 'ready_for_print'),
      );
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: CardsScreen(
            schoolUuid: 'school-1',
            schoolName: 'Test School',
            api: api,
            canEdit: false,
            canDesign: false,
            canPrint: false,
            canVerify: true,
            canMarkPrinted: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Verification'), findsOneWidget);
      expect(find.text('Not Printed'), findsNothing);
      expect(find.byType(StudentLifecycleBadge), findsOneWidget);
      final mark = find.byKey(const Key('mark-printed-student-1'));
      expect(mark, findsOneWidget);
      await tester.tap(mark);
      await tester.pumpAndSettle();
      expect(api.printCalls, 1);
    },
  );
}
