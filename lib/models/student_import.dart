import 'dart:typed_data';

class StudentImportTemplateFile {
  const StudentImportTemplateFile({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final Uint8List bytes;
  final String filename;
  final String contentType;
}

class StudentImportMapping {
  const StudentImportMapping({
    required this.sourceColumn,
    required this.targetField,
  });

  final String sourceColumn;
  final String targetField;

  Map<String, dynamic> toJson() => {
    'source_column': sourceColumn,
    'target_field': targetField,
  };

  factory StudentImportMapping.fromJson(Map<String, dynamic> json) =>
      StudentImportMapping(
        sourceColumn: json['source_column'] as String,
        targetField: json['target_field'] as String,
      );
}

class StudentImportTargetField {
  const StudentImportTargetField({
    required this.key,
    required this.label,
    required this.required,
    required this.dataType,
  });

  final String key;
  final String label;
  final bool required;
  final String dataType;

  factory StudentImportTargetField.fromJson(Map<String, dynamic> json) =>
      StudentImportTargetField(
        key: json['key'] as String,
        label: json['label'] as String,
        required: json['required'] == true,
        dataType: json['data_type'] as String? ?? 'text',
      );
}

class StudentImportUpload {
  const StudentImportUpload({
    required this.uploadId,
    required this.filename,
    required this.headers,
    required this.rowCount,
    required this.targetFields,
    required this.suggestedMappings,
  });

  final String uploadId;
  final String filename;
  final List<String> headers;
  final int rowCount;
  final List<StudentImportTargetField> targetFields;
  final List<StudentImportMapping> suggestedMappings;

  factory StudentImportUpload.fromJson(Map<String, dynamic> json) =>
      StudentImportUpload(
        uploadId: json['upload_id'] as String,
        filename: json['filename'] as String,
        headers: (json['headers'] as List<dynamic>).cast<String>(),
        rowCount: (json['row_count'] as num).toInt(),
        targetFields: (json['target_fields'] as List<dynamic>)
            .map(
              (item) => StudentImportTargetField.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(),
        suggestedMappings: (json['suggested_mappings'] as List<dynamic>)
            .map(
              (item) =>
                  StudentImportMapping.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}

class StudentImportPreviewRow {
  const StudentImportPreviewRow({
    required this.rowNumber,
    required this.values,
    required this.errors,
  });

  final int rowNumber;
  final Map<String, dynamic> values;
  final List<String> errors;

  factory StudentImportPreviewRow.fromJson(Map<String, dynamic> json) =>
      StudentImportPreviewRow(
        rowNumber: (json['row_number'] as num).toInt(),
        values: Map<String, dynamic>.from(json['values'] as Map),
        errors: (json['errors'] as List<dynamic>).cast<String>(),
      );
}

class StudentImportPreview {
  const StudentImportPreview({
    required this.totalRows,
    required this.validRows,
    required this.invalidRows,
    required this.duplicateRows,
    required this.canImport,
    required this.rows,
  });

  final int totalRows;
  final int validRows;
  final int invalidRows;
  final int duplicateRows;
  final bool canImport;
  final List<StudentImportPreviewRow> rows;

  factory StudentImportPreview.fromJson(Map<String, dynamic> json) =>
      StudentImportPreview(
        totalRows: (json['total_rows'] as num).toInt(),
        validRows: (json['valid_rows'] as num).toInt(),
        invalidRows: (json['invalid_rows'] as num).toInt(),
        duplicateRows: (json['duplicate_rows'] as num).toInt(),
        canImport: json['can_import'] == true,
        rows: (json['rows'] as List<dynamic>)
            .map(
              (item) => StudentImportPreviewRow.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(),
      );
}

class StudentImportSummary {
  const StudentImportSummary({
    required this.importedCount,
    required this.skippedCount,
    required this.message,
  });

  final int importedCount;
  final int skippedCount;
  final String message;

  factory StudentImportSummary.fromJson(Map<String, dynamic> json) =>
      StudentImportSummary(
        importedCount: (json['imported_count'] as num).toInt(),
        skippedCount: (json['skipped_count'] as num).toInt(),
        message: json['message'] as String,
      );
}
