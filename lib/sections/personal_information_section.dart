import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/api_student_form_provider.dart';
import '../utils/validators.dart';
import '../widgets/app_text_input.dart';
import '../widgets/dob_input.dart';
import '../widgets/responsive_row.dart';

class PersonalInformationSection extends StatelessWidget {
  const PersonalInformationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ApiStudentFormProvider>();

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

                AppTextInput(
                  controller: provider.fatherNameController,
                  label: "Father Name",
                  hintText: "Enter Father's Name",
                  autoCapitalizeWords: true,
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            ),

            const SizedBox(height: 20),

            ResponsiveRow(
              children: [
                AppTextInput(
                  controller: provider.motherNameController,
                  label: "Mother Name",
                  hintText: "Enter Mother's Name",
                  autoCapitalizeWords: true,
                  textCapitalization: TextCapitalization.words,
                ),

                DobInput(
                  label: "Date of Birth",
                  dayController: provider.dobDayController,
                  monthController: provider.dobMonthController,
                  yearController: provider.dobYearController,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
