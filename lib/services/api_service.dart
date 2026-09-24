import 'session_http_client.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../models/api_student.dart';
import '../models/api_personnel.dart';
import '../models/academic_session.dart';
import '../models/bulk_photo_import.dart';
import '../models/school_class.dart';
import '../models/section.dart';
import '../models/card_template.dart';
import '../models/school_profile.dart';
import '../models/student_field.dart';
import '../models/student_import.dart';
import '../models/public_form.dart';
import '../models/public_design.dart';
import '../models/public_verification.dart';
import '../models/student_grid.dart';
import '../models/personnel_grid.dart';

/// Local SQLite service retained for the existing student repository.
/// The current authentication/user-management workflow uses FastAPI; this
/// local service remains available until student persistence is migrated.
class SQLiteService {
  static const String databaseName = 'school_id_card.db';
  static const int databaseVersion = 1;

  Database? _database;

  SQLiteService() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, databaseName);
    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT,
        fatherName TEXT,
        motherName TEXT,
        dob TEXT,
        gender TEXT,
        bloodGroup TEXT,
        admissionNo TEXT,
        rollNo TEXT,
        className TEXT,
        section TEXT,
        stream TEXT,
        house TEXT,
        session TEXT,
        mobile TEXT,
        aadhaar TEXT,
        address TEXT,
        photoPath TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future local database migrations.
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

class ApiException implements Exception {
  const ApiException(
    this.statusCode,
    this.message, [
    this.gridErrors = const [],
    this.details = const {},
  ]);

  final int statusCode;
  final String message;
  final List<StudentGridCellError> gridErrors;
  final Map<String, dynamic> details;

  @override
  String toString() => message;
}

class ApiStudentPage {
  const ApiStudentPage({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
    required this.hasMore,
  });

  final List<ApiStudent> items;
  final int total;
  final int offset;
  final int limit;
  final bool hasMore;

  factory ApiStudentPage.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((item) => ApiStudent.fromJson(item as Map<String, dynamic>))
        .toList();

