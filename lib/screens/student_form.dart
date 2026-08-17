import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../layouts/main_layout.dart';
import '../providers/api_student_form_provider.dart';
import '../sections/academic_information_section.dart';
import '../sections/contact_information_section.dart';
import '../sections/personal_information_section.dart';
import '../sections/photo_section.dart';
import '../services/api_service.dart';
import '../models/api_student.dart';

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

  Future<void> _save(BuildContext context) async {
    final provider = context.read<ApiStudentFormProvider>();

    final success = await provider.saveStudent();

    if (!context.mounted) return;

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

    return MainLayout(
      title: provider.student == null ? 'Add student' : 'Edit student',
      child: Form(
        key: provider.formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const PersonalInformationSection(),
              const SizedBox(height: 24),

              const AcademicInformationSection(),
              const SizedBox(height: 24),

              const ContactInformationSection(),
              const SizedBox(height: 24),

              const PhotoSection(),
              const SizedBox(height: 24),

              // ------------------------------------------------
              // Save button
              // ------------------------------------------------
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: provider.saving ? null : () => _save(context),
                  icon: provider.saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(provider.saving ? 'Saving...' : 'Save Student'),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
