import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/design_bindings.dart';
import 'package:idcard_flutter/models/student_field.dart';

void main() {
  const student = ApiStudent(
    uuid: 'student-1',
    sessionUuid: 'session-1',
    classUuid: 'class-1',
    sectionUuid: 'section-1',
    admissionNo: 'adm-42',
    rollNo: 'r-7',
    stream: 'science',
    fullName: 'Afiya Falak',
    fatherName: 'Wasim Akhtar',
    motherName: 'Nikhat Parween',
    gender: 'female',
    bloodGroup: 'A+',
    mobile: '9876543210',
    aadhaar: '123456789012',
    address: 'Burka Kanke Ranchi',
    isActive: true,
    verificationUrl: 'https://example.test/verify/AbC123xYz',
    customFields: [
      StudentCustomFieldValue(fieldUuid: 'house', value: 'Blue house'),
    ],
  );

  const bindings = DesignBindings(
    student: student,
    sessionName: '2026-2027',
    className: 'Class 8',
    sectionName: 'Section A',
  );

  test('student-bound display values are uppercased', () {
    const fields = <String, String>{
      'full_name': 'AFIYA FALAK',
      'admission_no': 'ADM-42',
      'roll_no': 'R-7',
      'stream': 'SCIENCE',
      'father_name': 'WASIM AKHTAR',
      'mother_name': 'NIKHAT PARWEEN',
      'gender': 'FEMALE',
      'blood_group': 'A+',
      'mobile': '9876543210',
      'aadhaar': '123456789012',
      'address': 'BURKA KANKE RANCHI',
      'session': '2026-2027',
      'class': 'CLASS 8',
      'section': 'SECTION A',
    };

    for (final entry in fields.entries) {
      final element = DesignElement(
        id: 'field-${entry.key}',
        type: DesignElementType.boundText,
        x: 0,
        y: 0,
        width: 10,
        height: 5,
        data: {'field': entry.key},
      );

      expect(
        bindings.text(element),
        entry.value,
        reason: '${entry.key} should render in uppercase',
      );
    }
  });

  test('prefix and suffix keep their designed case', () {
    const element = DesignElement(
      id: 'father-name',
      type: DesignElementType.boundText,
      x: 0,
      y: 0,
      width: 10,
      height: 5,
      data: {
        'field': 'father_name',
        'prefix': 'F. Name : ',
        'suffix': ' / Parent',
      },
    );

    expect(bindings.text(element), 'F. Name : WASIM AKHTAR / Parent');
  });

  test('student custom-field display values are uppercased', () {
    const element = DesignElement(
      id: 'house',
      type: DesignElementType.customFieldText,
      x: 0,
      y: 0,
      width: 10,
      height: 5,
      data: {'field_uuid': 'house', 'fallback': 'Sample house'},
    );

    expect(bindings.text(element), 'BLUE HOUSE');
  });

  test('static template text keeps its original case', () {
    const element = DesignElement(
      id: 'static-label',
      type: DesignElementType.text,
      x: 0,
      y: 0,
      width: 10,
      height: 5,
      data: {'text': 'Student Identity Card'},
    );

    expect(bindings.text(element), 'Student Identity Card');
  });

  test('verification QR preserves case-sensitive data', () {
    const element = DesignElement(
      id: 'verification-qr',
      type: DesignElementType.qrCode,
      x: 0,
      y: 0,
      width: 10,
      height: 10,
      data: {'field': 'verification_url'},
    );

    expect(bindings.text(element), 'https://example.test/verify/AbC123xYz');
  });

  test('raw student data remains unchanged', () {
    const element = DesignElement(
      id: 'student-name',
      type: DesignElementType.boundText,
      x: 0,
      y: 0,
      width: 10,
      height: 5,
      data: {'field': 'full_name'},
    );

    expect(bindings.rawValue(element), 'Afiya Falak');
    expect(student.fullName, 'Afiya Falak');
    expect(bindings.text(element), 'AFIYA FALAK');
  });
}
