import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/api_personnel.dart';
import '../navigation/app_navigation.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/authenticated_app_bar.dart';
import '../widgets/student_lifecycle_badge.dart';

class PersonnelScreen extends StatefulWidget {
  const PersonnelScreen({
    super.key,
    required this.schoolUuid,
    required this.schoolName,
    required this.api,
    required this.personnelType,
    required this.canEdit,
    required this.canDelete,
    required this.canVerify,
    required this.canViewHistory,
    required this.canMarkPrinted,
  });

  final String schoolUuid;
  final String schoolName;
  final ApiService api;
  final PersonnelType personnelType;
  final bool canEdit;
  final bool canDelete;
  final bool canVerify;
  final bool canViewHistory;
  final bool canMarkPrinted;

  @override
  State<PersonnelScreen> createState() => _PersonnelScreenState();
}

class _PersonnelScreenState extends State<PersonnelScreen> {
  final _search = TextEditingController();
  final Set<String> _selected = {};
  List<ApiPersonnel> _records = const [];
  String? _verificationStatus;
  bool? _printed;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PersonnelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.personnelType != widget.personnelType ||
        oldWidget.schoolUuid != widget.schoolUuid) {
      _selected.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.api.getPersonnel(
        schoolUuid: widget.schoolUuid,
        personnelType: widget.personnelType,
        search: _search.text,
        verificationStatus: _verificationStatus,
        printed: _printed,
        limit: 500,
      );
      if (!mounted) return;
      setState(() {
        _records = page.items;
        _selected.removeWhere(
          (uuid) => !_records.any((item) => item.uuid == uuid),
        );
        _loading = false;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openForm([ApiPersonnel? personnel]) async {
    final route = personnel == null
        ? widget.personnelType == PersonnelType.teacher
              ? AppRoutes.addTeacher
              : AppRoutes.addStaff
        : AppRoutes.editPersonnel;
    final changed = await AppNavigation.navigateToWorkflow<bool>(
      context,
      route,
      arguments: personnel,
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _delete(ApiPersonnel personnel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${personnel.fullName}?'),
        content: const Text(
          'This record will be deactivated and removed from active lists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.deletePersonnel(
        schoolUuid: widget.schoolUuid,
        personnelUuid: personnel.uuid,
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    }
  }

  Future<void> _verify(ApiPersonnel personnel) async {
    await _lifecycle(
      () => widget.api.updatePersonnelVerification(
        schoolUuid: widget.schoolUuid,
        personnelUuid: personnel.uuid,
        status: 'verified',
      ),
    );
  }

  Future<void> _needsCorrection(ApiPersonnel personnel) async {
    final controller = TextEditingController(text: personnel.correctionNote);
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Needs Correction'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Correction note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;
    await _lifecycle(
      () => widget.api.updatePersonnelVerification(
        schoolUuid: widget.schoolUuid,
        personnelUuid: personnel.uuid,
        status: 'needs_correction',
        note: note,
      ),
    );
  }

  Future<void> _markPrinted(ApiPersonnel personnel) async {
    await _lifecycle(
      () => widget.api.markPersonnelPrinted(
        schoolUuid: widget.schoolUuid,
        personnelUuid: personnel.uuid,
      ),
    );
  }

  Future<void> _lifecycle(Future<ApiPersonnel> Function() action) async {
    try {
      await action();
      await _load();
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    }
  }

  Future<void> _runBatch(bool verify) async {
    try {
      if (verify) {
        await widget.api.batchVerifyPersonnel(
          schoolUuid: widget.schoolUuid,
          personnelUuids: _selected.toList(),
        );
      } else {
        await widget.api.batchMarkPersonnelPrinted(
          schoolUuid: widget.schoolUuid,
          personnelUuids: _selected.toList(),
        );
      }
      _selected.clear();
      await _load();
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(value), backgroundColor: AppColors.danger),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff5f7fb),
    appBar: AuthenticatedAppBar(
      title: Text('${widget.personnelType.pluralLabel} — ${widget.schoolName}'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 360,
                    child: TextField(
                      controller: _search,
                      onSubmitted: (_) => _load(),
                      decoration: InputDecoration(
                        hintText:
                            'Search name, employee number, designation or department',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          onPressed: _load,
                          icon: const Icon(Icons.arrow_forward),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  _dropdown<String>(
                    label: 'Verification',
                    value: _verificationStatus,
                    items: const {
                      null: 'All statuses',
                      'pending': 'Pending',
                      'needs_correction': 'Needs Correction',
                      'verified': 'Verified',
                    },
                    onChanged: (value) {
                      setState(() => _verificationStatus = value);
                      _load();
                    },
                  ),
                  _dropdown<bool>(
                    label: 'Printed',
                    value: _printed,
                    items: const {
                      null: 'All records',
                      false: 'Not printed',
                      true: 'Printed',
                    },
                    onChanged: (value) {
                      setState(() => _printed = value);
                      _load();
                    },
                  ),
                  if (widget.canEdit)
                    FilledButton.icon(
                      onPressed: () => _openForm(),
                      icon: const Icon(Icons.person_add_alt),
                      label: Text('Add ${widget.personnelType.label}'),
                    ),
                  if (_selected.isNotEmpty && widget.canVerify)
                    FilledButton.icon(
                      onPressed:
                          _selected.every(
                            (uuid) => !_records
                                .firstWhere((item) => item.uuid == uuid)
                                .isVerified,
                          )
                          ? () => _runBatch(true)
                          : null,
                      icon: const Icon(Icons.verified_outlined),
                      label: Text('Verify (${_selected.length})'),
                    ),
                  if (_selected.isNotEmpty && widget.canMarkPrinted)
                    OutlinedButton.icon(
                      onPressed:
                          _selected.every(
                            (uuid) => _records
                                .firstWhere((item) => item.uuid == uuid)
                                .isVerified,
                          )
                          ? () => _runBatch(false)
                          : null,
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Mark Printed'),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(child: _content()),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(_error!),
        ),
      );
    }
    if (_records.isEmpty) {
      return Center(
        child: Text(
          'No ${widget.personnelType.pluralLabel.toLowerCase()} found.',
        ),
      );
    }
    return Card(
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: _records.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final personnel = _records[index];
          return ListTile(
            leading: Checkbox(
              value: _selected.contains(personnel.uuid),
              onChanged: widget.canVerify || widget.canMarkPrinted
                  ? (selected) => setState(
                      () => selected == true
                          ? _selected.add(personnel.uuid)
                          : _selected.remove(personnel.uuid),
                    )
                  : null,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    personnel.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                StudentLifecycleBadge(status: personnel.lifecycleStatus),
              ],
            ),
            subtitle: Text(
              'Employee: ${personnel.employeeNo}'
              '${personnel.designation == null ? '' : ' • ${personnel.designation}'}'
              '${personnel.department == null ? '' : ' • ${personnel.department}'}'
              '${personnel.correctionNote == null ? '' : '\nCorrection: ${personnel.correctionNote}'}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') _openForm(personnel);
                if (action == 'delete') _delete(personnel);
                if (action == 'verify') _verify(personnel);
                if (action == 'correction') _needsCorrection(personnel);
                if (action == 'printed') _markPrinted(personnel);
                if (action == 'history') {
                  AppNavigation.navigateToPage<void>(
                    context,
                    AppRoutes.personnelHistory(personnel.uuid),
                  );
                }
              },
              itemBuilder: (_) => [
                if (widget.canEdit)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (widget.canDelete)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                if (widget.canVerify && !personnel.isVerified)
                  const PopupMenuItem(value: 'verify', child: Text('Verify')),
                if (widget.canVerify)
                  const PopupMenuItem(
                    value: 'correction',
                    child: Text('Needs Correction'),
                  ),
                if (widget.canMarkPrinted && personnel.isVerified)
                  PopupMenuItem(
                    value: 'printed',
                    child: Text(
                      personnel.isPrinted ? 'Record Reprint' : 'Mark Printed',
                    ),
                  ),
                if (widget.canViewHistory)
                  const PopupMenuItem(value: 'history', child: Text('History')),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required Map<T?, String> items,
    required ValueChanged<T?> onChanged,
  }) => SizedBox(
    width: 190,
    child: DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.entries
          .map(
            (entry) =>
                DropdownMenuItem<T>(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      onChanged: onChanged,
    ),
  );
}
