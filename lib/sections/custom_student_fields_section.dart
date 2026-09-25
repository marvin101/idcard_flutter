import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/student_field.dart';
import '../providers/api_student_form_provider.dart';

class CustomStudentFieldsSection extends StatelessWidget {
  const CustomStudentFieldsSection({super.key});

  static const double _mobileBreakpoint = 700;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ApiStudentFormProvider>();

    if (provider.customFields.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _mobileBreakpoint;
        final theme = Theme.of(context);

        return Card(
          margin: EdgeInsets.zero,
          elevation: compact ? 0 : 1,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 14 : 16),
            side: compact
                ? BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.20),
                  )
                : BorderSide.none,
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Additional information',
                  style: compact
                      ? theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        )
                      : theme.textTheme.titleLarge,
                ),
                SizedBox(height: compact ? 4 : 6),
                Text(
                  'School-specific student details',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: compact ? 18 : 20),
                for (
                  var index = 0;
                  index < provider.customFields.length;
                  index++
                ) ...[
                  _DynamicField(
                    field: provider.customFields[index],
                    controller:
                        provider.customFieldControllers[provider
                            .customFields[index]
                            .uuid]!,
                  ),
                  if (index != provider.customFields.length - 1)
                    SizedBox(height: compact ? 14 : 16),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DynamicField extends StatelessWidget {
  const _DynamicField({required this.field, required this.controller});

  final StudentFieldDefinition field;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final multiline = field.dataType == 'multiline';

    return Semantics(
      label: field.isRequired ? '${field.label}, required' : field.label,
      textField: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: field.label, requiredField: field.isRequired),
          const SizedBox(height: 6),
          if (field.dataType == 'date')
            _buildDateField(context)
          else
            TextFormField(
              key: ValueKey('custom-field-${field.uuid}'),
              controller: controller,
              validator: _validate,
              keyboardType: _keyboardType(),
              textInputAction: multiline
                  ? TextInputAction.newline
                  : TextInputAction.next,
              maxLines: multiline ? 4 : 1,
              inputFormatters: _inputFormatters(),
              style: const TextStyle(fontSize: 16, height: 1.2),
              decoration: _decoration(context, hintText: _hintText()),
              onFieldSubmitted: multiline
                  ? null
                  : (_) {
                      FocusScope.of(context).nextFocus();
                    },
            ),
        ],
      ),
    );
  }

  Widget _buildDateField(BuildContext context) {
    return TextFormField(
      key: ValueKey('custom-field-${field.uuid}'),
      controller: controller,
      readOnly: true,
      validator: _validate,
      style: const TextStyle(fontSize: 16, height: 1.2),
      decoration: _decoration(
        context,
        hintText: 'Select ${field.label}',
        suffixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      onTap: () async {
        final current = DateTime.tryParse(controller.text);

        final picked = await showDatePicker(
          context: context,
          initialDate: current ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2200),
          helpText: 'Select ${field.label}',
        );

        if (picked == null) {
          return;
        }

        controller.text =
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
      },
    );
  }

  InputDecoration _decoration(
    BuildContext context, {
    required String hintText,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
      ),
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.65),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
      ),
    );
  }

  TextInputType _keyboardType() {
    switch (field.dataType) {
      case 'number':
        return const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        );

      case 'phone':
        return TextInputType.phone;

      case 'multiline':
        return TextInputType.multiline;

      default:
        return TextInputType.text;
    }
  }

  List<TextInputFormatter>? _inputFormatters() {
    if (field.dataType != 'number') {
      return null;
    }

    return [FilteringTextInputFormatter.allow(RegExp(r'[-+0-9.]'))];
  }

  String _hintText() {
    switch (field.dataType) {
      case 'phone':
        return 'Enter ${field.label}';

      case 'number':
        return 'Enter ${field.label}';

      case 'multiline':
        return 'Enter ${field.label}';

      default:
        return 'Enter ${field.label}';
    }
  }

  String? _validate(String? input) {
    final value = input?.trim() ?? '';

    if (field.isRequired && value.isEmpty) {
      return '${field.label} is required.';
    }

    if (value.isEmpty) {
      return null;
    }

    if (field.dataType == 'number' && double.tryParse(value) == null) {
      return 'Enter a valid number.';
    }

    if (field.dataType == 'date' && DateTime.tryParse(value) == null) {
      return 'Enter a valid date.';
    }

    if (field.dataType == 'phone') {
      final digits = value.replaceAll(RegExp(r'\D'), '');

      if (digits.length < 5 || digits.length > 25) {
        return 'Enter a valid phone number.';
      }
    }

    return null;
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
