import 'package:flutter/material.dart';

import '../models/api_student.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/authenticated_app_bar.dart';

class StudentHistoryScreen extends StatefulWidget {
  const StudentHistoryScreen({
    super.key,
    required this.schoolUuid,
    required this.studentUuid,
    required this.api,
  });

  final String schoolUuid;
  final String studentUuid;
  final ApiService api;

  @override
  State<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> {
  late Future<List<StudentAuditEvent>> _history;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _history = widget.api.getStudentHistory(
      schoolUuid: widget.schoolUuid,
      studentUuid: widget.studentUuid,
    );
  }

  String _title(String value) => value
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');

  String _change(StudentAuditEvent event) {
    if (event.fieldName == null) return 'Student record event';
    return '${event.fieldName}: ${event.oldValue ?? '—'} → ${event.newValue ?? '—'}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff5f7fb),
    appBar: const AuthenticatedAppBar(title: Text('Student History')),
    body: FutureBuilder<List<StudentAuditEvent>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Unable to load history: ${snapshot.error}'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => setState(_reload),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final events = snapshot.data ?? const [];
        if (events.isEmpty) {
          return const Center(child: Text('No history recorded yet.'));
        }
        return ListView.separated(
          key: const Key('student-history-timeline'),
          padding: const EdgeInsets.all(20),
          itemCount: events.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final event = events[index];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.history, size: 18),
                ),
                title: Text(_title(event.eventType)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_change(event)),
                    if (event.note?.isNotEmpty == true)
                      Text('Note: ${event.note}'),
                    Text(
                      '${event.actorName ?? 'System'} • ${event.createdAt.toLocal()}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
