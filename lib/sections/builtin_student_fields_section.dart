import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/academic_session.dart';
import '../models/school_class.dart';
import '../models/section.dart';
import '../models/student_field.dart';
import '../providers/api_student_form_provider.dart';
import '../utils/validators.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/app_text_input.dart';
import '../widgets/dob_input.dart';
import '../widgets/responsive_row.dart';

class BuiltinStudentFieldsSection extends StatelessWidget {
  const BuiltinStudentFieldsSection({super.key});

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
          child: Text(provider.error!),
        ),
      );
    }

    final fields =
        provider.builtinFields.where((field) => field.enabled).toList()..sort(
          (left, right) => left.displayOrder.compareTo(right.displayOrder),
        );
    final rows = <Widget>[];
    for (var index = 0; index < fields.length; index += 2) {
      rows.add(
        ResponsiveRow(
          children: [
            _field(provider, fields[index]),
            if (index + 1 < fields.length)
              _field(provider, fields[index + 1])
            else
              const SizedBox(),
          ],
        ),
      );
      if (index + 2 < fields.length) rows.add(const SizedBox(height: 20));
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
              'Student Information',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _field(ApiStudentFormProvider provider, BuiltinStudentField field) {
    String? required(String? value) =>
        field.required ? Validators.required(value, field.label) : null;
    switch (field.key) {
      case 'session_uuid':
        return AppDropdown<String>(
          label: field.label,
          value: provider.selectedSessionUuid,
          requiredField: field.required,
          items: provider.sessions
              .map(
                (AcademicSession item) =>
                    DropdownMenuItem(value: item.uuid, child: Text(item.name)),
              )
              .toList(),
          onChanged: provider.setSession,
          validator: (value) => value == null || value.isEmpty
              ? '${field.label} is required'
              : null,
        );
      case 'class_uuid':
        return AppDropdown<String>(
          label: field.label,
          value: provider.selectedClassUuid,
          requiredField: field.required,
          items: provider.classes
              .map(
                (SchoolClass item) =>
                    DropdownMenuItem(value: item.uuid, child: Text(item.name)),
              )
              .toList(),
          onChanged: provider.setClass,
          validator: (value) => value == null || value.isEmpty
              ? '${field.label} is required'
              : null,
        );
      case 'section_uuid':
        return AppDropdown<String>(
          label: field.label,
          value: provider.selectedSectionUuid,
          requiredField: field.required,
          enabled:
              provider.selectedClassUuid != null && !provider.loadingSections,
          items: provider.sections
              .map(
                (SchoolSection item) =>
                    DropdownMenuItem(value: item.uuid, child: Text(item.name)),
              )
              .toList(),
          onChanged: provider.setSection,
          validator: (value) => value == null || value.isEmpty
              ? '${field.label} is required'
              : null,
        );
      case 'admission_no':
        return _text(
          field,
          provider.admissionNoController,
          validator: required,
        );
      case 'full_name':
        return _text(
          field,
          provider.fullNameController,
          validator: required,
          capitalization: TextCapitalization.words,
          autoCapitalizeWords: true,
        );
      case 'roll_no':
        return _text(field, provider.rollNoController, validator: required);
      case 'stream':
        return _text(field, provider.streamController, validator: required);
      case 'father_name':
        return _text(
          field,
          provider.fatherNameController,
          validator: required,
          capitalization: TextCapitalization.words,
          autoCapitalizeWords: true,
        );
      case 'mother_name':
        return _text(
          field,
          provider.motherNameController,
          validator: required,
          capitalization: TextCapitalization.words,
          autoCapitalizeWords: true,
        );
      case 'dob':
        return DobInput(
          label: field.required ? '${field.label} *' : field.label,
          dayController: provider.dobDayController,
          monthController: provider.dobMonthController,
          yearController: provider.dobYearController,
        );
      case 'gender':
        return AppDropdown<String>(
          label: field.label,
          value: provider.selectedGender,
          requiredField: field.required,
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: provider.setGender,
          validator: required,
        );
      case 'blood_group':
        return AppDropdown<String>(
          label: field.label,
          value: provider.selectedBloodGroup,
          requiredField: field.required,
          items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: provider.setBloodGroup,
          validator: required,
        );
      case 'mobile':
        return _text(
          field,
          provider.mobileController,
          validator: (value) {
            final requiredError = required(value);
            if (requiredError != null) return requiredError;
            if (value != null && value.isNotEmpty && value.length != 10) {
              return 'Enter a valid 10-digit mobile number';
            }
            return null;
          },
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        );
      case 'aadhaar':
        return _text(
          field,
          provider.aadhaarController,
          validator: (value) {
            final requiredError = required(value);
            if (requiredError != null) return requiredError;
            if (value != null && value.isNotEmpty && value.length != 12) {
              return 'Aadhaar must contain 12 digits';
            }
            return null;
          },
          keyboardType: TextInputType.number,
          maxLength: 12,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        );
      case 'address':
        return _text(
          field,
          provider.addressController,
          validator: required,
          maxLines: 3,
          capitalization: TextCapitalization.sentences,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _text(
    BuiltinStudentField field,
    TextEditingController controller, {
    String? Function(String?)? validator,
    TextCapitalization capitalization = TextCapitalization.none,
    bool autoCapitalizeWords = false,
    TextInputType? keyboardType,
    int? maxLength,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) => AppTextInput(
    controller: controller,
    label: field.label,
    hintText: 'Enter ${field.label}',
    requiredField: field.required,
    validator: validator,
    textCapitalization: capitalization,
    autoCapitalizeWords: autoCapitalizeWords,
    keyboardType: keyboardType ?? TextInputType.text,
    maxLength: maxLength,
    maxLines: maxLines,
    inputFormatters: inputFormatters,
  );
}
