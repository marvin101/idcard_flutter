import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextInput extends StatelessWidget {
  final String label;

  final String? hintText;

  final TextEditingController? controller;

  final TextInputType keyboardType;

  final bool readOnly;

  final bool enabled;

  final bool obscureText;

  final bool requiredField;

  final int maxLines;

  final int? maxLength;

  final Widget? prefixIcon;

  final Widget? suffixIcon;

  final List<TextInputFormatter>? inputFormatters;

  final String? Function(String?)? validator;

  final void Function(String)? onChanged;

  final FocusNode? focusNode;

  final FocusNode? nextFocus;

  final TextInputAction textInputAction;

  const AppTextInput({
    super.key,
    required this.label,
    this.hintText,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.enabled = true,
    this.obscureText = false,
    this.requiredField = false,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.focusNode,
    this.nextFocus,
    this.textInputAction = TextInputAction.next,
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
              fontSize: 15,
              fontWeight: FontWeight.w600,
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

        TextFormField(
          controller: controller,
          focusNode: focusNode,

          keyboardType: keyboardType,

          textInputAction: textInputAction,

          obscureText: obscureText,

          readOnly: readOnly,

          enabled: enabled,

          maxLines: maxLines,

          maxLength: maxLength,

          validator: validator,

          inputFormatters: inputFormatters,

          decoration: InputDecoration(
            hintText: hintText,

            prefixIcon: prefixIcon,

            suffixIcon: suffixIcon,

            counterText: "",

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

          onChanged: onChanged,

          onFieldSubmitted: (_) {
            if (nextFocus != null) {
              FocusScope.of(context).requestFocus(nextFocus);
            }
          },
        ),
      ],
    );
  }
}
