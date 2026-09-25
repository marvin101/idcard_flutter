import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/academic_session.dart';
import '../models/school_class.dart';
import '../models/section.dart';
import '../models/student_field.dart';
import '../providers/api_student_form_provider.dart';
import '../utils/validators.dart';
import '../widgets/dob_input.dart';

class BuiltinStudentFieldsSection extends StatelessWidget {
  const BuiltinStudentFieldsSection({super.key});

  static const double _mobileBreakpoint = 700;

  /// At roughly a 360 px viewport there is enough usable width for Class and
  /// Section to share a row. Narrower phones fall back to stacked controls.
  static const double _classSectionRowBreakpoint = 300;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ApiStudentFormProvider>();

    if (provider.loading) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (provider.error != null) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(provider.error!),
        ),
      );
    }

    final fields =
        provider.builtinFields.where((field) => field.enabled).toList()..sort(
          (left, right) => left.displayOrder.compareTo(right.displayOrder),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _mobileBreakpoint;

        final theme = Theme.of(context);

        return Card(
          margin: EdgeInsets.zero,
          elevation: compact ? 0 : 2,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 14 : 20),
            side: compact
                ? BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.20),
                  )
                : BorderSide.none,
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student information',
                  style: compact
                      ? theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        )
                      : theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                ),

                SizedBox(height: compact ? 4 : 6),

                Text(
                  'Academic and personal details',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

                SizedBox(height: compact ? 18 : 24),

                _buildFields(
                  provider,
                  fields,
                  compact: compact,
                  availableWidth: constraints.maxWidth - (compact ? 32 : 48),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFields(
    ApiStudentFormProvider provider,
    List<BuiltinStudentField> fields, {
    required bool compact,
    required double availableWidth,
  }) {
    if (!compact) {
      return _buildDesktopFields(provider, fields);
    }

    return _buildMobileFields(provider, fields, availableWidth: availableWidth);
  }

  Widget _buildDesktopFields(
    ApiStudentFormProvider provider,
    List<BuiltinStudentField> fields,
  ) {
    final rows = <Widget>[];

    for (var index = 0; index < fields.length; index += 2) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _field(provider, fields[index])),
            const SizedBox(width: 20),
            Expanded(
              child: index + 1 < fields.length
                  ? _field(provider, fields[index + 1])
                  : const SizedBox(),
            ),
          ],
        ),
      );

      if (index + 2 < fields.length) {
        rows.add(const SizedBox(height: 20));
      }
    }

    return Column(children: rows);
  }

  Widget _buildMobileFields(
    ApiStudentFormProvider provider,
    List<BuiltinStudentField> fields, {
    required double availableWidth,
  }) {
    final children = <Widget>[];

    var index = 0;

    while (index < fields.length) {
      final current = fields[index];

      final hasNext = index + 1 < fields.length;

      final next = hasNext ? fields[index + 1] : null;

      final canPairClassAndSection =
          availableWidth >= _classSectionRowBreakpoint &&
          current.key == 'class_uuid' &&
          next?.key == 'section_uuid';

      if (canPairClassAndSection) {
        children.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _field(provider, current)),
              const SizedBox(width: 12),
              Expanded(child: _field(provider, next!)),
            ],
          ),
        );

        index += 2;
      } else {
        children.add(_field(provider, current));

        index++;
      }

      if (index < fields.length) {
        children.add(const SizedBox(height: 12));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _field(ApiStudentFormProvider provider, BuiltinStudentField field) {
    String? required(String? value) =>
        field.required ? Validators.required(value, field.label) : null;

    switch (field.key) {
      case 'session_uuid':
        return _StudentDropdown<String>(
          label: field.label,
          value: provider.selectedSessionUuid,
          requiredField: field.required,
          hintText: 'Select ${field.label}',
          items: provider.sessions
              .map(
                (AcademicSession item) => DropdownMenuItem<String>(
                  value: item.uuid,
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: provider.setSession,
          validator: (value) => value == null || value.isEmpty
              ? '${field.label} is required'
              : null,
        );

      case 'class_uuid':
        return _StudentDropdown<String>(
          label: field.label,
          value: provider.selectedClassUuid,
          requiredField: field.required,
          hintText: 'Select class',
          items: provider.classes
              .map(
                (SchoolClass item) => DropdownMenuItem<String>(
                  value: item.uuid,
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: provider.setClass,
          validator: (value) => value == null || value.isEmpty
              ? '${field.label} is required'
              : null,
        );

      case 'section_uuid':
        return _StudentDropdown<String>(
          label: field.label,
          value: provider.selectedSectionUuid,
          requiredField: field.required,
          enabled:
              provider.selectedClassUuid != null && !provider.loadingSections,
          hintText: provider.selectedClassUuid == null
              ? 'Class first'
              : provider.loadingSections
              ? 'Loading...'
              : 'Select section',
          items: provider.sections
              .map(
                (SchoolSection item) => DropdownMenuItem<String>(
                  value: item.uuid,
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                ),
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
        return _StudentDropdown<String>(
          label: field.label,
          value: provider.selectedGender,
          requiredField: field.required,
          hintText: 'Select gender',
          items: const [
            DropdownMenuItem<String>(value: 'Male', child: Text('Male')),
            DropdownMenuItem<String>(value: 'Female', child: Text('Female')),
            DropdownMenuItem<String>(value: 'Other', child: Text('Other')),
          ],
          onChanged: provider.setGender,
          validator: required,
        );

      case 'blood_group':
        return _StudentDropdown<String>(
          label: field.label,
          value: provider.selectedBloodGroup,
          requiredField: field.required,
          hintText: 'Select blood group',
          items: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
              .map(
                (value) =>
                    DropdownMenuItem<String>(value: value, child: Text(value)),
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

            if (requiredError != null) {
              return requiredError;
            }

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

            if (requiredError != null) {
              return requiredError;
            }

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
  }) {
    return _StudentTextInput(
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
}

class _StudentTextInput extends StatelessWidget {
  const _StudentTextInput({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.requiredField,
    required this.validator,
    required this.textCapitalization,
    required this.autoCapitalizeWords,
    required this.keyboardType,
    required this.maxLines,
    this.maxLength,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool requiredField;

  final String? Function(String?)? validator;

  final TextCapitalization textCapitalization;

  final bool autoCapitalizeWords;

  final TextInputType keyboardType;

  final int maxLines;
  final int? maxLength;

  final List<TextInputFormatter>? inputFormatters;

  String _capitalizeWords(String text) {
    return text.replaceAllMapped(RegExp(r'[A-Za-z]+'), (match) {
      final word = match.group(0)!;

      if (word.isEmpty) {
        return word;
      }

      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: requiredField ? '$label, required' : label,
      textField: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label, requiredField: requiredField),

          const SizedBox(height: 6),

          TextFormField(
            controller: controller,
            keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
            textCapitalization: textCapitalization,
            textInputAction: maxLines > 1
                ? TextInputAction.newline
                : TextInputAction.next,
            maxLines: maxLines,
            maxLength: maxLength,
            validator: validator,
            inputFormatters: inputFormatters,
            style: const TextStyle(fontSize: 16, height: 1.2),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.65,
                ),
              ),
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.65),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.colorScheme.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.colorScheme.error,
                  width: 2,
                ),
              ),
            ),
            onChanged: (value) {
              if (!autoCapitalizeWords) {
                return;
              }

              final selection = controller.selection;

              final capitalized = _capitalizeWords(value);

              if (capitalized == value) {
                return;
              }

              controller.value = TextEditingValue(
                text: capitalized,
                selection: TextSelection.collapsed(
                  offset: selection.baseOffset.clamp(0, capitalized.length),
                ),
              );
            },
            onFieldSubmitted: (_) {
              if (maxLines == 1) {
                FocusScope.of(context).nextFocus();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _StudentDropdown<T> extends StatelessWidget {
  const _StudentDropdown({
    required this.label,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.requiredField = false,
    this.enabled = true,
    this.hintText,
  });

  final String label;

  final T? value;

  final List<DropdownMenuItem<T>> items;

  final ValueChanged<T?>? onChanged;

  final String? Function(T?)? validator;

  final bool requiredField;
  final bool enabled;

  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: requiredField ? '$label, required' : label,
      enabled: enabled,
      button: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label, requiredField: requiredField),

          const SizedBox(height: 6),

          DropdownButtonFormField<T>(
            initialValue: value,
            items: items,
            validator: validator,
            onChanged: enabled ? onChanged : null,
            isExpanded: true,
            isDense: true,
            hint: hintText == null
                ? null
                : Text(hintText!, overflow: TextOverflow.ellipsis),
            style: TextStyle(
              fontSize: 16,
              height: 1.2,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: enabled
                  ? theme.colorScheme.surface
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.55,
                    ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.65),
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.30),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.colorScheme.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.colorScheme.error,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.requiredField});

  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),

        if (requiredField) ...[
          const SizedBox(width: 3),

          Semantics(
            label: 'required',
            child: ExcludeSemantics(
              child: Text(
                '*',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
