import 'package:flutter/material.dart';

import '../layouts/main_layout.dart';
import '../sections/personal_information_section.dart';
import '../sections/academic_information_section.dart';
import '../sections/contact_information_section.dart';
import '../sections/photo_section.dart';

class StudentFormScreen extends StatelessWidget {
  const StudentFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: "Add Student",
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// Personal Information
            const PersonalInformationSection(),

            const SizedBox(height: 24),

            /// Academic Information
            const AcademicInformationSection(),

            const SizedBox(height: 24),

            /// Contact Information
            const ContactInformationSection(),

            const SizedBox(height: 24),

            /// Student Photo
            const PhotoSection(),

            const SizedBox(height: 32),

            /// Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Save student
                },
                icon: const Icon(Icons.save),
                label: const Text(
                  "Save Student",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
