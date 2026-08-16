import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../layouts/main_layout.dart';
import '../providers/api_student_form_provider.dart';
import '../sections/academic_information_section.dart';
import '../sections/contact_information_section.dart';
import '../sections/personal_information_section.dart';
import '../sections/photo_section.dart';
import '../services/api_service.dart';

class StudentFormScreen extends StatelessWidget {
  const StudentFormScreen({
    super.key,
    required this.schoolUuid,
    required this.api,
  });

  final String schoolUuid;
  final ApiService api;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ApiStudentFormProvider(api: api, schoolUuid: schoolUuid),
      child: const _StudentFormView(),
    );
  }
}

class _StudentFormView extends StatelessWidget {
  const _StudentFormView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ApiStudentFormProvider>();

    return MainLayout(
      title: 'Add Student',
      child: Form(
        key: provider.formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: const [
              PersonalInformationSection(),
              SizedBox(height: 24),
              AcademicInformationSection(),
              SizedBox(height: 24),
              ContactInformationSection(),
              SizedBox(height: 24),
              PhotoSection(),
            ],
          ),
        ),
      ),
    );
  }
}
