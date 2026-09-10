import 'api_student.dart';
import 'card_template.dart';
import 'design_bindings.dart';
import 'design_barcode.dart';
import 'design_qr.dart';
import 'school_profile.dart';

enum BulkCardExportScope { matchingFilters, selectedStudents, printBasket }

class BulkExportIssue {
  const BulkExportIssue({required this.message, required this.studentCount});

  final String message;
  final int studentCount;
}

class BulkExportInspection {
  const BulkExportInspection({
    required this.warnings,
    required this.blockingIssues,
  });

  final List<BulkExportIssue> warnings;
  final List<BulkExportIssue> blockingIssues;

  bool get canContinue => blockingIssues.isEmpty;

  static BulkExportInspection inspect({
    required Iterable<ApiStudent> students,
    required CardTemplate template,
    required String schoolName,
    required String? Function(ApiStudent) sessionName,
    required String? Function(ApiStudent) className,
    required String? Function(ApiStudent) sectionName,
    String? Function(ApiStudent)? photoUrl,
    SchoolProfile? schoolProfile,
    bool includeBack = false,
  }) {
    final warningCounts = <String, int>{};
    final blockingCounts = <String, int>{};
    final visible =
        [
              template.document,
              if (includeBack && template.backDocument != null)
                template.backDocument!,
            ]
            .expand((document) => document.elements)
            .where((element) => element.visible);
    final needsPhoto = visible.any(
      (element) => element.type == DesignElementType.studentPhoto,
    );
    final boundElements = visible.where(
      (element) =>
          element.type == DesignElementType.boundText ||
          element.type == DesignElementType.customFieldText ||
          ({
                DesignElementType.qrCode,
                DesignElementType.barcode,
              }.contains(element.type) &&
              (element.data.containsKey('field') ||
                  element.data.containsKey('field_uuid'))),
    );
    final qrElements = visible.where(
      (element) => element.type == DesignElementType.qrCode,
    );
    final barcodeElements = visible.where(
      (element) => element.type == DesignElementType.barcode,
    );
    final multiFieldElements = visible.where(
      (element) =>
          {
            DesignElementType.qrCode,
            DesignElementType.barcode,
          }.contains(element.type) &&
          element.data['fields'] is List,
    );

    for (final student in students) {
      final resolvedPhoto = photoUrl?.call(student) ?? student.photoPath;
      if (needsPhoto &&
          (resolvedPhoto == null || resolvedPhoto.trim().isEmpty)) {
        warningCounts.update(
          'Missing student photo',
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      } else if (needsPhoto && !_isUsableImageReference(resolvedPhoto!)) {
        warningCounts.update(
          'Malformed student photo URL',
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }

      final bindings = DesignBindings(
        student: student,
        sessionName: sessionName(student),
        className: className(student),
        sectionName: sectionName(student),
        schoolName: schoolName,
        schoolProfile: schoolProfile,
      );
      final missingForStudent = <String>{};
      for (final element in boundElements) {
        if (bindings.rawValue(element).trim().isNotEmpty ||
            (element.data['fallback'] as String?)?.trim().isNotEmpty == true) {
          continue;
        }
        final label =
            element.type == DesignElementType.customFieldText ||
                element.data.containsKey('field_uuid')
            ? (element.data['label'] as String? ?? 'custom field')
            : _fieldLabel(element.data['field'] as String?);
        missingForStudent.add(label);
      }
      for (final element in multiFieldElements) {
        for (final field in bindings.qrFieldValues(element)) {
          if (field.rawValue.trim().isEmpty && field.value.trim().isEmpty) {
            missingForStudent.add(field.label);
          }
        }
      }
      for (final label in missingForStudent) {
        warningCounts.update(
          'Missing $label',
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      if (qrElements.any(
        (element) => !isDesignQrDataSupported(bindings.text(element)),
      )) {
        blockingCounts.update(
          'QR content exceeds 1000 UTF-8 bytes',
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      for (final element in barcodeElements) {
        final message = designBarcodeValidation(
          bindings.text(element),
          element.data['symbology'] as String? ?? 'code128',
        );
        if (message != null) {
          blockingCounts.update(
            message,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }

    return BulkExportInspection(
      warnings: warningCounts.entries
          .map(
            (entry) =>
                BulkExportIssue(message: entry.key, studentCount: entry.value),
          )
          .toList(),
      blockingIssues: blockingCounts.entries
          .map(
            (entry) =>
                BulkExportIssue(message: entry.key, studentCount: entry.value),
          )
          .toList(),
    );
  }

  static bool _isUsableImageReference(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    if (!uri.hasScheme) return true;
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  static String _fieldLabel(String? field) => switch (field) {
    'admission_no' => 'admission number',
    'roll_no' => 'roll number',
    'full_name' => 'student name',
    'father_name' => "father's name",
    'mother_name' => "mother's name",
    'session' => 'academic session',
    'class' => 'class',
    'section' => 'section',
    null || '' => 'bound field',
    _ => field.replaceAll('_', ' '),
  };
}
