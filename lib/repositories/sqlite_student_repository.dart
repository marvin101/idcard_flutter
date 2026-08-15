import '../models/student.dart';
import '../services/api_service.dart';
import 'student_repository.dart';

class SqliteStudentRepository implements StudentRepository {
  final SQLiteService sqliteService;

  SqliteStudentRepository(this.sqliteService);

  @override
  Future<int> addStudent(Student student) async {
    throw UnimplementedError();
  }

  @override
  Future<void> clearDatabase() async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteStudent(int id) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Student>> getAllStudents() async {
    throw UnimplementedError();
  }

  @override
  Future<Student?> getStudentById(int id) async {
    throw UnimplementedError();
  }

  @override
  Future<int> getStudentCount() async {
    throw UnimplementedError();
  }

  @override
  Future<List<Student>> getStudentsByClass(String className) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Student>> getStudentsBySection(String section) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Student>> getStudentsBySession(String session) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Student>> searchStudents(String query) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateStudent(Student student) async {
    throw UnimplementedError();
  }
}
