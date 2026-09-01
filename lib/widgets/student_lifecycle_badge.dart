import 'package:flutter/material.dart';

class StudentLifecycleBadge extends StatelessWidget {
  const StudentLifecycleBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'needs_correction' => ('Needs Correction', Colors.orange.shade800),
      'verified' || 'ready_for_print' => ('Verified', Colors.green.shade700),
      'printed' => ('Printed', Colors.blue.shade700),
      _ => ('Pending', Colors.grey.shade700),
    };
    return Semantics(
      label: 'Lifecycle status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
