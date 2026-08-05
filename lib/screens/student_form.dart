import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../layouts/main_layout.dart';
import '../providers/student_form_provider.dart';
import '../sections/personal_information_section.dart';
import '../sections/academic_information_section.dart';
import '../sections/contact_information_section.dart';
import '../sections/photo_section.dart';

class StudentFormScreen extends StatelessWidget {
  const StudentFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<StudentFormProvider>();

    return MainLayout(
      title: "Add Student",
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
