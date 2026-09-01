import 'package:flutter/material.dart';

import '../models/api_student.dart';
import '../theme/app_colors.dart';
import 'student_lifecycle_badge.dart';

class StudentLifecycleSummary extends StatelessWidget {
  const StudentLifecycleSummary({super.key, required this.student});

  final ApiStudent student;

  String _when(DateTime? value) => value == null
      ? 'Not recorded'
      : value.toLocal().toString().replaceFirst(RegExp(r'\.\d+$'), '');

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('student-lifecycle-summary'),
    margin: EdgeInsets.zero,
    color: const Color(0xfff7f9fc),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0xffdfe4ec)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Card lifecycle',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              StudentLifecycleBadge(status: student.lifecycleStatus),
            ],
          ),
          if (student.correctionNote?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              'Correction note: ${student.correctionNote}',
              style: const TextStyle(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              Text(
                student.verifiedAt == null
                    ? 'Verified: Not yet'
                    : 'Verified by ${student.verifiedByName ?? 'Unknown user'} at ${_when(student.verifiedAt)}',
              ),
              Text(
                student.printedAt == null
                    ? 'Printed: Not yet'
                    : 'Last printed by ${student.printedByName ?? 'Unknown user'} at ${_when(student.printedAt)}',
              ),
              Text('Print count: ${student.printCount}'),
            ],
          ),
        ],
      ),
    ),
  );
}
