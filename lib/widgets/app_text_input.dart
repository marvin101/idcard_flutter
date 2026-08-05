import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextInput extends StatelessWidget {
  final String label;

  final String? hintText;

  final TextEditingController? controller;

  final TextInputType keyboardType;

  final TextCapitalization textCapitalization;

  final bool autoCapitalizeWords;

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
    this.textCapitalization = TextCapitalization.none,
    this.autoCapitalizeWords = false,
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

  String _capitalizeWords(String text) {
    if (text.trim().isEmpty) return text;

    return text.split(RegExp(r'(\s+)')).map((part) {
      if (part.trim().isEmpty) return part;

      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).join();
  }

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
          textCapitalization: textCapitalization,
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

          onChanged: (value) {
            if (autoCapitalizeWords && controller != null) {
              final selection = controller!.selection;
              final capitalized = _capitalizeWords(value);

              if (capitalized != value) {
                controller!.value = TextEditingValue(
                  text: capitalized,
                  selection: TextSelection.collapsed(
                    offset: selection.baseOffset.clamp(0, capitalized.length),
                  ),
                );
              }
            }

            if (onChanged != null) {
              onChanged!(controller?.text ?? value);
            }
          },

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
