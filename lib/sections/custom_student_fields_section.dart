import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/student_field.dart';
import '../providers/api_student_form_provider.dart';

class CustomStudentFieldsSection extends StatelessWidget {
  const CustomStudentFieldsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ApiStudentFormProvider>();
    if (provider.customFields.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Additional Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            for (final field in provider.customFields) ...[
              _DynamicField(
                field: field,
                controller: provider.customFieldControllers[field.uuid]!,
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _DynamicField extends StatelessWidget {
  const _DynamicField({required this.field, required this.controller});

  final StudentFieldDefinition field;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final decoration = InputDecoration(
      labelText: field.label,
      helperText: field.isRequired ? 'Required' : null,
    );
    if (field.dataType == 'date') {
      return TextFormField(
        key: ValueKey('custom-field-${field.uuid}'),
        controller: controller,
        readOnly: true,
        decoration: decoration.copyWith(suffixIcon: const Icon(Icons.event)),
        validator: _validate,
        onTap: () async {
          final current = DateTime.tryParse(controller.text);
          final picked = await showDatePicker(
            context: context,
            initialDate: current ?? DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime(2200),
          );
          if (picked != null) {
            controller.text =
                '${picked.year.toString().padLeft(4, '0')}-'
                '${picked.month.toString().padLeft(2, '0')}-'
                '${picked.day.toString().padLeft(2, '0')}';
          }
        },
      );
    }
    return TextFormField(
      key: ValueKey('custom-field-${field.uuid}'),
      controller: controller,
      decoration: decoration,
      validator: _validate,
      keyboardType: switch (field.dataType) {
        'number' => const TextInputType.numberWithOptions(decimal: true, signed: true),
        'phone' => TextInputType.phone,
        _ => TextInputType.text,
      },
      maxLines: field.dataType == 'multiline' ? 4 : 1,
      inputFormatters: field.dataType == 'number'
          ? [FilteringTextInputFormatter.allow(RegExp(r'[-+0-9.]'))]
          : null,
    );
  }

  String? _validate(String? input) {
    final value = input?.trim() ?? '';
    if (field.isRequired && value.isEmpty) return '${field.label} is required.';
    if (value.isEmpty) return null;
    if (field.dataType == 'number' && double.tryParse(value) == null) {
      return 'Enter a valid number.';
    }
    if (field.dataType == 'date' && DateTime.tryParse(value) == null) {
      return 'Enter a valid date.';
    }
    if (field.dataType == 'phone') {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 5 || digits.length > 25) return 'Enter a valid phone number.';
    }
    return null;
  }
}
