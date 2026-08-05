import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SQLiteService {
  static const String databaseName = 'school_id_card.db';
  static const int databaseVersion = 1;

  Database? _database;

  SQLiteService() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();

    return _database!;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await databaseFactory.getDatabasesPath();

    final path = join(dbPath, databaseName);

    return await databaseFactory.openDatabase(
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
    // Future database migrations.
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
