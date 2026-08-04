import 'package:flutter/material.dart';

class AppDropdown<T> extends StatelessWidget {
  final String label;

  final T? value;

  final List<DropdownMenuItem<T>> items;

  final ValueChanged<T?>? onChanged;

  final String? Function(T?)? validator;

  final bool requiredField;

  final bool enabled;

  final Widget? prefixIcon;

  final Widget? suffixIcon;

  const AppDropdown({
    super.key,
    required this.label,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.requiredField = false,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            children: [
              TextSpan(text: label),

              if (requiredField)
                const TextSpan(
                  text: " *",
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        DropdownButtonFormField<T>(
          initialValue: value,

          items: items,

          validator: validator,

          onChanged: enabled ? onChanged : null,

          decoration: InputDecoration(
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),

            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.indigo, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
