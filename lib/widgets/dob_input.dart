import 'package:flutter/material.dart';
import 'dob_field.dart';

class DobInput extends StatefulWidget {
  final String label;

  const DobInput({super.key, required this.label});

  @override
  State<DobInput> createState() => _DobInputState();
}

class _DobInputState extends State<DobInput> {
  // Controllers
  final TextEditingController dayController = TextEditingController();
  final TextEditingController monthController = TextEditingController();
  final TextEditingController yearController = TextEditingController();

  // Focus Nodes
  final FocusNode dayFocus = FocusNode();
  final FocusNode monthFocus = FocusNode();
  final FocusNode yearFocus = FocusNode();

  @override
  void dispose() {
    dayController.dispose();
    monthController.dispose();
    yearController.dispose();

    dayFocus.dispose();
    monthFocus.dispose();
    yearFocus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            DobField(
              controller: dayController,
              focusNode: dayFocus,
              nextFocus: monthFocus,
              hint: "DD",
              maxLength: 2,
            ),

            const SizedBox(width: 12),

            DobField(
              controller: monthController,
              focusNode: monthFocus,
              nextFocus: yearFocus,
              hint: "MM",
              maxLength: 2,
            ),

            const SizedBox(width: 12),

            DobField(
              controller: yearController,
              focusNode: yearFocus,
              hint: "YYYY",
              maxLength: 4,
              width: 110,
            ),
          ],
        ),
      ],
    );
  }
}
