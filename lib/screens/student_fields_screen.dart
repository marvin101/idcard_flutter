import 'package:flutter/material.dart';

import '../layouts/main_layout.dart';
import '../models/student_field.dart';
import '../services/api_service.dart';

bool canManageStudentFields({
  required bool isPlatformAdmin,
  required String? schoolRole,
}) => isPlatformAdmin || schoolRole == 'school_admin' || schoolRole == 'admin';

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
  List<BuiltinStudentField> _builtinFields = const [];
  List<StudentFieldDefinition> _fields = const [];
  bool _autoAdmissionFormat = false;
  List<StreamOption> _streamOptions = const [
    StreamOption(name: 'Science', code: 'SCI'),
    StreamOption(name: 'Arts', code: 'ARTS'),
    StreamOption(name: 'Commerce', code: 'COM'),
  ];
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
      final values = await Future.wait([
        widget.api.getStudentFieldConfig(widget.schoolUuid),
        widget.api.getStudentFields(widget.schoolUuid, includeInactive: true),
      ]);
      if (mounted) {
        final config = values[0] as StudentFieldConfigResponse;
        setState(() {
          _builtinFields = config.fields;
          _autoAdmissionFormat = config.autoAdmissionFormat;
          if (config.streamOptions.isNotEmpty) {
            _streamOptions = config.streamOptions;
          }
          _fields = values[1] as List<StudentFieldDefinition>;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveBuiltin(List<BuiltinStudentField> fields) async {
    setState(() => _builtinFields = fields);
    try {
      final saved = await widget.api.updateStudentFieldConfig(
        schoolUuid: widget.schoolUuid,
        fields: fields,
        autoAdmissionFormat: _autoAdmissionFormat,
        streamOptions: _streamOptions,
      );
      if (mounted) {
        setState(() {
          _builtinFields = saved.fields;
          _autoAdmissionFormat = saved.autoAdmissionFormat;
          if (saved.streamOptions.isNotEmpty) {
            _streamOptions = saved.streamOptions;
          }
        });
      }
    } catch (error) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleAutoAdmission(bool enabled) async {
    if (enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enable Automated Admission Numbers?'),
          content: const Text(
            'This will automatically format Admission Numbers as STREAM/ROLL (e.g. SCI/31, ARTS/31, COM/31).\n\n'
            'Admission numbers for all existing students who have a stream and roll number will be updated to this format.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enable & Update Students'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      final saved = await widget.api.updateStudentFieldConfig(
        schoolUuid: widget.schoolUuid,
        fields: _builtinFields,
        autoAdmissionFormat: enabled,
        streamOptions: _streamOptions,
      );
      if (mounted) {
        setState(() {
          _autoAdmissionFormat = saved.autoAdmissionFormat;
          _builtinFields = saved.fields;
          if (saved.streamOptions.isNotEmpty) {
            _streamOptions = saved.streamOptions;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Automated admission format enabled and existing students updated.'
                  : 'Automated admission format disabled.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cannot Enable Automated Admission Numbers'),
            content: Text(error.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _addStream() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add School Stream'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Stream Name *',
                  hintText: 'e.g. Science, Vocational',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter stream name';
                  if (_streamOptions.any(
                    (opt) => opt.name.toLowerCase() == val.trim().toLowerCase(),
                  )) {
                    return 'Stream already exists';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Stream Code (Prefix) *',
                  hintText: 'e.g. SCI, VOC',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter stream code';
                  if (_streamOptions.any(
                    (opt) => opt.code.toLowerCase() == val.trim().toLowerCase(),
                  )) {
                    return 'Code already in use';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (created == true) {
      final updated = [
        ..._streamOptions,
        StreamOption(
          name: nameController.text.trim(),
          code: codeController.text.trim().toUpperCase(),
        ),
      ];
      try {
        final saved = await widget.api.updateStudentFieldConfig(
          schoolUuid: widget.schoolUuid,
          fields: _builtinFields,
          autoAdmissionFormat: _autoAdmissionFormat,
          streamOptions: updated,
        );
        if (mounted) {
          setState(() {
            _streamOptions = saved.streamOptions;
          });
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _removeStream(int index) async {
    final updated = [..._streamOptions]..removeAt(index);
    try {
      final saved = await widget.api.updateStudentFieldConfig(
        schoolUuid: widget.schoolUuid,
        fields: _builtinFields,
        autoAdmissionFormat: _autoAdmissionFormat,
        streamOptions: updated,
      );
      if (mounted) {
        setState(() {
          _streamOptions = saved.streamOptions;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _toggleBuiltinEnabled(int index, bool enabled) {
    final field = _builtinFields[index];
    if (field.protected) return;
    final updated = [..._builtinFields];
    updated[index] = field.copyWith(
      enabled: enabled,
      required: enabled ? field.required : false,
    );
    _saveBuiltin(updated);
  }

  void _toggleBuiltinRequired(int index, bool required) {
    final field = _builtinFields[index];
    if (field.protected || !field.enabled) return;
    final updated = [..._builtinFields];
    updated[index] = field.copyWith(required: required);
    _saveBuiltin(updated);
  }

  void _reorderBuiltin(int oldIndex, int newIndex) {
    final updated = [..._builtinFields];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    _saveBuiltin([
      for (var index = 0; index < updated.length; index++)
        updated[index].copyWith(displayOrder: index),
    ]);
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
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
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
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
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
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => MainLayout(
    title: 'Student Fields',
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: _loading
          ? const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          : _error != null
          ? SizedBox(height: 160, child: Center(child: Text(_error!)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.schoolName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                Text(
                  'BUILT-IN FIELDS',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: _builtinFields.length,
                  onReorderItem: _reorderBuiltin,
                  itemBuilder: (context, index) {
                    final field = _builtinFields[index];
                    return Card(
                      key: ValueKey('builtin-${field.key}'),
                      child: ListTile(
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: Text(field.label),
                        subtitle: Text(
                          field.protected
                              ? 'Required by CampusID'
                              : field.dataType,
                        ),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (field.protected)
                              const Tooltip(
                                message: 'Required by CampusID',
                                child: Icon(Icons.lock_outline),
                              ),
                            const Text('Enabled'),
                            Switch(
                              key: Key('builtin-enabled-${field.key}'),
                              value: field.enabled,
                              onChanged: field.protected
                                  ? null
                                  : (value) =>
                                        _toggleBuiltinEnabled(index, value),
                            ),
                            const Text('Required'),
                            Checkbox(
                              key: Key('builtin-required-${field.key}'),
                              value: field.required,
                              onChanged: field.protected || !field.enabled
                                  ? null
                                  : (value) => _toggleBuiltinRequired(
                                      index,
                                      value ?? false,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                Text(
                  'ADMISSION NUMBER AUTOMATION',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Auto-generate Admission No. from Stream & Roll No.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Combines stream code and roll number into STREAM/ROLL (e.g. SCI/31, ARTS/31, COM/31). '
                                    'Enabling will also update existing students with valid stream and roll numbers.',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              key: const Key('auto-admission-format-switch'),
                              value: _autoAdmissionFormat,
                              onChanged: _toggleAutoAdmission,
                            ),
                          ],
                        ),
                        if (_autoAdmissionFormat) ...[
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Allowed School Streams',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              TextButton.icon(
                                onPressed: _addStream,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Stream'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _streamOptions.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final opt = entry.value;
                              return Chip(
                                label: Text('${opt.name} (${opt.code})'),
                                onDeleted: _streamOptions.length > 1
                                    ? () => _removeStream(idx)
                                    : null,
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'CUSTOM FIELDS',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
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
                      child: Text(
                        'No custom student fields have been configured.',
                      ),
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
    title: Text(
      widget.field == null ? 'Add Student Field' : 'Edit Student Field',
    ),
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
              validator: (value) =>
                  RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Use lowercase letters, numbers, and underscores.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(labelText: 'Label'),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Label is required.' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _dataType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const ['text', 'multiline', 'number', 'date', 'phone']
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
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
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
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
