class BulkPhotoUploadResponse {
  const BulkPhotoUploadResponse({
    required this.manifestUuid,
    required this.filename,
    required this.totalFiles,
    required this.expiresAt,
  });

  final String manifestUuid;
  final String filename;
  final int totalFiles;
  final DateTime expiresAt;

  factory BulkPhotoUploadResponse.fromJson(Map<String, dynamic> json) =>
      BulkPhotoUploadResponse(
        manifestUuid: json['manifest_uuid'] as String,
        filename: json['filename'] as String,
        totalFiles: (json['total_files'] as num).toInt(),
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );
}

class BulkPhotoItem {
  const BulkPhotoItem({
    required this.filename,
    required this.status,
    required this.hasExistingPhoto,
    this.admissionNo,
    this.studentUuid,
    this.studentName,
    this.detail,
  });

  final String filename;
  final String? admissionNo;
  final String? studentUuid;
  final String? studentName;
  final String status;
  final String? detail;
  final bool hasExistingPhoto;

  factory BulkPhotoItem.fromJson(Map<String, dynamic> json) => BulkPhotoItem(
    filename: json['filename'] as String,
    admissionNo: json['admission_no'] as String?,
    studentUuid: json['student_uuid'] as String?,
    studentName: json['student_name'] as String?,
    status: json['status'] as String,
    detail: json['detail'] as String?,
    hasExistingPhoto: json['has_existing_photo'] == true,
  );
}

class BulkPhotoPreviewResponse {
  const BulkPhotoPreviewResponse({
    required this.manifestUuid,
    required this.totalFiles,
    required this.readyCount,
    required this.unmatchedCount,
    required this.invalidCount,
    required this.replacementCount,
    required this.canCommit,
    required this.items,
  });

  final String manifestUuid;
  final int totalFiles;
  final int readyCount;
  final int unmatchedCount;
  final int invalidCount;
  final int replacementCount;
  final bool canCommit;
  final List<BulkPhotoItem> items;

  factory BulkPhotoPreviewResponse.fromJson(Map<String, dynamic> json) =>
      BulkPhotoPreviewResponse(
        manifestUuid: json['manifest_uuid'] as String,
        totalFiles: (json['total_files'] as num).toInt(),
        readyCount: (json['ready_count'] as num).toInt(),
        unmatchedCount: (json['unmatched_count'] as num).toInt(),
        invalidCount: (json['invalid_count'] as num).toInt(),
        replacementCount: (json['replacement_count'] as num).toInt(),
        canCommit: json['can_commit'] == true,
        items: (json['items'] as List<dynamic>? ?? const [])
            .map(
              (item) => BulkPhotoItem.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}

class BulkPhotoCommitItem {
  const BulkPhotoCommitItem({
    required this.filename,
    required this.status,
    this.admissionNo,
    this.studentUuid,
    this.studentName,
    this.detail,
  });

  final String filename;
  final String? admissionNo;
  final String? studentUuid;
  final String? studentName;
  final String status;
  final String? detail;

  factory BulkPhotoCommitItem.fromJson(Map<String, dynamic> json) =>
      BulkPhotoCommitItem(
        filename: json['filename'] as String,
        admissionNo: json['admission_no'] as String?,
        studentUuid: json['student_uuid'] as String?,
        studentName: json['student_name'] as String?,
        status: json['status'] as String,
        detail: json['detail'] as String?,
      );
}

class BulkPhotoCommitResponse {
  const BulkPhotoCommitResponse({
    required this.manifestUuid,
    required this.totalFiles,
    required this.uploadedCount,
    required this.failedCount,
    required this.unmatchedCount,
    required this.invalidCount,
    required this.replacementCount,
    required this.completed,
    required this.items,
  });

  final String manifestUuid;
  final int totalFiles;
  final int uploadedCount;
  final int failedCount;
  final int unmatchedCount;
  final int invalidCount;
  final int replacementCount;
  final bool completed;
  final List<BulkPhotoCommitItem> items;

  factory BulkPhotoCommitResponse.fromJson(Map<String, dynamic> json) =>
      BulkPhotoCommitResponse(
        manifestUuid: json['manifest_uuid'] as String,
        totalFiles: (json['total_files'] as num).toInt(),
        uploadedCount: (json['uploaded_count'] as num).toInt(),
        failedCount: (json['failed_count'] as num).toInt(),
        unmatchedCount: (json['unmatched_count'] as num).toInt(),
        invalidCount: (json['invalid_count'] as num).toInt(),
        replacementCount: (json['replacement_count'] as num).toInt(),
        completed: json['completed'] == true,
        items: (json['items'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  BulkPhotoCommitItem.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}