    return ApiStudentPage(
      items: items,
      total: (json['total'] as num?)?.toInt() ?? 0,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      hasMore: json['has_more'] == true,
    );
  }
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://127.0.0.1:8000',
          ) {
    _client = SessionHttpClient(client ?? http.Client(), this.baseUrl);
  }

  late final SessionHttpClient _client;
  final String baseUrl;

  Future<PublicFormConfig?> getPublicFormConfig(String schoolUuid) async {
    final response = await _client.get(
      _uri('/schools/$schoolUuid/public-form'),
      headers: _headers,
    );
    final decoded = _decode(response);
    return decoded == null
        ? null
        : PublicFormConfig.fromJson(decoded as Map<String, dynamic>);
  }

  Future<PublicFormConfig> savePublicFormConfig({
    required String schoolUuid,
    required PublicFormConfig config,
  }) async {
    final response = await _client.put(
      _uri('/schools/$schoolUuid/public-form'),
      headers: _headers,
      body: jsonEncode({
        'title': config.title,
        'instructions': config.instructions,
        'is_active': config.isActive,
        'require_all_fields': config.requireAllFields,
        'allow_photo': config.allowPhoto,
        'expires_at': config.expiresAt?.toUtc().toIso8601String(),
        'selected_system_fields': config.selectedSystemFields,
        'selected_custom_field_uuids': config.selectedCustomFieldUuids,
        'success_message': config.successMessage,
      }),
    );
    return PublicFormConfig.fromJson(_decodeMap(response));
  }

  Future<PublicFormConfig> regeneratePublicFormLink(String schoolUuid) async {
    final response = await _client.post(
      _uri('/schools/$schoolUuid/public-form/regenerate-link'),
      headers: _headers,
    );
    return PublicFormConfig.fromJson(_decodeMap(response));
  }

  Future<PublicFormSubmissionPage> getPublicFormSubmissions(
    String schoolUuid, {
    String? status,
  }) async {
    final query = status == null
        ? ''
        : '?status_filter=${Uri.encodeQueryComponent(status)}';
    final response = await _client.get(
      _uri('/schools/$schoolUuid/public-form/submissions$query'),
      headers: _headers,
    );
    return PublicFormSubmissionPage.fromJson(_decodeMap(response));
  }

  Future<PublicFormSubmission> approvePublicFormSubmission(
    String schoolUuid,
    String submissionUuid,
  ) async {
    final response = await _client.post(
      _uri(
        '/schools/$schoolUuid/public-form/submissions/$submissionUuid/approve',
      ),
      headers: _headers,
    );
    return PublicFormSubmission.fromJson(_decodeMap(response));
  }

  Future<PublicFormSubmission> rejectPublicFormSubmission(
    String schoolUuid,
    String submissionUuid, {
    String? note,
  }) async {
    final response = await _client.post(
      _uri(
        '/schools/$schoolUuid/public-form/submissions/$submissionUuid/reject',
      ),
      headers: _headers,
      body: jsonEncode({'note': note}),
    );
    return PublicFormSubmission.fromJson(_decodeMap(response));
  }

  Future<PublicFormView> getPublicForm(String token) async {
    final response = await _client.get(
      _uri('/public/forms/${Uri.encodeComponent(token)}'),
    );
    return PublicFormView.fromJson(_decodeMap(response));
  }

  Future<PublicDesignView> getPublicDesign(String token) async {
    final response = await _client.get(
      _uri('/public/designs/${Uri.encodeComponent(token)}'),
    );
    return PublicDesignView.fromJson(_decodeMap(response));
  }

  Future<PublicStudentVerification> getPublicStudentVerification(
    String token,
  ) async {
    final response = await _client.get(
      _uri('/public/verifications/${Uri.encodeComponent(token)}'),
    );
    return PublicStudentVerification.fromJson(_decodeMap(response));
  }

  Future<PublicVerificationSettings> getPublicVerificationSettings(
    String schoolUuid,
  ) async {
    final response = await _client.get(
      _uri('/schools/$schoolUuid/public-verification'),
      headers: _headers,
    );
    return PublicVerificationSettings.fromJson(_decodeMap(response));
  }

  Future<PublicVerificationSettings> updatePublicVerificationSettings({
    required String schoolUuid,
    required bool enabled,
    required List<String> fields,
    required int validityDays,
  }) async {
    final response = await _client.put(
      _uri('/schools/$schoolUuid/public-verification'),
      headers: _headers,
      body: jsonEncode({
        'enabled': enabled,
        'fields': fields,
        'validity_days': validityDays,
      }),
    );
    return PublicVerificationSettings.fromJson(_decodeMap(response));
  }

  Future<StudentVerificationLink> getStudentVerificationLink({
    required String schoolUuid,
    required String studentUuid,
  }) async {
    final response = await _client.get(
      _uri('/schools/$schoolUuid/students/$studentUuid/public-verification'),
      headers: _headers,
    );
    return StudentVerificationLink.fromJson(_decodeMap(response));
  }

  Future<StudentVerificationLink> updateStudentVerificationLink({
    required String schoolUuid,
    required String studentUuid,
    required bool enabled,
  }) async {
    final response = await _client.put(
      _uri('/schools/$schoolUuid/students/$studentUuid/public-verification'),
      headers: _headers,
      body: jsonEncode({'enabled': enabled}),
    );
    return StudentVerificationLink.fromJson(_decodeMap(response));
  }

  Future<StudentVerificationLink> regenerateStudentVerificationLink({
    required String schoolUuid,
    required String studentUuid,
  }) async {
    final response = await _client.post(
      _uri(
        '/schools/$schoolUuid/students/$studentUuid/public-verification/regenerate-link',
      ),
      headers: _headers,
    );
    return StudentVerificationLink.fromJson(_decodeMap(response));
  }

  Future<PublicDesignShare> getPublicDesignShare(String schoolUuid) async {
    final response = await _client.get(
      _uri('/schools/$schoolUuid/card-template/public-share'),
      headers: _headers,
    );
    return PublicDesignShare.fromJson(_decodeMap(response));
  }

  Future<PublicDesignShare> updatePublicDesignShare({
    required String schoolUuid,
    required bool enabled,
  }) async {
    final response = await _client.put(
      _uri('/schools/$schoolUuid/card-template/public-share'),
      headers: _headers,
      body: jsonEncode({'enabled': enabled}),
    );
    return PublicDesignShare.fromJson(_decodeMap(response));
  }

  Future<PublicDesignShare> regeneratePublicDesignShare(
    String schoolUuid,
  ) async {
    final response = await _client.post(
      _uri('/schools/$schoolUuid/card-template/public-share/regenerate-link'),
      headers: _headers,
    );
    return PublicDesignShare.fromJson(_decodeMap(response));
  }

  Future<String> submitPublicForm({
    required String token,
    required Map<String, dynamic> studentData,
    XFile? photo,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/public/forms/${Uri.encodeComponent(token)}/submissions'),
    );
    request.fields['student_data_json'] = jsonEncode(studentData);
    if (photo != null) {
      final name = photo.name.toLowerCase();
      final subtype = name.endsWith('.png')
          ? 'png'
          : name.endsWith('.webp')
          ? 'webp'
          : 'jpeg';
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          await photo.readAsBytes(),
          filename: photo.name,
          contentType: MediaType('image', subtype),
        ),
      );
    }
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    return _decodeMap(response)['message'] as String;
  }

  String? _token;
  void Function()? _onSessionInvalidated;
  bool _sessionInvalidationReported = false;

  void setToken(String? token) {
    _token = token;
    _client.setTokens(token, null);
    if (token != null) _sessionInvalidationReported = false;
  }

  void setRefreshToken(String? refresh) => _client.setTokens(_token, refresh);

  void setSessionInvalidatedCallback(void Function()? callback) {
    _onSessionInvalidated = callback;
    _client.onInvalidated = () {
      if (!_sessionInvalidationReported) {
        _sessionInvalidationReported = true;
        _token = null;
        _onSessionInvalidated?.call();
      }
    };
  }

  void setTokensRefreshedCallback(
    Future<void> Function(String, String) callback, {
    void Function()? onRefreshed,
  }) {
    _client.onTokens = (access, refresh) async {
      _token = access;
      await callback(access, refresh);
    };
    _client.onRefreshed = onRefreshed;
  }

  Future<void> revokeSession() => _client.revoke();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<List<dynamic>> getAdminSchools() async => _decodeList(
    await _client.get(
      _uri('/schools?include_inactive=true'),
      headers: _headers,
    ),
  );
  Future<Map<String, dynamic>> createSchool(String code, String name) async =>
      _decodeMap(
        await _client.post(
          _uri('/schools'),
          headers: _headers,
          body: jsonEncode({'school_code': code, 'school_name': name}),
        ),
      );
  Future<Map<String, dynamic>> setSchoolActivation(
    String uuid,
    bool active,
  ) async => _decodeMap(
    await _client.patch(
      _uri('/schools/$uuid/activation'),
      headers: _headers,
      body: jsonEncode({'is_active': active}),
    ),
  );
  Future<SchoolProfile> removeSchoolLogo(String uuid) async =>
      SchoolProfile.fromJson(
        _decodeMap(
          await _client.delete(_uri('/schools/$uuid/logo'), headers: _headers),
        ),
      );
  Future<List<dynamic>> getAccounts({
    int offset = 0,
    String search = '',
  }) async => _decodeList(
    await _client.get(
      _uri('/users').replace(
        queryParameters: {
          'offset': '$offset',
          'limit': '100',
          'search': search,
        },
      ),
      headers: _headers,
    ),
  );
  Future<Map<String, dynamic>> createAccount(Map<String, dynamic> data) async =>
      _decodeMap(
        await _client.post(
          _uri('/users/accounts'),
          headers: _headers,
          body: jsonEncode(data),
        ),
      );
  Future<Map<String, dynamic>> updateAccount(
    String uuid,
    Map<String, dynamic> data,
  ) async => _decodeMap(
    await _client.patch(
      _uri('/users/$uuid/account'),
      headers: _headers,
      body: jsonEncode(data),
    ),
  );

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _client.post(
      _uri('/auth/login'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String fullName,
    required String schoolUuid,
    required String designation,
    String? email,
    String? mobile,
  }) async {
    final response = await _client.post(
      _uri('/users/register'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'password': password,
        'full_name': fullName,
        'school_uuid': schoolUuid,
        'email': _nullIfEmpty(email),
        'mobile': _nullIfEmpty(mobile),
        'designation': designation,
      }),
    );
    return _decodeMap(response);
  }

  Future<List<dynamic>> getRegistrationSchools() async {
    final response = await _client.get(
      _uri('/users/registration-schools'),
      headers: _headers,
    );
    return _decodeList(response);
  }

  String? _nullIfEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _client.get(_uri('/users/me'), headers: _headers);
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> updateMe({
    required String username,
    required String fullName,
    String? email,
    String? mobile,
  }) async {
    final response = await _client.patch(
      _uri('/users/me'),
      headers: _headers,
      body: jsonEncode({
        'username': username.trim(),
        'full_name': fullName.trim(),
        'email': _nullIfEmpty(email),
        'mobile': _nullIfEmpty(mobile),
      }),
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> uploadProfilePhoto(XFile photo) async {
    final sourceFilename = photo.name.trim();
    final lowerName = sourceFilename.toLowerCase();
    final mimeType =
        photo.mimeType ??
        switch (lowerName) {
          String name when name.endsWith('.jpg') || name.endsWith('.jpeg') =>
            'image/jpeg',
          String name when name.endsWith('.png') => 'image/png',
          String name when name.endsWith('.webp') => 'image/webp',
          _ => null,
        };
    if (!{'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
      throw const ApiException(0, 'Choose a JPEG, PNG or WebP profile photo.');
    }
    final request = http.MultipartRequest(
      'POST',
      _uri('/users/me/profile-photo'),
    );
    request.headers.addAll(
      Map<String, String>.from(_headers)
        ..removeWhere((key, value) => key.toLowerCase() == 'content-type'),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        await photo.readAsBytes(),
        filename: sourceFilename.isEmpty ? 'profile-photo' : sourceFilename,
        contentType: MediaType.parse(mimeType!),
      ),
    );
    return _decodeMap(
      await http.Response.fromStream(await _client.send(request)),
    );
  }

  Future<Map<String, dynamic>> removeProfilePhoto() async => _decodeMap(
    await _client.delete(_uri('/users/me/profile-photo'), headers: _headers),
  );

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _client.post(
      _uri('/users/me/change-password'),
      headers: _headers,
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    _decode(response);
  }

  Future<List<dynamic>> getSchools() async {
    final response = await _client.get(_uri('/schools'), headers: _headers);
    return _decodeList(response);
  }

  Future<SchoolProfile> getSchoolProfile(String schoolUuid) async {
    final response = await _client.get(
      _uri('/schools/$schoolUuid/profile'),
      headers: _headers,
    );
    return SchoolProfile.fromJson(_decodeMap(response));
  }

  Future<SchoolProfile> updateSchoolProfile(SchoolProfile profile) async {
    final response = await _client.patch(
      _uri('/schools/${profile.uuid}/profile'),
      headers: _headers,
      body: jsonEncode(profile.toUpdateJson()),
    );
    return SchoolProfile.fromJson(_decodeMap(response));
  }

  Future<SchoolProfile> uploadSchoolLogo({
    required String schoolUuid,
    required XFile logo,
  }) async {
    final sourceFilename = logo.name.trim();
    final lowerName = sourceFilename.toLowerCase();
    final mimeType =
        logo.mimeType ??
        switch (lowerName) {
          String name when name.endsWith('.jpg') || name.endsWith('.jpeg') =>
            'image/jpeg',
          String name when name.endsWith('.png') => 'image/png',
          String name when name.endsWith('.webp') => 'image/webp',
          _ => null,
        };
    if (!{'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
      throw const ApiException(0, 'Choose a JPEG, PNG or WebP school logo.');
    }
    final filename = sourceFilename.isNotEmpty
        ? sourceFilename
        : switch (mimeType) {
            'image/jpeg' => 'school_logo.jpg',
            'image/png' => 'school_logo.png',
            'image/webp' => 'school_logo.webp',
            _ => 'school_logo',
          };

    final request = http.MultipartRequest(
      'POST',
      _uri('/schools/$schoolUuid/logo'),
    );
    request.headers.addAll(
      Map<String, String>.from(_headers)
        ..removeWhere((key, value) => key.toLowerCase() == 'content-type'),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'logo',
        await logo.readAsBytes(),
        filename: filename,
        contentType: MediaType.parse(mimeType!),
      ),
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    return SchoolProfile.fromJson(_decodeMap(response));
  }

  Future<SchoolProfile> uploadPrincipalSignature({
    required String schoolUuid,
    required XFile signature,
  }) async {
    final sourceFilename = signature.name.trim();
    final lowerName = sourceFilename.toLowerCase();
    final mimeType =
        signature.mimeType ??
        switch (lowerName) {
          String name when name.endsWith('.jpg') || name.endsWith('.jpeg') =>
            'image/jpeg',
          String name when name.endsWith('.png') => 'image/png',
          String name when name.endsWith('.webp') => 'image/webp',
          _ => null,
        };
    if (!{'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
      throw const ApiException(
        0,
        'Choose a JPEG, PNG or WebP principal signature.',
      );
    }
    final filename = sourceFilename.isNotEmpty
        ? sourceFilename
        : switch (mimeType) {
            'image/jpeg' => 'principal_signature.jpg',
            'image/png' => 'principal_signature.png',
            'image/webp' => 'principal_signature.webp',
            _ => 'principal_signature',
          };

    final request = http.MultipartRequest(
      'POST',
      _uri('/schools/$schoolUuid/principal-signature'),
    );
    request.headers.addAll(
      Map<String, String>.from(_headers)
        ..removeWhere((key, value) => key.toLowerCase() == 'content-type'),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'signature',
        await signature.readAsBytes(),
        filename: filename,
        contentType: MediaType.parse(mimeType!),
      ),
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    return SchoolProfile.fromJson(_decodeMap(response));
  }

  Future<SchoolProfile> removePrincipalSignature(String schoolUuid) async {
    final response = await _client.delete(
      _uri('/schools/$schoolUuid/principal-signature'),
      headers: _headers,
    );
    return SchoolProfile.fromJson(_decodeMap(response));
  }

  Future<List<dynamic>> getUserSchools(String userUuid) async {
    final response = await _client.get(
      _uri('/users/$userUuid/schools'),
      headers: _headers,
    );
    return _decodeList(response);
  }

  Future<List<dynamic>> getSchoolAssignments(String schoolUuid) async {
    final response = await _client.get(
      _uri('/users/schools/$schoolUuid/assignments'),
      headers: _headers,
    );
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> createSchoolAccess({
    required String userUuid,
    required String schoolUuid,
    required String role,
  }) async {
    final response = await _client.post(
      _uri('/users/$userUuid/schools/$schoolUuid'),
      headers: _headers,
      body: jsonEncode({'role': role}),
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> updateSchoolAccess({
    required String userUuid,
    required String schoolUuid,
    required String role,
  }) async {
    final response = await _client.put(
      _uri('/users/$userUuid/schools/$schoolUuid'),
      headers: _headers,
      body: jsonEncode({'role': role}),
    );
    return _decodeMap(response);
  }

  Future<List<AcademicSession>> getAcademicSessions(String schoolUuid) async {
    final response = await _client.get(
      _uri('/schools/$schoolUuid/academic-sessions'),
      headers: _headers,
    );

    return _decodeList(
      response,
    ).map((item) => AcademicSession.fromJson(item)).toList();
  }

  Future<CardTemplate> getCardTemplate(String schoolUuid) async {
    final response = await _client.get(
      _uri('/schools/$schoolUuid/card-template'),
      headers: _headers,
    );
    return _decodeCardTemplate(response);
  }

  Future<CardTemplate> saveCardTemplate(
    String schoolUuid,
    CardTemplate template, {
    DateTime? expectedUpdatedAt,
  }) async {
    final response = await _client.put(
      _uri('/schools/$schoolUuid/card-template'),
      headers: _headers,
      body: jsonEncode(template.toApi(expectedUpdatedAt: expectedUpdatedAt)),
    );
    return _decodeCardTemplate(response);
  }

  Future<CardTemplate> copyCardTemplate({
    required String sourceSchoolUuid,
    required String targetSchoolUuid,
    DateTime? expectedUpdatedAt,
  }) async {
    final response = await _client.post(
      _uri('/schools/$targetSchoolUuid/card-template/copy'),
      headers: _headers,
      body: jsonEncode({
        'source_school_uuid': sourceSchoolUuid,
        if (expectedUpdatedAt != null)
          'expected_updated_at': expectedUpdatedAt.toUtc().toIso8601String(),
      }),
    );
    return _decodeCardTemplate(response);
  }

  Future<Map<String, dynamic>> createAcademicSession({
    required String schoolUuid,
    required String name,
    DateTime? startDate,
    DateTime? endDate,
    bool isCurrent = false,
  }) async {
    final response = await _client.post(
      _uri('/schools/$schoolUuid/academic-sessions'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'start_date': _formatDate(startDate),
        'end_date': _formatDate(endDate),
        'is_current': isCurrent,
      }),
    );
    return _decodeMap(response);
  }

  Future<List<SchoolClass>> getClasses(String schoolUuid) async {
    final response = await _client.get(
      _uri('/schools/$schoolUuid/classes'),
      headers: _headers,
    );

    return _decodeList(
      response,
    ).map((item) => SchoolClass.fromJson(item)).toList();
  }

  Future<Map<String, dynamic>> createClass({
    required String schoolUuid,
    required String name,
  }) async {
    final response = await _client.post(
      _uri('/schools/$schoolUuid/classes'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> updateClass({
    required String schoolUuid,
    required String classUuid,
    required String name,
  }) async {
    final response = await _client.put(
      _uri('/schools/$schoolUuid/classes/$classUuid'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    return _decodeMap(response);
  }

  Future<void> deleteClass({
    required String schoolUuid,
    required String classUuid,
  }) async {
    final response = await _client.delete(
      _uri('/schools/$schoolUuid/classes/$classUuid'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response);
    }
  }

  Future<List<SchoolSection>> getSections({
    required String schoolUuid,
    required String classUuid,
  }) async {
    final response = await _client.get(
      _uri('/schools/$schoolUuid/classes/$classUuid/sections'),
      headers: _headers,
    );

    return _decodeList(
      response,
    ).map((item) => SchoolSection.fromJson(item)).toList();
  }

  Future<Map<String, dynamic>> createSection({
    required String schoolUuid,
    required String classUuid,
    required String name,
  }) async {
    final response = await _client.post(
      _uri('/schools/$schoolUuid/classes/$classUuid/sections'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> updateSection({
    required String schoolUuid,
    required String classUuid,
    required String sectionUuid,
    required String name,
  }) async {
    final response = await _client.put(
      _uri('/schools/$schoolUuid/classes/$classUuid/sections/$sectionUuid'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    return _decodeMap(response);
  }

  Future<void> deleteSection({
    required String schoolUuid,
    required String classUuid,
    required String sectionUuid,
  }) async {
    final response = await _client.delete(
      _uri('/schools/$schoolUuid/classes/$classUuid/sections/$sectionUuid'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response);
    }
  }

  Future<ApiPersonnelPage> getPersonnel({
    required String schoolUuid,
    required PersonnelType personnelType,
    int limit = 100,
    int offset = 0,
    String? search,
    String? verificationStatus,
    bool? printed,
  }) async {
    final query = <String, String>{
      'personnel_type': personnelType.apiValue,
      'limit': '$limit',
      'offset': '$offset',
      if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
      if (verificationStatus?.isNotEmpty == true)
        'verification_status': verificationStatus!,
      if (printed != null) 'printed': '$printed',
    };
    final response = await _client.get(
      _uri('/schools/$schoolUuid/personnel').replace(queryParameters: query),
      headers: _headers,
    );
    return ApiPersonnelPage.fromJson(_decodeMap(response));
  }

  Future<List<StudentFieldDefinition>> getPersonnelFields({
    required String schoolUuid,
    required PersonnelType personnelType,
    bool includeInactive = false,
  }) async {
    final response = await _client.get(
      _uri('/schools/$schoolUuid/personnel-fields').replace(
        queryParameters: {
          'personnel_type': personnelType.apiValue,
          if (includeInactive) 'include_inactive': 'true',
        },
      ),
      headers: _headers,
    );
    return _decodeList(response)
        .whereType<Map<String, dynamic>>()
        .map(StudentFieldDefinition.fromJson)
        .toList();
  }

  Future<ApiPersonnel> createPersonnel({
    required String schoolUuid,
    required PersonnelType personnelType,
    required String employeeNo,
    required String fullName,
    String? designation,
    String? department,
    DateTime? dob,
    String? gender,
    String? bloodGroup,
    String? mobile,
    String? email,
    String? address,
    List<StudentCustomFieldValue> customFields = const [],
  }) async {
    final response = await _client.post(
      _uri('/schools/$schoolUuid/personnel'),
      headers: _headers,
      body: jsonEncode({
        'personnel_type': personnelType.apiValue,
        'employee_no': employeeNo,
        'full_name': fullName,
        'designation': designation,
        'department': department,
        'dob': _formatDate(dob),
        'gender': gender,
        'blood_group': bloodGroup,
        'mobile': mobile,
        'email': email,
        'address': address,
        'custom_fields': customFields.map((item) => item.toJson()).toList(),
      }),
    );
    return ApiPersonnel.fromJson(_decodeMap(response));
  }

  Future<ApiPersonnel> updatePersonnel({
    required String schoolUuid,
    required String personnelUuid,
    required PersonnelType personnelType,
    required String employeeNo,
    required String fullName,
    String? designation,
    String? department,
    DateTime? dob,
    String? gender,
    String? bloodGroup,
    String? mobile,
    String? email,
    String? address,
    List<StudentCustomFieldValue>? customFields,
  }) async {
    final response = await _client.put(
      _uri('/schools/$schoolUuid/personnel/$personnelUuid'),
      headers: _headers,
      body: jsonEncode({
        'personnel_type': personnelType.apiValue,
        'employee_no': employeeNo,
        'full_name': fullName,
        'designation': designation,
        'department': department,
        'dob': _formatDate(dob),
        'gender': gender,
        'blood_group': bloodGroup,
        'mobile': mobile,
        'email': email,
        'address': address,
        if (customFields != null)
          'custom_fields': customFields.map((item) => item.toJson()).toList(),
      }),
    );
    return ApiPersonnel.fromJson(_decodeMap(response));
  }

  Future<ApiPersonnel> uploadPersonnelPhoto({
    required String schoolUuid,
    required String personnelUuid,
    required XFile photo,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/schools/$schoolUuid/personnel/$personnelUuid/photo'),
    );
    request.headers.addAll(
      Map<String, String>.from(_headers)
        ..removeWhere((key, value) => key.toLowerCase() == 'content-type'),
    );
    final contentType = photo.mimeType ?? 'image/jpeg';
    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        await photo.readAsBytes(),
        filename: photo.name.isEmpty ? 'personnel_photo.jpg' : photo.name,
        contentType: MediaType.parse(contentType),
      ),
    );
    return ApiPersonnel.fromJson(
      _decodeMap(await http.Response.fromStream(await _client.send(request))),
    );
  }

  Future<ApiPersonnel> removePersonnelPhoto({
    required String schoolUuid,
    required String personnelUuid,
  }) async {
    final response = await _client.delete(
      _uri('/schools/$schoolUuid/personnel/$personnelUuid/photo'),
      headers: _headers,
    );
    return ApiPersonnel.fromJson(_decodeMap(response));
  }

  Future<void> deletePersonnel({
    required String schoolUuid,
    required String personnelUuid,
  }) async {
    final response = await _client.delete(
      _uri('/schools/$schoolUuid/personnel/$personnelUuid'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response);
    }
  }

  Future<ApiPersonnel> updatePersonnelVerification({
    required String schoolUuid,
    required String personnelUuid,
    required String status,
    String? note,
  }) async {
    final response = await _client.patch(
      _uri('/schools/$schoolUuid/personnel/$personnelUuid/verification'),
      headers: _headers,
      body: jsonEncode({'status': status, 'note': note}),
    );
    return ApiPersonnel.fromJson(_decodeMap(response));
  }

  Future<ApiPersonnel> markPersonnelPrinted({
    required String schoolUuid,
    required String personnelUuid,
  }) async {
    final response = await _client.post(
      _uri('/schools/$schoolUuid/personnel/$personnelUuid/mark-printed'),
      headers: _headers,
    );
    return ApiPersonnel.fromJson(_decodeMap(response));
  }

  Future<List<ApiPersonnel>> batchVerifyPersonnel({
    required String schoolUuid,
    required List<String> personnelUuids,
  }) => _batchPersonnelLifecycle(
    schoolUuid: schoolUuid,
    endpoint: 'batch-verify',
    personnelUuids: personnelUuids,
  );

  Future<List<ApiPersonnel>> batchMarkPersonnelPrinted({
    required String schoolUuid,
    required List<String> personnelUuids,
  }) => _batchPersonnelLifecycle(
    schoolUuid: schoolUuid,
    endpoint: 'batch-mark-printed',
    personnelUuids: personnelUuids,
  );

  Future<List<ApiPersonnel>> _batchPersonnelLifecycle({
    required String schoolUuid,
    required String endpoint,
    required List<String> personnelUuids,
  }) async {
    final response = await _client.post(
      _uri('/schools/$schoolUuid/personnel/$endpoint'),
      headers: _headers,
      body: jsonEncode({'personnel_uuids': personnelUuids}),
    );
    final data = _decodeMap(response);
    return (data['personnel'] as List<dynamic>? ?? const [])
        .map((item) => ApiPersonnel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<PersonnelAuditEvent>> getPersonnelHistory({
    required String schoolUuid,
    required String personnelUuid,
  }) async {
    final response = await _client.get(
      _uri('/schools/$schoolUuid/personnel/$personnelUuid/history'),
      headers: _headers,
    );
    return _decodeList(
      response,
    ).map((item) => PersonnelAuditEvent.fromJson(item)).toList();
  }

  Future<List<ApiStudent>> getStudents({
    required String schoolUuid,
    String? admissionNo,
    String? sessionUuid,
    String? classUuid,
    String? sectionUuid,
    String? verificationStatus,
    bool? printed,
  }) async {
    final queryParameters = <String, String>{};

    if (admissionNo != null && admissionNo.trim().isNotEmpty) {
      queryParameters['admission_no'] = admissionNo.trim();
    }

    if (sessionUuid != null && sessionUuid.isNotEmpty) {
      queryParameters['session_uuid'] = sessionUuid;
    }

    if (classUuid != null && classUuid.isNotEmpty) {
      queryParameters['class_uuid'] = classUuid;
    }

    if (sectionUuid != null && sectionUuid.isNotEmpty) {
      queryParameters['section_uuid'] = sectionUuid;
    }
    if (verificationStatus != null && verificationStatus.isNotEmpty) {
      queryParameters['verification_status'] = verificationStatus;
    }
    if (printed != null) queryParameters['printed'] = printed.toString();

    final uri = Uri.parse('$baseUrl/schools/$schoolUuid/students').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final response = await _client.get(uri, headers: _headers);

    final data = _decodeList(response);

    return data.map((item) => ApiStudent.fromJson(item)).toList();
  }

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
  }) async {
    final queryParameters = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }

    if (sessionUuid != null && sessionUuid.isNotEmpty) {
      queryParameters['session_uuid'] = sessionUuid;
    }

    if (classUuid != null && classUuid.isNotEmpty) {
      queryParameters['class_uuid'] = classUuid;
    }

    if (sectionUuid != null && sectionUuid.isNotEmpty) {
      queryParameters['section_uuid'] = sectionUuid;
    }

    if (createdFrom != null) {
      queryParameters['created_from'] = _dateOnly(createdFrom);
    }

    if (createdTo != null) {
      queryParameters['created_to'] = _dateOnly(createdTo);
    }
    if (verificationStatus != null && verificationStatus.isNotEmpty) {
      queryParameters['verification_status'] = verificationStatus;
    }
    if (printed != null) queryParameters['printed'] = printed.toString();

    final uri = Uri.parse(
      '$baseUrl/schools/$schoolUuid/students/paged',
    ).replace(queryParameters: queryParameters);

    final response = await _client.get(uri, headers: _headers);

    return ApiStudentPage.fromJson(_decodeMap(response));
  }

  Future<StudentGridPage> getStudentGrid({
    required String schoolUuid,
    int limit = 100,
    int offset = 0,
    String? search,
    String? sessionUuid,
    String? classUuid,
    String? sectionUuid,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
      if (sessionUuid?.isNotEmpty == true) 'session_uuid': sessionUuid!,
      if (classUuid?.isNotEmpty == true) 'class_uuid': classUuid!,
      if (sectionUuid?.isNotEmpty == true) 'section_uuid': sectionUuid!,
    };
    final uri = _uri(
      '/schools/$schoolUuid/students/grid',
    ).replace(queryParameters: query);
    return StudentGridPage.fromJson(
      _decodeMap(await _client.get(uri, headers: _headers)),
    );
  }

  Future<StudentGridPatchResult> patchStudentGrid({
    required String schoolUuid,
    required List<StudentGridRowPatch> rows,
  }) async {
    final response = await _client.patch(
      _uri('/schools/$schoolUuid/students/grid'),
      headers: _headers,
      body: jsonEncode({'rows': rows.map((row) => row.toJson()).toList()}),
    );
    return StudentGridPatchResult.fromJson(_decodeMap(response));
  }

  Future<PersonnelGridPage> getPersonnelGrid({
    required String schoolUuid,
    required PersonnelType personnelType,
    int limit = 100,
    int offset = 0,
    String? search,
    bool? active = true,
    String? department,
    String? designation,
  }) async {
    final query = <String, String>{
      'personnel_type': personnelType.apiValue,
      'limit': '$limit',
      'offset': '$offset',
      if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
      if (active != null) 'active': '$active',
      if (department?.isNotEmpty == true) 'department': department!,
      if (designation?.isNotEmpty == true) 'designation': designation!,
    };
    final response = await _client.get(
      _uri(
        '/schools/$schoolUuid/personnel/grid',
      ).replace(queryParameters: query),
      headers: _headers,
    );
    return PersonnelGridPage.fromJson(_decodeMap(response));
  }

  Future<PersonnelGridPatchResult> patchPersonnelGrid({
    required String schoolUuid,
    required List<PersonnelGridRowPatch> rows,
  }) async {
    final response = await _client.patch(
      _uri('/schools/$schoolUuid/personnel/grid'),
      headers: _headers,
      body: jsonEncode({'rows': rows.map((row) => row.toJson()).toList()}),
    );
    return PersonnelGridPatchResult.fromJson(_decodeMap(response));
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<ApiStudent> getStudent({
    required String schoolUuid,
    required String studentUuid,
  }) async {
    final response = await _client.get(
      _uri('/schools/$schoolUuid/students/$studentUuid'),
      headers: _headers,
    );

    return ApiStudent.fromJson(_decodeMap(response));
  }

  Future<ApiStudent> updateStudentVerification({
    required String schoolUuid,
    required String studentUuid,
    required String status,
    String? note,
  }) async {
    final response = await _client.patch(
      _uri('/schools/$schoolUuid/students/$studentUuid/verification'),
      headers: _headers,
      body: jsonEncode({'status': status, 'note': note}),
    );
    return ApiStudent.fromJson(_decodeMap(response));
  }

  Future<ApiStudent> markStudentPrinted({
    required String schoolUuid,
    required String studentUuid,
  }) async {
    final response = await _client.post(
      _uri('/schools/$schoolUuid/students/$studentUuid/mark-printed'),
      headers: _headers,
    );
    return ApiStudent.fromJson(_decodeMap(response));
  }

  Future<List<ApiStudent>> batchVerifyStudents({
    required String schoolUuid,
    required List<String> studentUuids,
  }) => _batchLifecycle(
    schoolUuid: schoolUuid,
    endpoint: 'batch-verify',
    studentUuids: studentUuids,
  );

  Future<List<ApiStudent>> batchMarkStudentsPrinted({
    required String schoolUuid,
    required List<String> studentUuids,
  }) => _batchLifecycle(
    schoolUuid: schoolUuid,
    endpoint: 'batch-mark-printed',
    studentUuids: studentUuids,
  );

  Future<List<ApiStudent>> _batchLifecycle({
    required String schoolUuid,
    required String endpoint,
    required List<String> studentUuids,
  }) async {
    final response = await _client.post(
      _uri('/schools/$schoolUuid/students/$endpoint'),
      headers: _headers,
      body: jsonEncode({'student_uuids': studentUuids}),
    );
    final data = _decodeMap(response);
    return (data['students'] as List<dynamic>? ?? const [])
        .map((item) => ApiStudent.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<StudentAuditEvent>> getStudentHistory({
    required String schoolUuid,
    required String studentUuid,
  }) async {
    final response = await _client.get(
      _uri('/schools/$schoolUuid/students/$studentUuid/history'),
      headers: _headers,
    );
    return _decodeList(
      response,
    ).map((item) => StudentAuditEvent.fromJson(item)).toList();
  }

  Future<StudentImportUpload> uploadStudentImport({
    required String schoolUuid,
    required String filename,
    required Uint8List bytes,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/schools/$schoolUuid/students/imports/upload'),
    );
    request.headers.addAll(
      Map<String, String>.from(_headers)
        ..removeWhere((key, value) => key.toLowerCase() == 'content-type'),
    );
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    return StudentImportUpload.fromJson(_decodeMap(response));
  }

  Future<StudentImportTemplateFile> downloadStudentImportTemplate({
    required String schoolUuid,
  }) async {
    final response = await _client.get(
      _uri('/schools/$schoolUuid/students/imports/template'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response);
    }
    final disposition = response.headers['content-disposition'] ?? '';
    final filename = _responseFilename(disposition);
    return StudentImportTemplateFile(
      bytes: response.bodyBytes,
      filename: filename ?? 'student_import_template.xlsx',
      contentType:
          response.headers['content-type'] ??
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  String? _responseFilename(String contentDisposition) {
    final encoded = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(contentDisposition)?.group(1);
    if (encoded != null) return Uri.decodeComponent(encoded);
    return RegExp(
      r'filename="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(contentDisposition)?.group(1);
  }

  Future<StudentImportPreview> previewStudentImport({
    required String schoolUuid,
    required String uploadId,
    required List<StudentImportMapping> mappings,
  }) async {
    final response = await _client.post(
      _uri('/schools/$schoolUuid/students/imports/$uploadId/preview'),
      headers: _headers,
      body: jsonEncode({
        'mappings': mappings.map((item) => item.toJson()).toList(),
      }),
    );
    return StudentImportPreview.fromJson(_decodeMap(response));
  }

  Future<StudentImportSummary> commitStudentImport({
    required String schoolUuid,
    required String uploadId,
    required List<StudentImportMapping> mappings,
    required bool confirmed,
  }) async {
    final response = await _client.post(
      _uri('/schools/$schoolUuid/students/imports/$uploadId/commit'),
      headers: _headers,
      body: jsonEncode({
        'mappings': mappings.map((item) => item.toJson()).toList(),
        'confirmed': confirmed,
      }),
    );
    return StudentImportSummary.fromJson(_decodeMap(response));
  }

  Future<StudentImportUpload> uploadPersonnelImport({
    required String schoolUuid,
    required PersonnelType personnelType,
    required String filename,
    required Uint8List bytes,
  }) async {
    final uri = _uri(
      '/schools/$schoolUuid/personnel/imports/upload',
    ).replace(queryParameters: {'personnel_type': personnelType.apiValue});
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(
      Map<String, String>.from(_headers)
        ..removeWhere((key, value) => key.toLowerCase() == 'content-type'),
    );
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    return StudentImportUpload.fromJson(
      _decodeMap(await http.Response.fromStream(await _client.send(request))),
    );
  }

  Future<StudentImportTemplateFile> downloadPersonnelImportTemplate({
    required String schoolUuid,
    required PersonnelType personnelType,
  }) async {
    final response = await _client.get(
      _uri(
        '/schools/$schoolUuid/personnel/imports/template',
      ).replace(queryParameters: {'personnel_type': personnelType.apiValue}),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response);
    }
    return StudentImportTemplateFile(
      bytes: response.bodyBytes,
      filename:
          _responseFilename(response.headers['content-disposition'] ?? '') ??
          '${personnelType.apiValue}_import_template.xlsx',
      contentType:
          response.headers['content-type'] ??
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  Future<StudentImportPreview> previewPersonnelImport({
    required String schoolUuid,
    required PersonnelType personnelType,
    required String uploadId,
    required List<StudentImportMapping> mappings,
  }) async {
    final response = await _client.post(
      _uri(
        '/schools/$schoolUuid/personnel/imports/$uploadId/preview',
      ).replace(queryParameters: {'personnel_type': personnelType.apiValue}),
      headers: _headers,
      body: jsonEncode({
        'mappings': mappings.map((item) => item.toJson()).toList(),
      }),
    );
    return StudentImportPreview.fromJson(_decodeMap(response));
  }

  Future<StudentImportSummary> commitPersonnelImport({
    required String schoolUuid,
    required PersonnelType personnelType,
    required String uploadId,
    required List<StudentImportMapping> mappings,
    required bool confirmed,
  }) async {
    final response = await _client.post(
      _uri(
        '/schools/$schoolUuid/personnel/imports/$uploadId/commit',
      ).replace(queryParameters: {'personnel_type': personnelType.apiValue}),
      headers: _headers,
      body: jsonEncode({
        'mappings': mappings.map((item) => item.toJson()).toList(),
        'confirmed': confirmed,
      }),
    );
    return StudentImportSummary.fromJson(_decodeMap(response));
  }

  Future<BulkPhotoUploadResponse> uploadBulkStudentPhotos({
    required String schoolUuid,
    required String filename,
    required Uint8List bytes,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/schools/$schoolUuid/student-photos/bulk/upload'),
    );
    request.headers.addAll(
      Map<String, String>.from(_headers)
        ..removeWhere((key, value) => key.toLowerCase() == 'content-type'),
    );
    request.files.add(
      http.MultipartFile.fromBytes('archive', bytes, filename: filename),
    );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    return BulkPhotoUploadResponse.fromJson(_decodeMap(response));
  }

  Future<BulkPhotoPreviewResponse> previewBulkStudentPhotos({
    required String schoolUuid,
    required String manifestUuid,
  }) async {
    final response = await _client.post(
      _uri('/schools/$schoolUuid/student-photos/bulk/$manifestUuid/preview'),
      headers: _headers,
    );
    return BulkPhotoPreviewResponse.fromJson(_decodeMap(response));
  }

  Future<BulkPhotoCommitResponse> commitBulkStudentPhotos({
    required String schoolUuid,
    required String manifestUuid,
    required bool confirmed,
  }) async {
    final response = await _client.post(
      _uri('/schools/$schoolUuid/student-photos/bulk/$manifestUuid/commit'),
      headers: _headers,
      body: jsonEncode({'confirmed': confirmed}),
    );
    return BulkPhotoCommitResponse.fromJson(_decodeMap(response));
  }

  Future<BulkPhotoUploadResponse> uploadBulkPersonnelPhotos({
    required String schoolUuid,
    required PersonnelType personnelType,
    required String filename,
    required Uint8List bytes,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri(
        '/schools/$schoolUuid/personnel-photos/bulk/upload',
      ).replace(queryParameters: {'personnel_type': personnelType.apiValue}),
    );
    request.headers.addAll(
      Map<String, String>.from(_headers)
        ..removeWhere((key, value) => key.toLowerCase() == 'content-type'),
    );
    request.files.add(
      http.MultipartFile.fromBytes('archive', bytes, filename: filename),
    );
    return BulkPhotoUploadResponse.fromJson(
      _decodeMap(await http.Response.fromStream(await _client.send(request))),
    );
  }

  Future<BulkPhotoPreviewResponse> previewBulkPersonnelPhotos({
    required String schoolUuid,
    required PersonnelType personnelType,
    required String manifestUuid,
  }) async {
    final response = await _client.post(
      _uri(
        '/schools/$schoolUuid/personnel-photos/bulk/$manifestUuid/preview',
      ).replace(queryParameters: {'personnel_type': personnelType.apiValue}),
      headers: _headers,
    );
    return BulkPhotoPreviewResponse.fromJson(_decodeMap(response));
  }

  Future<BulkPhotoCommitResponse> commitBulkPersonnelPhotos({
    required String schoolUuid,
    required PersonnelType personnelType,
    required String manifestUuid,
    required bool confirmed,
  }) async {
    final response = await _client.post(
      _uri(
        '/schools/$schoolUuid/personnel-photos/bulk/$manifestUuid/commit',
      ).replace(queryParameters: {'personnel_type': personnelType.apiValue}),
      headers: _headers,
      body: jsonEncode({'confirmed': confirmed}),
    );
    return BulkPhotoCommitResponse.fromJson(_decodeMap(response));
  }

  Future<ApiStudent> createStudent({
    required String schoolUuid,
    required String sessionUuid,
    required String classUuid,
    required String sectionUuid,
    required String admissionNo,
    String? rollNo,
    String? stream,
    required String fullName,
    String? fatherName,
    String? motherName,
    DateTime? dob,
    String? gender,
    String? bloodGroup,
    String? mobile,
    String? aadhaar,
    String? address,
    List<StudentCustomFieldValue> customFields = const [],
    Set<String>? enabledFields,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/schools/$schoolUuid/students'),
    );

    // Keep authentication headers, but let MultipartRequest
    // create its own Content-Type boundary.
    request.headers.addAll(
      Map<String, String>.from(_headers)
        ..removeWhere((key, value) => key.toLowerCase() == 'content-type'),
    );

    final enabled = enabledFields;
    final studentData = <String, dynamic>{
      'session_uuid': sessionUuid,
      'class_uuid': classUuid,
      'section_uuid': sectionUuid,
      'admission_no': admissionNo,
      'full_name': fullName,
      if (enabled == null || enabled.contains('roll_no')) 'roll_no': rollNo,
      if (enabled == null || enabled.contains('stream')) 'stream': stream,
      if (enabled == null || enabled.contains('father_name'))
        'father_name': fatherName,
      if (enabled == null || enabled.contains('mother_name'))
        'mother_name': motherName,
      if (enabled == null || enabled.contains('dob')) 'dob': _formatDate(dob),
      if (enabled == null || enabled.contains('gender')) 'gender': gender,
      if (enabled == null || enabled.contains('blood_group'))
        'blood_group': bloodGroup,
      if (enabled == null || enabled.contains('mobile')) 'mobile': mobile,
      if (enabled == null || enabled.contains('aadhaar')) 'aadhaar': aadhaar,
      if (enabled == null || enabled.contains('address')) 'address': address,
      'custom_fields': customFields.map((item) => item.toJson()).toList(),
    };

    request.fields['student_data_json'] = jsonEncode(studentData);

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    return ApiStudent.fromJson(_decodeMap(response));
  }

  Future<void> uploadStudentPhoto({
    required String schoolUuid,
    required String studentUuid,
    required XFile photo,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/schools/$schoolUuid/students/$studentUuid/photo'),
    );

    // Authentication header only.
    // MultipartRequest creates its own Content-Type boundary.
    request.headers.addAll(
      Map<String, String>.from(_headers)
        ..removeWhere((key, value) => key.toLowerCase() == 'content-type'),
    );

    final bytes = await photo.readAsBytes();

    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        bytes,
        filename: 'student_photo.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    _decodeMap(response);
  }

  Future<void> removeStudentPhoto({
    required String schoolUuid,
    required String studentUuid,
  }) async {
    final response = await _client.delete(
      _uri('/schools/$schoolUuid/students/$studentUuid/photo'),
      headers: _headers,
    );
    _decodeMap(response);
  }

  Future<ApiStudent> updateStudent({
    required String schoolUuid,
    required String studentUuid,
    required String sessionUuid,
    required String classUuid,
    required String sectionUuid,
    required String admissionNo,
    String? rollNo,
    String? stream,
    required String fullName,
    String? fatherName,
    String? motherName,
    DateTime? dob,
    String? gender,
    String? bloodGroup,
    String? mobile,
    String? aadhaar,
    String? address,
    String? photoPath,
    List<StudentCustomFieldValue>? customFields,
    Set<String>? enabledFields,
  }) async {
    final response = await _client.put(
      _uri('/schools/$schoolUuid/students/$studentUuid'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'session_uuid': sessionUuid,
        'class_uuid': classUuid,
        'section_uuid': sectionUuid,
        'admission_no': admissionNo,
        'full_name': fullName,
        if (enabledFields == null || enabledFields.contains('roll_no'))
          'roll_no': rollNo,
        if (enabledFields == null || enabledFields.contains('stream'))
          'stream': stream,
        if (enabledFields == null || enabledFields.contains('father_name'))
          'father_name': fatherName,
        if (enabledFields == null || enabledFields.contains('mother_name'))
          'mother_name': motherName,
        if (enabledFields == null || enabledFields.contains('dob'))
          'dob': _formatDate(dob),
        if (enabledFields == null || enabledFields.contains('gender'))
          'gender': gender,
        if (enabledFields == null || enabledFields.contains('blood_group'))
          'blood_group': bloodGroup,
        if (enabledFields == null || enabledFields.contains('mobile'))
          'mobile': mobile,
        if (enabledFields == null || enabledFields.contains('aadhaar'))
          'aadhaar': aadhaar,
        if (enabledFields == null || enabledFields.contains('address'))
          'address': address,
        'photo_path': photoPath,
        if (customFields != null)
          'custom_fields': customFields.map((item) => item.toJson()).toList(),
      }),
    );

    return ApiStudent.fromJson(_decodeMap(response));
  }

  Future<List<StudentFieldDefinition>> getStudentFields(
    String schoolUuid, {
    bool includeInactive = false,
  }) async {
    final uri = _uri(
      '/schools/$schoolUuid/student-fields?include_inactive=$includeInactive',
    );
    final response = await _client.get(uri, headers: _headers);
    return _decodeList(response)
        .map(
          (item) =>
              StudentFieldDefinition.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<BuiltinStudentField>> getBuiltinStudentFields(
    String schoolUuid,
  ) async {
    final response = await _client.get(
      _uri('/schools/$schoolUuid/student-field-config'),
      headers: _headers,
    );
    final fields = _decodeMap(response)['fields'] as List<dynamic>? ?? const [];
    return fields
        .map(
          (item) => BuiltinStudentField.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<BuiltinStudentField>> updateBuiltinStudentFields({
    required String schoolUuid,
    required List<BuiltinStudentField> fields,
  }) async {
    final response = await _client.put(
      _uri('/schools/$schoolUuid/student-field-config'),
      headers: _headers,
      body: jsonEncode({
        'fields': fields.map((item) => item.toJson()).toList(),
      }),
    );
    final values = _decodeMap(response)['fields'] as List<dynamic>? ?? const [];
    return values
        .map(
          (item) => BuiltinStudentField.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<StudentFieldDefinition> createStudentField({
    required String schoolUuid,
    required String fieldKey,
    required String label,
    required String dataType,
    required bool isRequired,
  }) async {
    final response = await _client.post(
      _uri('/schools/$schoolUuid/student-fields'),
      headers: _headers,
      body: jsonEncode({
        'field_key': fieldKey,
        'label': label,
        'data_type': dataType,
        'is_required': isRequired,
      }),
    );
    return StudentFieldDefinition.fromJson(_decodeMap(response));
  }

  Future<StudentFieldDefinition> updateStudentField({
    required String schoolUuid,
    required String fieldUuid,
    String? label,
    String? dataType,
    bool? isRequired,
    bool? isActive,
    int? displayOrder,
  }) async {
    final payload = <String, dynamic>{
      'label': label,
      'data_type': dataType,
      'is_required': isRequired,
      'is_active': isActive,
      'display_order': displayOrder,
    }..removeWhere((_, value) => value == null);
    final response = await _client.patch(
      _uri('/schools/$schoolUuid/student-fields/$fieldUuid'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    return StudentFieldDefinition.fromJson(_decodeMap(response));
  }

  Future<List<StudentFieldDefinition>> reorderStudentFields({
    required String schoolUuid,
    required List<StudentFieldDefinition> fields,
  }) async {
    final response = await _client.put(
      _uri('/schools/$schoolUuid/student-fields/reorder'),
      headers: _headers,
      body: jsonEncode({
        'fields': [
          for (var index = 0; index < fields.length; index++)
            {'field_uuid': fields[index].uuid, 'display_order': index},
        ],
      }),
    );
    return _decodeList(response)
        .map(
          (item) =>
              StudentFieldDefinition.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> deleteStudent({
    required String schoolUuid,
    required String studentUuid,
  }) async {
    final response = await _client.delete(
      _uri('/schools/$schoolUuid/students/$studentUuid'),
      headers: _headers,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response);
    }
  }

  Future<Map<String, dynamic>> updateAcademicSession({
    required String schoolUuid,
    required String sessionUuid,
    required String name,
    DateTime? startDate,
    DateTime? endDate,
    required bool isCurrent,
  }) async {
    final response = await _client.put(
      _uri('/schools/$schoolUuid/academic-sessions/$sessionUuid'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'start_date': _formatDate(startDate),
        'end_date': _formatDate(endDate),
        'is_current': isCurrent,
      }),
    );
    return _decodeMap(response);
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    final local = DateTime(date.year, date.month, date.day);
    return local.toIso8601String().split('T').first;
  }

  Future<void> revokeSchoolAccess({
    required String userUuid,
    required String schoolUuid,
  }) async {
    final response = await _client.delete(
      _uri('/users/$userUuid/schools/$schoolUuid'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response);
    }
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final decoded = _decode(response);
    if (decoded is Map<String, dynamic>) return decoded;
    throw ApiException(response.statusCode, 'Unexpected server response.');
  }

  CardTemplate _decodeCardTemplate(http.Response response) {
    try {
      return CardTemplate.fromApi(_decodeMap(response));
    } on ApiException {
      rethrow;
    } on FormatException catch (error) {
      final unsupported = error.message.toString().contains(
        'Unsupported card-template schema_version',
      );
      throw ApiException(
        response.statusCode,
        unsupported
            ? 'The server returned a card template with an unsupported schema version.'
            : 'The server returned an invalid card template.',
      );
    } on TypeError {
      throw ApiException(
        response.statusCode,
        'The server returned an invalid card template.',
      );
    }
  }

  List<dynamic> _decodeList(http.Response response) {
    final decoded = _decode(response);
    if (decoded is List<dynamic>) return decoded;
    throw ApiException(response.statusCode, 'Unexpected server response.');
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response);
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  ApiException _apiException(http.Response response) {
    String message = 'Request failed (${response.statusCode}).';
    List<StudentGridCellError> gridErrors = const [];
    Map<String, dynamic> details = const {};

    try {
      final body = jsonDecode(response.body);

      if (body is Map<String, dynamic>) {
        final rawErrors = body['errors'];
        if (rawErrors is List) {
          gridErrors = rawErrors
              .whereType<Map<String, dynamic>>()
              .map(StudentGridCellError.fromJson)
              .toList();
        }
        final detail = body['detail'];

        // Normal FastAPI HTTPException.
        if (detail is String && detail.trim().isNotEmpty) {
          message = detail;
        }
        // Structured domain error (for example, unresolved custom fields
        // during a cross-school card-template copy).
        else if (detail is Map<String, dynamic>) {
          details = detail;
          final detailMessage = detail['message'];
          if (detailMessage is String && detailMessage.trim().isNotEmpty) {
            message = detailMessage;
          }
        }
        // FastAPI validation error.
        else if (detail is List) {
          final messages = detail
              .map((item) {
                if (item is Map<String, dynamic>) {
                  final msg = item['msg'];
                  final location = item['loc'];

                  if (msg is String && location is List) {
                    final field = location.whereType<String>().join('.');
                    return field.isEmpty ? msg : '$field: $msg';
                  }

                  if (msg is String) {
                    return msg;
                  }
                }

                return item.toString();
              })
              .join('\n');

          if (messages.isNotEmpty) {
            message = messages;
          }
        }
      }
    } catch (_) {
      // Keep the generic message if the response isn't valid JSON.
    }

    return ApiException(response.statusCode, message, gridErrors, details);
  }

  void dispose() => _client.close();
}
