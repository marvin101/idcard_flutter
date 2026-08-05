import 'package:flutter/material.dart';

import '../widgets/app_dropdown.dart';
import '../widgets/app_text_input.dart';
import '../widgets/responsive_row.dart';

class AcademicInformationSection extends StatelessWidget {
  const AcademicInformationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Academic Information",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            // Admission No. & Roll No.
            ResponsiveRow(
              children: [
                const AppTextInput(
                  label: "Admission No.",
                  hintText: "Enter Admission Number",
                ),
                const AppTextInput(
                  label: "Roll No.",
                  hintText: "Enter Roll Number",
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Class & Section
            ResponsiveRow(
              children: [
                const AppTextInput(label: "Class", hintText: "e.g. X"),
                const AppTextInput(label: "Section", hintText: "e.g. A"),
              ],
            ),

            const SizedBox(height: 20),

            // Stream & Session
            ResponsiveRow(
              children: [
                const AppTextInput(
                  label: "Stream",
                  hintText: "Science / Commerce / Arts",
                ),
                const AppTextInput(label: "Session", hintText: "2026-2027"),
              ],
            ),

            const SizedBox(height: 20),

            // Blood Group & House
            ResponsiveRow(
              children: [
                AppDropdown<String>(
                  label: "Blood Group",
                  value: null,
                  items: const [
                    DropdownMenuItem(value: "A+", child: Text("A+")),
                    DropdownMenuItem(value: "A-", child: Text("A-")),
                    DropdownMenuItem(value: "B+", child: Text("B+")),
                    DropdownMenuItem(value: "B-", child: Text("B-")),
                    DropdownMenuItem(value: "AB+", child: Text("AB+")),
                    DropdownMenuItem(value: "AB-", child: Text("AB-")),
                    DropdownMenuItem(value: "O+", child: Text("O+")),
                    DropdownMenuItem(value: "O-", child: Text("O-")),
                  ],
                  onChanged: (value) {},
                ),
                const AppTextInput(label: "House", hintText: "Optional"),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
