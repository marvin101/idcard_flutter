import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DobField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocus;

  final String hint;
  final int maxLength;
  final double width;

  const DobField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.nextFocus,
    required this.hint,
    required this.maxLength,
    this.width = 80,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: maxLength,

        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLength),
        ],

        onChanged: (value) {
          if (value.length == maxLength && nextFocus != null) {
            nextFocus!.requestFocus();
          }
        },

        decoration: InputDecoration(
          hintText: hint,
          counterText: "",
          contentPadding: const EdgeInsets.symmetric(vertical: 16),

          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
