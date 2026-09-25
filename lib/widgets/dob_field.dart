import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DobField extends StatelessWidget {
  const DobField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.nextFocus,
    required this.hint,
    required this.maxLength,
    this.width = 80,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocus;

  final String hint;
  final int maxLength;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textInputAction: nextFocus != null
            ? TextInputAction.next
            : TextInputAction.done,
        textAlign: TextAlign.center,
        maxLength: maxLength,
        style: const TextStyle(fontSize: 16, height: 1.2),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLength),
        ],
        onChanged: (value) {
          if (value.length == maxLength && nextFocus != null) {
            nextFocus!.requestFocus();
          }
        },
        onSubmitted: (_) {
          if (nextFocus != null) {
            nextFocus!.requestFocus();
          } else {
            FocusScope.of(context).unfocus();
          }
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
          ),
          counterText: '',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 13,
          ),
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
        ),
      ),
    );
  }
}
