import '../models/student.dart';
import '../services/api_service.dart';
import 'student_repository.dart';

class ApiStudentRepository implements StudentRepository {
  final ApiService apiService;

  ApiStudentRepository(this.apiService);

  // ==========================================================
  // CREATE
  // ==========================================================

  @override
  Future<int> addStudent(Student student) async {
    throw UnimplementedError();
  }

  // ==========================================================
  // READ
  // ==========================================================

  @override
  Future<Student?> getStudentById(int id) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Student>> getAllStudents() async {
    throw UnimplementedError();
  }

  // ==========================================================
  // UPDATE
  // ==========================================================

  @override
  Future<void> updateStudent(Student student) async {
    throw UnimplementedError();
  }

  // ==========================================================
  // DELETE
  // ==========================================================

  @override
  Future<void> deleteStudent(int id) async {
    throw UnimplementedError();
  }

  // ==========================================================
  // SEARCH
  // ==========================================================

  @override
  Future<List<Student>> searchStudents(String query) async {
    throw UnimplementedError();
  }

  // ==========================================================
  // FILTERS
  // ==========================================================

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

  // ==========================================================
  // UTILITIES
  // ==========================================================

  @override
  Future<int> getStudentCount() async {
    throw UnimplementedError();
  }

  @override
  Future<void> clearDatabase() async {
    throw UnimplementedError();
  }
}
