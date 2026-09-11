import 'package:flutter/material.dart';

import '../models/api_personnel.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/authenticated_app_bar.dart';

class PersonnelHistoryScreen extends StatefulWidget {
  const PersonnelHistoryScreen({
    super.key,
    required this.schoolUuid,
    required this.personnelUuid,
    required this.api,
  });

  final String schoolUuid;
  final String personnelUuid;
  final ApiService api;

  @override
  State<PersonnelHistoryScreen> createState() => _PersonnelHistoryScreenState();
}

class _PersonnelHistoryScreenState extends State<PersonnelHistoryScreen> {
  late Future<List<PersonnelAuditEvent>> _history;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _history = widget.api.getPersonnelHistory(
      schoolUuid: widget.schoolUuid,
      personnelUuid: widget.personnelUuid,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff5f7fb),
    appBar: const AuthenticatedAppBar(title: Text('Personnel History')),
    body: FutureBuilder<List<PersonnelAuditEvent>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh),
              label: Text('Retry: ${snapshot.error}'),
            ),
          );
        }
        final events = [...snapshot.data ?? const <PersonnelAuditEvent>[]]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (events.isEmpty) {
          return const Center(child: Text('No history recorded yet.'));
        }
        return ListView.separated(
          key: const Key('personnel-history-timeline'),
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
                title: Text(event.label),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.summary),
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
