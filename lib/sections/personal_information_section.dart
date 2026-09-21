import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/api_student_form_provider.dart';
import '../utils/validators.dart';
import '../widgets/app_text_input.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/dob_input.dart';
import '../widgets/responsive_row.dart';

class PersonalInformationSection extends StatelessWidget {
  const PersonalInformationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ApiStudentFormProvider>();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Personal Information",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            ResponsiveRow(
              children: [
                AppTextInput(
                  controller: provider.fullNameController,
                  label: "Full Name",
                  hintText: "Enter Full Name",
                  requiredField: true,
                  autoCapitalizeWords: true,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => Validators.required(value, "Full Name"),
                ),

                if (provider.isFieldEnabled('father_name'))
                  AppTextInput(
                    controller: provider.fatherNameController,
                    label: "Father Name",
                    hintText: "Enter Father's Name",
                    requiredField: provider.isFieldRequired('father_name'),
                    validator: provider.isFieldRequired('father_name')
                        ? (value) => Validators.required(value, 'Father Name')
                        : null,
                    autoCapitalizeWords: true,
                    textCapitalization: TextCapitalization.words,
                  ),
              ],
            ),

            const SizedBox(height: 20),

            ResponsiveRow(
              children: [
                if (provider.isFieldEnabled('mother_name'))
                  AppTextInput(
                    controller: provider.motherNameController,
                    label: "Mother Name",
                    hintText: "Enter Mother's Name",
                    requiredField: provider.isFieldRequired('mother_name'),
                    validator: provider.isFieldRequired('mother_name')
                        ? (value) => Validators.required(value, 'Mother Name')
                        : null,
                    autoCapitalizeWords: true,
                    textCapitalization: TextCapitalization.words,
                  ),

                if (provider.isFieldEnabled('dob'))
                  DobInput(
                    label: provider.isFieldRequired('dob')
                        ? 'Date of Birth *'
                        : 'Date of Birth',
                    dayController: provider.dobDayController,
                    monthController: provider.dobMonthController,
                    yearController: provider.dobYearController,
                  ),
              ],
            ),
            if (provider.isFieldEnabled('gender')) ...[
              const SizedBox(height: 20),
              ResponsiveRow(
                children: [
                  AppDropdown<String>(
                    label: 'Gender',
                    value: provider.selectedGender,
                    requiredField: provider.isFieldRequired('gender'),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: provider.setGender,
                    validator: provider.isFieldRequired('gender')
                        ? (value) => value == null || value.isEmpty
                              ? 'Please select a gender'
                              : null
                        : null,
                  ),
                  const SizedBox(),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
