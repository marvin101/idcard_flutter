import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/design_bindings.dart';
import 'package:idcard_flutter/models/design_render_scene.dart';
import 'package:idcard_flutter/models/school_profile.dart';
import 'package:idcard_flutter/models/student_field.dart';
import 'package:idcard_flutter/services/design_fonts.dart';
import 'package:idcard_flutter/services/pdf_document_renderer.dart';
import 'package:idcard_flutter/widgets/design_document_view.dart';

const student = ApiStudent(
  uuid: 'student',
  sessionUuid: 'session',
  classUuid: 'class',
  sectionUuid: 'section',
  admissionNo: 'A-1',
  fullName: 'Fixture Student',
  bloodGroup: 'B+',
  isActive: true,
  customFields: [
    StudentCustomFieldValue(
      fieldUuid: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      value: 'Blue',
    ),
  ],
);
const school = SchoolProfile(
  uuid: 'school',
  schoolCode: 'FIX',
  schoolName: 'Fixture School',
  isActive: true,
);

DesignDocument loadFixture() {
  final value = jsonDecode(
    File('test/fixtures/designer_v2_complete.json').readAsStringSync(),
  );
  return DesignDocument.fromJson(Map<String, dynamic>.from(value as Map));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(DesignFonts.load);

  test('completion fixture round-trips every stable library element', () {
    final document = loadFixture();
    expect(
      document.elements.map((element) => element.type).toSet(),
      DesignElementType.values.toSet(),
    );
    expect(
      DesignDocument.fromJson(document.toJson()).toJson(),
      document.toJson(),
    );
    final scene = DesignRenderScene(
      document: document,
      bindings: const DesignBindings(student: student, schoolProfile: school),
    );
    expect(
      scene.elements.map((node) => node.element.id),
      document.elements.map((element) => element.id),
    );
    expect(
      scene.elements.firstWhere((node) => node.element.id == 'name').text,
      'FIXTURE STUDENT',
    );
    expect(
      scene.elements.firstWhere((node) => node.element.id == 'custom').text,
      'BLUE',
    );
    expect(
      scene.elements.firstWhere((node) => node.element.id == 'blood').text,
      'B+',
    );
  });

  testWidgets(
    'fixture geometry is identical in Flutter and normalized PDF scene',
    (tester) async {
      final document = loadFixture();
      final scene = DesignRenderScene(
        document: document,
        bindings: const DesignBindings(student: student, schoolProfile: school),
      );
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: DesignDocumentView(
            document: document,
            student: student,
            schoolProfile: school,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final surface = find.byKey(const Key('design-document-surface'));
      final origin = tester.getTopLeft(surface);
      final scale = tester.getSize(surface).width / document.canvas.width;
    final fonts = (await tester.runAsync(() => DesignFonts.pdfFonts()))!;
      final pdfRenderer = PdfDocumentRenderer(fonts, const {});
      for (final node in scene.elements) {
        final target = find.byKey(Key('design-element-${node.element.id}'));
        final rect = tester.getRect(target);
        expect(
          (rect.left - origin.dx) / scale,
          closeTo(node.element.x, 0.000001),
        );
        expect(
          (rect.top - origin.dy) / scale,
          closeTo(node.element.y, 0.000001),
        );
        expect(rect.width / scale, closeTo(node.element.width, 0.000001));
        expect(rect.height / scale, closeTo(node.element.height, 0.000001));
        expect(() => pdfRenderer.element(node), returnsNormally);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
