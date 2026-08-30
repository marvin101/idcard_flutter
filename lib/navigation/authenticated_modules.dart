enum DashboardModuleKind {
  schoolProfile,
  users,
  academicSessions,
  classesAndSections,
  students,
  studentFields,
  idCards,
}

Set<DashboardModuleKind> dashboardModulesFor({
  required bool isPlatformAdmin,
  required String? schoolRole,
  required bool hasSelectedSchool,
}) {
  if (!hasSelectedSchool) return const {};

  if (isPlatformAdmin ||
      schoolRole == 'school_admin' ||
      schoolRole == 'admin') {
    return DashboardModuleKind.values.toSet();
  }

  return switch (schoolRole) {
    'card_operator' => const {
      DashboardModuleKind.schoolProfile,
      DashboardModuleKind.students,
      DashboardModuleKind.idCards,
    },
    'teacher' || 'staff' => const {
      DashboardModuleKind.schoolProfile,
      DashboardModuleKind.academicSessions,
      DashboardModuleKind.classesAndSections,
    },
    _ => const {},
  };
}
