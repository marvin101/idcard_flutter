import 'package:flutter/material.dart';

import '../widgets/app_text_input.dart';
import '../widgets/dob_input.dart';

class PersonalInformationSection extends StatelessWidget {
  const PersonalInformationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Personal Information",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 25),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextInput(label: "Full Name", requiredField: true),
            ),

            const SizedBox(width: 20),

            Expanded(child: AppTextInput(label: "Father Name")),
          ],
        ),

        const SizedBox(height: 20),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: AppTextInput(label: "Mother Name")),

            const SizedBox(width: 20),

            Expanded(child: DobInput(label: "Date of Birth")),
          ],
        ),
      ],
    );
  }
}
