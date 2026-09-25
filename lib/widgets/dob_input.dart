import 'package:flutter/material.dart';

import 'dob_field.dart';

class DobInput extends StatefulWidget {
  const DobInput({
    super.key,
    required this.label,
    required this.dayController,
    required this.monthController,
    required this.yearController,
  });

  final String label;

  final TextEditingController dayController;
  final TextEditingController monthController;
  final TextEditingController yearController;

  @override
  State<DobInput> createState() => _DobInputState();
}

class _DobInputState extends State<DobInput> {
  final FocusNode dayFocus = FocusNode();
  final FocusNode monthFocus = FocusNode();
  final FocusNode yearFocus = FocusNode();

  @override
  void dispose() {
    dayFocus.dispose();
    monthFocus.dispose();
    yearFocus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final required = widget.label.trim().endsWith('*');

    final cleanLabel = required
        ? widget.label
              .trim()
              .substring(0, widget.label.trim().length - 1)
              .trim()
        : widget.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DobLabel(label: cleanLabel, requiredField: required),

        const SizedBox(height: 6),

        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 8.0;

            final usableWidth = constraints.maxWidth - (spacing * 2);

            // Give the year a little more room while allowing the three
            // controls to fit comfortably even on a 320 px phone viewport.
            final shortWidth = (usableWidth * 0.27).clamp(56.0, 92.0);

            final yearWidth = usableWidth - (shortWidth * 2);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: required
                      ? '$cleanLabel day, required'
                      : '$cleanLabel day',
                  textField: true,
                  child: DobField(
                    controller: widget.dayController,
                    focusNode: dayFocus,
                    nextFocus: monthFocus,
                    hint: 'DD',
                    maxLength: 2,
                    width: shortWidth,
                  ),
                ),

                const SizedBox(width: spacing),

                Semantics(
                  label: required
                      ? '$cleanLabel month, required'
                      : '$cleanLabel month',
                  textField: true,
                  child: DobField(
                    controller: widget.monthController,
                    focusNode: monthFocus,
                    nextFocus: yearFocus,
                    hint: 'MM',
                    maxLength: 2,
                    width: shortWidth,
                  ),
                ),

                const SizedBox(width: spacing),

                Semantics(
                  label: required
                      ? '$cleanLabel year, required'
                      : '$cleanLabel year',
                  textField: true,
                  child: DobField(
                    controller: widget.yearController,
                    focusNode: yearFocus,
                    hint: 'YYYY',
                    maxLength: 4,
                    width: yearWidth,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DobLabel extends StatelessWidget {
  const _DobLabel({required this.label, required this.requiredField});

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
