import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_models.dart';
import '../providers/auth_provider.dart';
import '../providers/display_scale_provider.dart';
import '../theme/app_colors.dart';
import 'academic_sessions_screen.dart';
import 'classes_sections_screen.dart';
import 'cards_screen.dart';
import 'school_user_assignment_screen.dart';
import 'student_screen.dart';

enum DashboardModuleKind {
  users,
  academicSessions,
  classesAndSections,
  students,
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
    'card_operator' => const {DashboardModuleKind.students},
    'teacher' || 'staff' => const {
      DashboardModuleKind.academicSessions,
      DashboardModuleKind.classesAndSections,
    },
    _ => const {},
  };
}

class DashboardGridLayout {
  const DashboardGridLayout({
    required this.compact,
    required this.columns,
    required this.mainAxisExtent,
  });

  final bool compact;
  final int columns;
  final double mainAxisExtent;
}

DashboardGridLayout dashboardGridLayoutFor(double width) {
  if (width < 600) {
    return DashboardGridLayout(
      compact: true,
      columns: width >= 270 ? 3 : 2,
      mainAxisExtent: 108,
    );
  }
  return const DashboardGridLayout(
    compact: false,
    columns: 0,
    mainAxisExtent: 155,
  );
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;
    final school = auth.selectedSchool;
    final access = auth.selectedSchoolAccess;

    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Image.asset(
              'assets/images/campusid_logo.png',
              width: 34,
              height: 34,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            const Text('CampusID'),
          ],
        ),
        actions: [
          Consumer<DisplayScaleProvider>(
            builder: (context, displayScale, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Zoom out (${displayScale.percentage}%)',
                  onPressed: displayScale.canZoomOut
                      ? displayScale.zoomOut
                      : null,
                  iconSize: 25,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  icon: const Icon(Icons.remove_rounded),
                ),
                IconButton(
                  tooltip: 'Zoom in (${displayScale.percentage}%)',
                  onPressed: displayScale.canZoomIn
                      ? displayScale.zoomIn
                      : null,
                  iconSize: 25,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => context.read<AuthProvider>().logout(),
            iconSize: 28,
            constraints: const BoxConstraints.tightFor(width: 54, height: 54),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth > 900 ? 48 : 20,
            vertical: 32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome, ${user.fullName}.',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SchoolContextCard(
                    auth: auth,
                    school: school,
                    access: access,
                  ),
                  const SizedBox(height: 24),
                  _ModuleGrid(auth: auth),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SchoolContextCard extends StatelessWidget {
  const _SchoolContextCard({required this.auth, this.school, this.access});

  final AuthProvider auth;
  final SchoolSummary? school;
  final SchoolAccess? access;

  @override
  Widget build(BuildContext context) {
    final needsSelection = auth.schools.length > 1 && school == null;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe4e8f0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final selector = DropdownButtonFormField<String>(
            initialValue: school?.uuid,
            decoration: const InputDecoration(
              labelText: 'School context',
              prefixIcon: Icon(Icons.school_outlined),
            ),
            hint: const Text('Select a school'),
            items: auth.schools
                .map(
                  (item) => DropdownMenuItem(
                    value: item.uuid,
                    child: Text(item.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null) return;
              final selected = auth.schools.firstWhere(
                (item) => item.uuid == value,
              );
              try {
                await auth.selectSchool(selected);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
          );

          return constraints.maxWidth > 700
              ? Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current school',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            school?.name ??
                                (needsSelection
                                    ? 'Select a school to continue'
                                    : 'No school assigned'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            auth.isPlatformAdmin
                                ? 'Platform-wide access'
                                : (access?.role ?? 'No school role'),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (auth.schools.length > 1)
                      SizedBox(width: 360, child: selector),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      school?.name ??
                          (needsSelection
                              ? 'Select a school to continue'
                              : 'No school assigned'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      auth.isPlatformAdmin
                          ? 'Platform-wide access'
                          : (access?.role ?? 'No school role'),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (auth.schools.length > 1) ...[
                      const SizedBox(height: 18),
                      selector,
                    ],
                  ],
                );
        },
      ),
    );
  }
}

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid({required this.auth});
  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    final school = auth.selectedSchool;
    final visibleModules = dashboardModulesFor(
      isPlatformAdmin: auth.isPlatformAdmin,
      schoolRole: auth.selectedSchoolAccess?.role,
      hasSelectedSchool: school != null,
    );
    final modules = <_DashboardModule>[
      if (visibleModules.contains(DashboardModuleKind.users))
        _DashboardModule(
          'Users',
          'Manage school assignments and roles.',
          Icons.people_alt_outlined,
          true,
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SchoolUserAssignmentScreen(
                  schoolUuid: school!.uuid,
                  schoolName: school.name,
                  api: auth.api,
                  canManageElevatedRoles: auth.isPlatformAdmin,
                ),
              ),
            );
          },
        ),
      if (visibleModules.contains(DashboardModuleKind.academicSessions))
        _DashboardModule(
          'Academic Sessions',
          'Manage sessions for the selected school.',
          Icons.calendar_month_outlined,
          true,
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AcademicSessionsScreen(
                  schoolUuid: school!.uuid,
                  schoolName: school.name,
                  api: auth.api,
                  canManage: auth.canManageAcademicSessions,
                ),
              ),
            );
          },
        ),
      if (visibleModules.contains(DashboardModuleKind.classesAndSections))
        _DashboardModule(
          'Classes & Sections',
          'Organize classes and sections.',
          Icons.account_tree_outlined,
          true,
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ClassesSectionsScreen(
                  schoolUuid: school!.uuid,
                  schoolName: school.name,
                  api: auth.api,
                  canManage: auth.canManageClasses,
                ),
              ),
            );
          },
        ),
      if (visibleModules.contains(DashboardModuleKind.students))
        _DashboardModule(
          'Students',
          'Student records and ID-card data.',
          Icons.school_outlined,
          true,
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StudentsScreen(
                  schoolUuid: school!.uuid,
                  schoolName: school.name,
                  api: auth.api,
                  canEdit: auth.canManageCardData,
                  canDelete: auth.canDeleteStudents,
                ),
              ),
            );
          },
        ),
      if (visibleModules.contains(DashboardModuleKind.idCards))
        _DashboardModule(
          'ID Cards',
          'Prepare and manage ID cards.',
          Icons.badge_outlined,
          true,
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CardsScreen(
                  schoolUuid: school!.uuid,
                  schoolName: school.name,
                  api: auth.api,
                  canEdit: auth.canManageCardData,
                  canDesign: auth.canDesignCards,
                  canPrint: auth.canPrintCards,
                ),
              ),
            );
          },
        ),
    ];

    if (modules.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffe4e8f0)),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: AppColors.textSecondary,
              size: 34,
            ),
            SizedBox(height: 12),
            Text(
              'No modules are available for this school role.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Contact a School Admin if your assignment needs to change.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = dashboardGridLayoutFor(constraints.maxWidth);
        final delegate = layout.compact
            ? SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: layout.columns,
                mainAxisExtent: layout.mainAxisExtent,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              )
            : SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisExtent: layout.mainAxisExtent,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              );
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: delegate,
          itemCount: modules.length,
          itemBuilder: (_, index) =>
              _ModuleCard(module: modules[index], compact: layout.compact),
        );
      },
    );
  }
}

class _DashboardModule {
  const _DashboardModule(
    this.title,
    this.description,
    this.icon,
    this.enabled,
    this.onTap,
  );
  final String title;
  final String description;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.compact});
  final _DashboardModule module;
  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xffe4e8f0)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: module.enabled ? module.onTap : null,
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 20),
        child: Column(
          mainAxisAlignment: compact
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          crossAxisAlignment: compact
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Icon(
              module.icon,
              color: module.enabled ? AppColors.primary : AppColors.disabled,
              size: compact ? 28 : 30,
            ),
            SizedBox(height: compact ? 8 : 12),
            Text(
              module.title,
              textAlign: compact ? TextAlign.center : TextAlign.start,
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w700,
                color: module.enabled
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 4),
              Text(
                module.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
