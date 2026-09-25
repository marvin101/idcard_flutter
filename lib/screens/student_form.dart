import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../layouts/main_layout.dart';
import '../models/api_student.dart';
import '../providers/api_student_form_provider.dart';
import '../sections/builtin_student_fields_section.dart';
import '../sections/custom_student_fields_section.dart';
import '../sections/photo_section.dart';
import '../services/api_service.dart';
import '../widgets/student_lifecycle_summary.dart';

class StudentFormScreen extends StatelessWidget {
  const StudentFormScreen({
    super.key,
    required this.schoolUuid,
    required this.api,
    this.student,
  });

  final String schoolUuid;
  final ApiService api;
  final ApiStudent? student;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ApiStudentFormProvider(
        api: api,
        schoolUuid: schoolUuid,
        student: student,
      ),
      child: const _StudentFormView(),
    );
  }
}

class _StudentFormView extends StatelessWidget {
  const _StudentFormView();

  static const double _mobileBreakpoint = 700;

  Future<void> _save(BuildContext context) async {
    final provider = context.read<ApiStudentFormProvider>();

    final success = await provider.saveStudent();

    if (!context.mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.student == null
                ? 'Student created successfully.'
                : 'Student updated successfully.',
          ),
        ),
      );

      Navigator.of(context).pop();
      return;
    }

    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ApiStudentFormProvider>();
    final editing = provider.student != null;

    return MainLayout(
      title: editing ? 'Edit student' : 'Add student',
      compactMobile: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < _mobileBreakpoint;

          return Padding(
            padding: compact
                ? const EdgeInsets.fromLTRB(12, 12, 12, 24)
                : EdgeInsets.zero,
            child: Form(
              key: provider.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (provider.student != null) ...[
                    StudentLifecycleSummary(student: provider.student!),
                    SizedBox(height: compact ? 14 : 24),
                  ],

                  const BuiltinStudentFieldsSection(),

                  SizedBox(height: compact ? 14 : 24),

                  const CustomStudentFieldsSection(),

                  if (provider.customFields.isNotEmpty)
                    SizedBox(height: compact ? 14 : 24),

                  const PhotoSection(),

                  SizedBox(height: compact ? 18 : 24),

                  _SaveAction(
                    saving: provider.saving,
                    editing: editing,
                    compact: compact,
                    onPressed: () => _save(context),
                  ),

                  SizedBox(height: compact ? 8 : 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SaveAction extends StatelessWidget {
  const _SaveAction({
    required this.saving,
    required this.editing,
    required this.compact,
    required this.onPressed,
  });

  final bool saving;
  final bool editing;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: saving ? null : onPressed,
      icon: saving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_outlined),
      label: Text(
        saving
            ? 'Saving...'
            : editing
            ? 'Save Student'
            : 'Save Student',
      ),
      style: FilledButton.styleFrom(
        minimumSize: Size(compact ? double.infinity : 0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      ),
    );

    if (compact) {
      return Semantics(
        button: true,
        label: editing ? 'Save changes to student' : 'Save new student',
        child: SizedBox(width: double.infinity, child: button),
      );
    }

    return Align(alignment: Alignment.centerRight, child: button);
  }
}
