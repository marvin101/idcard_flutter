abstract final class AppRoutes {
  static const landing = '/';
  static const signIn = '/sign-in';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const students = '/students';
  static const teachers = '/teachers';
  static const staff = '/staff';
  static const studentGrid = '/students/grid';
  static const addStudent = '/students/add';
  static const editStudent = '/students/edit';
  static const addTeacher = '/teachers/add';
  static const addStaff = '/staff/add';
  static const editPersonnel = '/personnel/edit';
  static const studentFields = '/students/fields';
  static const publicForms = '/public-forms';
  static const publicFormPrefix = '/public/forms/';
  static const publicDesignPrefix = '/public/designs/';
  static const publicVerificationPrefix = '/verify/';
  static const studentImport = '/students/import';
  static const bulkPhotoImport = '/students/photos/import';
  static const studentHistoryPrefix = '/students/';
  static const studentHistorySuffix = '/history';
  static const personnelHistoryPrefix = '/personnel/';
  static const personnelHistorySuffix = '/history';
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
    teachers,
    staff,
    studentGrid,
    addStudent,
    editStudent,
    addTeacher,
    addStaff,
    editPersonnel,
    studentFields,
    publicForms,
    studentImport,
    bulkPhotoImport,
    schoolProfile,
    academicSessions,
    classesSections,
    users,
    design,
    cards,
  };

  static bool isProtected(String? routeName) =>
      routeName != null &&
      (protectedRoutes.contains(routeName) ||
          isStudentHistory(routeName) ||
          isPersonnelHistory(routeName));

  static String publicForm(String token) =>
      '$publicFormPrefix${Uri.encodeComponent(token)}';
  static bool isPublicForm(String? routeName) =>
      routeName != null &&
      routeName.startsWith(publicFormPrefix) &&
      routeName.length > publicFormPrefix.length;
  static String? publicFormToken(String? routeName) => isPublicForm(routeName)
      ? Uri.decodeComponent(routeName!.substring(publicFormPrefix.length))
      : null;

  static String publicDesign(String token) =>
      '$publicDesignPrefix${Uri.encodeComponent(token)}';
  static bool isPublicDesign(String? routeName) =>
      routeName != null &&
      routeName.startsWith(publicDesignPrefix) &&
      routeName.length > publicDesignPrefix.length;
  static String? publicDesignToken(String? routeName) =>
      isPublicDesign(routeName)
      ? Uri.decodeComponent(routeName!.substring(publicDesignPrefix.length))
      : null;

  static String publicVerification(String token) =>
      '$publicVerificationPrefix${Uri.encodeComponent(token)}';
  static bool isPublicVerification(String? routeName) =>
      routeName != null &&
      routeName.startsWith(publicVerificationPrefix) &&
      routeName.length > publicVerificationPrefix.length;
  static String? publicVerificationToken(String? routeName) =>
      isPublicVerification(routeName)
      ? Uri.decodeComponent(
          routeName!.substring(publicVerificationPrefix.length),
        )
      : null;

  static String studentHistory(String studentUuid) =>
      '$studentHistoryPrefix${Uri.encodeComponent(studentUuid)}$studentHistorySuffix';

  static bool isStudentHistory(String? routeName) =>
      routeName != null &&
      routeName.startsWith(studentHistoryPrefix) &&
      routeName.endsWith(studentHistorySuffix) &&
      routeName.length >
          studentHistoryPrefix.length + studentHistorySuffix.length;

  static String? studentUuidFromHistory(String? routeName) =>
      isStudentHistory(routeName)
      ? Uri.decodeComponent(
          routeName!.substring(
            studentHistoryPrefix.length,
            routeName.length - studentHistorySuffix.length,
          ),
        )
      : null;

  static String personnelHistory(String personnelUuid) =>
      '$personnelHistoryPrefix${Uri.encodeComponent(personnelUuid)}$personnelHistorySuffix';

  static bool isPersonnelHistory(String? routeName) =>
      routeName != null &&
      routeName.startsWith(personnelHistoryPrefix) &&
      routeName.endsWith(personnelHistorySuffix) &&
      routeName.length >
          personnelHistoryPrefix.length + personnelHistorySuffix.length;

  static String? personnelUuidFromHistory(String? routeName) =>
      isPersonnelHistory(routeName)
      ? Uri.decodeComponent(
          routeName!.substring(
            personnelHistoryPrefix.length,
            routeName.length - personnelHistorySuffix.length,
          ),
        )
      : null;
}
