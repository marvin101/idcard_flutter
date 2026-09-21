import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/api_student_form_provider.dart';
import '../widgets/app_text_input.dart';
import '../widgets/responsive_row.dart';

class ContactInformationSection extends StatelessWidget {
  const ContactInformationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ApiStudentFormProvider>();

    if (!provider.isFieldEnabled('mobile') &&
        !provider.isFieldEnabled('aadhaar') &&
        !provider.isFieldEnabled('address')) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Contact Information",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            ResponsiveRow(
              children: [
                if (provider.isFieldEnabled('mobile'))
                  AppTextInput(
                    controller: provider.mobileController,
                    label: "Mobile No.",
                    hintText: "10-digit mobile number",
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    requiredField: provider.isFieldRequired('mobile'),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return provider.isFieldRequired('mobile')
                            ? "Mobile number is required"
                            : null;
                      }

                      if (value.length != 10) {
                        return "Enter a valid 10-digit mobile number";
                      }

                      return null;
                    },
                  ),

                if (provider.isFieldEnabled('aadhaar'))
                  AppTextInput(
                    controller: provider.aadhaarController,
                    label: "Aadhaar No.",
                    hintText: "12-digit Aadhaar number",
                    keyboardType: TextInputType.number,
                    maxLength: 12,
                    requiredField: provider.isFieldRequired('aadhaar'),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return provider.isFieldRequired('aadhaar')
                            ? 'Aadhaar is required'
                            : null;
                      }

                      if (value.length != 12) {
                        return "Aadhaar must contain 12 digits";
                      }

                      return null;
                    },
                  ),
              ],
            ),

            const SizedBox(height: 20),

            if (provider.isFieldEnabled('address'))
              AppTextInput(
                controller: provider.addressController,
                label: "Address",
                hintText: "House No., Street, City, State, PIN",
                requiredField: provider.isFieldRequired('address'),
                validator: provider.isFieldRequired('address')
                    ? (value) => value == null || value.trim().isEmpty
                          ? 'Address is required'
                          : null
                    : null,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
          ],
        ),
      ),
    );
  }
}
