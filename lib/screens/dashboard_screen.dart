import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_models.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import 'academic_sessions_screen.dart';
import 'classes_sections_screen.dart';
import 'cards_screen.dart';
import 'school_user_assignment_screen.dart';
import 'student_screen.dart';

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
        title: const Row(
          children: [
            Icon(Icons.badge_outlined),
            SizedBox(width: 10),
            Text('ID Card Manager'),
          ],
        ),
        actions: [
          if (auth.isPlatformAdmin)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  'PLATFORM ADMIN',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
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
    final canManageUsers = auth.canManageUsers && school != null;
    final modules = <_DashboardModule>[
      _DashboardModule(
        'Users',
        'Manage school assignments and roles.',
        Icons.people_alt_outlined,
        canManageUsers,
        () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SchoolUserAssignmentScreen(
                schoolUuid: school!.uuid,
                schoolName: school.name,
                api: auth.api,
              ),
            ),
          );
        },
      ),
      _DashboardModule(
        'Academic Sessions',
        'Manage sessions for the selected school.',
        Icons.calendar_month_outlined,
        school != null,
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
      _DashboardModule(
        'Classes & Sections',
        'Organize classes and sections.',
        Icons.account_tree_outlined,
        school != null,
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
      _DashboardModule(
        'Students',
        'Student records and ID-card data.',
        Icons.school_outlined,
        school != null,
        () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StudentsScreen(
                schoolUuid: school!.uuid,
                schoolName: school.name,
                api: auth.api,
                canManage: auth.canManageUsers,
              ),
            ),
          );
        },
      ),
      _DashboardModule(
        'ID Cards',
        'Prepare and manage ID cards.',
        Icons.badge_outlined,
        school != null,
        () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CardsScreen(
                schoolUuid: school!.uuid,
                schoolName: school.name,
                api: auth.api,
                canManage: auth.canManageUsers,
              ),
            ),
          );
        },
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        mainAxisExtent: 155,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: modules.length,
      itemBuilder: (_, index) => _ModuleCard(module: modules[index]),
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
  const _ModuleCard({required this.module});
  final _DashboardModule module;

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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              module.icon,
              color: module.enabled ? AppColors.primary : AppColors.disabled,
              size: 30,
            ),
            const SizedBox(height: 12),
            Text(
              module.title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: module.enabled
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
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
        ),
      ),
    ),
  );
}
