import '../models/student.dart';

abstract class StudentRepository {
  /// ==========================================================
  /// Create
  /// ==========================================================

  Future<int> addStudent(Student student);

  /// ==========================================================
  /// Read
  /// ==========================================================

  Future<Student?> getStudentById(int id);

  Future<List<Student>> getAllStudents();

  /// ==========================================================
  /// Update
  /// ==========================================================

  Future<void> updateStudent(Student student);

  /// ==========================================================
  /// Delete
  /// ==========================================================

  Future<void> deleteStudent(int id);

  /// ==========================================================
  /// Search
  /// ==========================================================

  Future<List<Student>> searchStudents(String query);

  /// ==========================================================
  /// Filters
  /// ==========================================================

  Future<List<Student>> getStudentsByClass(String className);

  Future<List<Student>> getStudentsBySection(String section);

  Future<List<Student>> getStudentsBySession(String session);

  /// ==========================================================
  /// Utilities
  /// ==========================================================

  Future<int> getStudentCount();

  Future<void> clearDatabase();
}
