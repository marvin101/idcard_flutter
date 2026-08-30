abstract final class AppRoutes {
  static const landing = '/';
  static const signIn = '/sign-in';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const students = '/students';
  static const addStudent = '/students/add';
  static const editStudent = '/students/edit';
  static const studentFields = '/students/fields';
  static const studentImport = '/students/import';
  static const schoolProfile = '/school-profile';
  static const academicSessions = '/academic-sessions';
  static const classesSections = '/classes-sections';
  static const users = '/users';
  static const design = '/design';
  static const cards = '/cards';
  static const privacy = '/privacy';
  static const terms = '/terms';
  static const support = '/support';

  static const protectedRoutes = <String>{
    dashboard,
    students,
    addStudent,
    editStudent,
    studentFields,
    studentImport,
    schoolProfile,
    academicSessions,
    classesSections,
    users,
    design,
    cards,
  };

  static bool isProtected(String? routeName) =>
      routeName != null && protectedRoutes.contains(routeName);
}
