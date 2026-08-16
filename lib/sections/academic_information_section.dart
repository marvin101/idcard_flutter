import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/academic_session.dart';
import '../models/school_class.dart';
import '../models/section.dart';
import '../providers/api_student_form_provider.dart';
import '../utils/validators.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/app_text_input.dart';
import '../widgets/responsive_row.dart';

class AcademicInformationSection extends StatelessWidget {
  const AcademicInformationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ApiStudentFormProvider>();

    if (provider.loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (provider.error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unable to load academic information.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(provider.error!),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Academic Information',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            // --------------------------------------------------
            // Admission No. & Roll No.
            // --------------------------------------------------
            ResponsiveRow(
              children: [
                AppTextInput(
                  controller: provider.admissionNoController,
                  label: 'Admission No.',
                  hintText: 'Enter Admission Number',
                  requiredField: true,
                  validator: (value) =>
                      Validators.required(value, 'Admission No.'),
                ),
                AppTextInput(
                  controller: provider.rollNoController,
                  label: 'Roll No.',
                  hintText: 'Enter Roll Number',
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --------------------------------------------------
            // Academic Session & Class
            // --------------------------------------------------
            ResponsiveRow(
              children: [
                AppDropdown<String>(
                  label: 'Academic Session',
                  value: provider.selectedSessionUuid,
                  requiredField: true,
                  items: provider.sessions
                      .map(
                        (AcademicSession session) => DropdownMenuItem<String>(
                          value: session.uuid,
                          child: Text(session.name),
                        ),
                      )
                      .toList(),
                  onChanged: provider.setSession,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a session';
                    }
                    return null;
                  },
                ),

                AppDropdown<String>(
                  label: 'Class',
                  value: provider.selectedClassUuid,
                  requiredField: true,
                  items: provider.classes
                      .map(
                        (SchoolClass schoolClass) => DropdownMenuItem<String>(
                          value: schoolClass.uuid,
                          child: Text(schoolClass.name),
                        ),
                      )
                      .toList(),
                  onChanged: provider.setClass,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a class';
                    }
                    return null;
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --------------------------------------------------
            // Section & Stream
            // --------------------------------------------------
            ResponsiveRow(
              children: [
                AppDropdown<String>(
                  label: 'Section',
                  value: provider.selectedSectionUuid,
                  requiredField: true,
                  enabled:
                      provider.selectedClassUuid != null &&
                      !provider.loadingSections,
                  items: provider.sections
                      .map(
                        (SchoolSection section) => DropdownMenuItem<String>(
                          value: section.uuid,
                          child: Text(section.name),
                        ),
                      )
                      .toList(),
                  onChanged: provider.setSection,
                  suffixIcon: provider.loadingSections
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a section';
                    }
                    return null;
                  },
                ),

                AppTextInput(
                  controller: provider.streamController,
                  label: 'Stream',
                  hintText: 'Science / Commerce / Arts',
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --------------------------------------------------
            // Blood Group
            // --------------------------------------------------
            ResponsiveRow(
              children: [
                AppDropdown<String>(
                  label: 'Blood Group',
                  value: provider.selectedBloodGroup,
                  items: const [
                    DropdownMenuItem(value: 'A+', child: Text('A+')),
                    DropdownMenuItem(value: 'A-', child: Text('A-')),
                    DropdownMenuItem(value: 'B+', child: Text('B+')),
                    DropdownMenuItem(value: 'B-', child: Text('B-')),
                    DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                    DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                    DropdownMenuItem(value: 'O+', child: Text('O+')),
                    DropdownMenuItem(value: 'O-', child: Text('O-')),
                  ],
                  onChanged: provider.setBloodGroup,
                ),
                const SizedBox(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
