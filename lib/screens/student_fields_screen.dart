import 'package:flutter/material.dart';

import '../layouts/main_layout.dart';
import '../models/student_field.dart';
import '../services/api_service.dart';

const systemStudentFields = <String>[
  'Photo',
  'Student Name',
  'Admission Number',
  'Roll Number',
  "Father's Name",
  "Mother's Name",
  'Date of Birth',
  'Gender',
  'Blood Group',
  'Mobile',
  'Aadhaar',
  'Address',
  'Stream',
  'Academic Session',
  'Class',
  'Section',
];

bool canManageStudentFields({
  required bool isPlatformAdmin,
  required String? schoolRole,
}) =>
    isPlatformAdmin || schoolRole == 'school_admin' || schoolRole == 'admin';

class StudentFieldsScreen extends StatefulWidget {
  const StudentFieldsScreen({
    super.key,
    required this.schoolUuid,
    required this.schoolName,
    required this.api,
  });

  final String schoolUuid;
  final String schoolName;
  final ApiService api;

  @override
  State<StudentFieldsScreen> createState() => _StudentFieldsScreenState();
}

class _StudentFieldsScreenState extends State<StudentFieldsScreen> {
  List<StudentFieldDefinition> _fields = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fields = await widget.api.getStudentFields(
        widget.schoolUuid,
        includeInactive: true,
      );
      if (mounted) setState(() => _fields = fields);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([StudentFieldDefinition? field]) async {
    final result = await showDialog<_FieldDraft>(
      context: context,
      builder: (_) => _FieldDialog(field: field),
    );
    if (result == null) return;
    try {
      if (field == null) {
        await widget.api.createStudentField(
          schoolUuid: widget.schoolUuid,
          fieldKey: result.fieldKey,
          label: result.label,
          dataType: result.dataType,
          isRequired: result.isRequired,
        );
      } else {
        await widget.api.updateStudentField(
          schoolUuid: widget.schoolUuid,
          fieldUuid: field.uuid,
          label: result.label,
          dataType: result.dataType,
          isRequired: result.isRequired,
        );
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggle(StudentFieldDefinition field, bool active) async {
    try {
      await widget.api.updateStudentField(
        schoolUuid: widget.schoolUuid,
        fieldUuid: field.uuid,
        isActive: active,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final updated = [..._fields];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    setState(() => _fields = updated);
    try {
      final fields = await widget.api.reorderStudentFields(
        schoolUuid: widget.schoolUuid,
        fields: updated,
      );
      if (mounted) setState(() => _fields = fields);
    } catch (error) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => MainLayout(
    title: 'Student Fields',
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text(_error!))
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(widget.schoolName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              Text('SYSTEM FIELDS', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final field in systemStudentFields)
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: Text(field),
                        subtitle: const Text('System field · typed database column'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text('CUSTOM FIELDS', style: Theme.of(context).textTheme.labelLarge),
                  ),
                  FilledButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Field'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_fields.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No custom student fields have been configured.'),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _fields.length,
                  onReorderItem: _reorder,
                  itemBuilder: (context, index) {
                    final field = _fields[index];
                    return Card(
                      key: ValueKey(field.uuid),
                      child: ListTile(
                        leading: const Icon(Icons.drag_handle),
                        title: Text(field.label),
                        subtitle: Text(
                          '${field.dataType}${field.isRequired ? ' · Required' : ''}'
                          '${field.isActive ? '' : ' · Inactive'}',
                        ),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Switch(
                              value: field.isActive,
                              onChanged: (value) => _toggle(field, value),
                            ),
                            IconButton(
                              tooltip: 'Edit field',
                              onPressed: () => _edit(field),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
  );
}

class _FieldDraft {
  const _FieldDraft(this.fieldKey, this.label, this.dataType, this.isRequired);
  final String fieldKey;
  final String label;
  final String dataType;
  final bool isRequired;
}

class _FieldDialog extends StatefulWidget {
  const _FieldDialog({this.field});
  final StudentFieldDefinition? field;

  @override
  State<_FieldDialog> createState() => _FieldDialogState();
}

class _FieldDialogState extends State<_FieldDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _keyController;
  late final TextEditingController _labelController;
  late String _dataType;
  late bool _required;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.field?.fieldKey ?? '');
    _labelController = TextEditingController(text: widget.field?.label ?? '');
    _dataType = widget.field?.dataType ?? 'text';
    _required = widget.field?.isRequired ?? false;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.field == null ? 'Add Student Field' : 'Edit Student Field'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _keyController,
              enabled: widget.field == null,
              decoration: const InputDecoration(labelText: 'Field key'),
              validator: (value) => RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Use lowercase letters, numbers, and underscores.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(labelText: 'Label'),
              validator: (value) => (value?.trim().isEmpty ?? true) ? 'Label is required.' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _dataType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const ['text', 'multiline', 'number', 'date', 'phone']
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) => setState(() => _dataType = value!),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Required'),
              value: _required,
              onChanged: (value) => setState(() => _required = value),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        onPressed: () {
          if (!(_formKey.currentState?.validate() ?? false)) return;
          Navigator.pop(
            context,
            _FieldDraft(
              _keyController.text.trim(),
              _labelController.text.trim(),
              _dataType,
              _required,
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );

  @override
  void dispose() {
    _keyController.dispose();
    _labelController.dispose();
    super.dispose();
  }
}
