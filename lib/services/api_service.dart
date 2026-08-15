import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

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
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://127.0.0.1:8000',
          );

  final http.Client _client;
  final String baseUrl;
  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _client.post(
      _uri('/auth/login'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _client.get(_uri('/users/me'), headers: _headers);
    return _decodeMap(response);
  }

  Future<List<dynamic>> getSchools() async {
    final response = await _client.get(_uri('/schools'), headers: _headers);
    return _decodeList(response);
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

  Future<List<dynamic>> getAcademicSessions(String schoolUuid) async {
    final response = await _client.get(
      _uri('/schools/$schoolUuid/academic-sessions'),
      headers: _headers,
    );
    return _decodeList(response);
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
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['detail'] is String) {
        message = body['detail'] as String;
      }
    } catch (_) {}
    return ApiException(response.statusCode, message);
  }

  void dispose() => _client.close();
}
