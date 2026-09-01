import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_routes.dart';
import '../models/public_form.dart';
import '../models/student_field.dart';
import '../services/api_service.dart';
import '../widgets/authenticated_app_bar.dart';

class PublicFormManagementScreen extends StatefulWidget {
  const PublicFormManagementScreen({
    super.key,
    required this.schoolUuid,
    required this.schoolName,
    required this.api,
  });
  final String schoolUuid;
  final String schoolName;
  final ApiService api;

  @override
  State<PublicFormManagementScreen> createState() =>
      _PublicFormManagementScreenState();
}

class _PublicFormManagementScreenState
    extends State<PublicFormManagementScreen> {
  static const _systemFields = <String, String>{
    'session_uuid': 'Academic session',
    'class_uuid': 'Class',
    'section_uuid': 'Section',
    'admission_no': 'Admission number',
    'roll_no': 'Roll number',
    'stream': 'Stream',
    'full_name': 'Full name',
    'father_name': "Father's name",
    'mother_name': "Mother's name",
    'dob': 'Date of birth',
    'gender': 'Gender',
    'blood_group': 'Blood group',
    'mobile': 'Mobile',
    'aadhaar': 'Aadhaar',
    'address': 'Address',
  };
  static const _required = {
    'session_uuid',
    'class_uuid',
    'section_uuid',
    'admission_no',
    'full_name',
  };

  final _title = TextEditingController();
  final _instructions = TextEditingController();
  final _success = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  PublicFormConfig? _config;
  List<StudentFieldDefinition> _customFields = const [];
  final Set<String> _selectedSystem = {..._required};
  final Set<String> _selectedCustom = {};
  bool _active = false;
  bool _requireAll = false;
  bool _allowPhoto = false;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _instructions.dispose();
    _success.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        widget.api.getPublicFormConfig(widget.schoolUuid),
        widget.api.getStudentFields(widget.schoolUuid),
      ]);
      final config = values[0] as PublicFormConfig?;
      _customFields = (values[1] as List<StudentFieldDefinition>)
          .where((field) => field.isActive)
          .toList();
      _config = config;
      _title.text = config?.title ?? 'Student information form';
      _instructions.text = config?.instructions ?? '';
      _success.text = config?.successMessage ?? '';
      _selectedSystem
        ..clear()
        ..addAll(config?.selectedSystemFields ?? _required);
      _selectedSystem.addAll(_required);
      _selectedCustom
        ..clear()
        ..addAll(config?.selectedCustomFieldUuids ?? const []);
      _active = config?.isActive ?? false;
      _requireAll = config?.requireAllFields ?? false;
      _allowPhoto = config?.allowPhoto ?? false;
      _expiresAt = config?.expiresAt;
    } catch (error) {
      _error = error.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  PublicFormConfig _draft() => PublicFormConfig(
    title: _title.text.trim(),
    instructions: _instructions.text.trim().isEmpty
        ? null
        : _instructions.text.trim(),
    isActive: _active,
    requireAllFields: _requireAll,
    allowPhoto: _allowPhoto,
    expiresAt: _expiresAt,
    selectedSystemFields: _systemFields.keys
        .where(_selectedSystem.contains)
        .toList(),
    selectedCustomFieldUuids: _customFields
        .where((field) => _selectedCustom.contains(field.uuid))
        .map((field) => field.uuid)
        .toList(),
    successMessage: _success.text.trim().isEmpty ? null : _success.text.trim(),
  );

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      _config = await widget.api.savePublicFormConfig(
        schoolUuid: widget.schoolUuid,
        config: _draft(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Public form saved.')));
      }
    } catch (error) {
      _error = error.toString();
    }
    if (mounted) setState(() => _saving = false);
  }

  String? get _publicLink {
    final token = _config?.publicToken;
    return token == null
        ? null
        : Uri.base.resolve(AppRoutes.publicForm(token)).toString();
  }

  Future<void> _regenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate public link?'),
        content: const Text('The current link will stop working immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      _config = await widget.api.regeneratePublicFormLink(widget.schoolUuid);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _setActive(bool value) async {
    if (!value && _active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Disable public form?'),
          content: const Text(
            'The public link will stop accepting submissions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Disable'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _active = value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AuthenticatedAppBar(title: Text('Public Forms')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.schoolName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Card(
                      color: Color(0xfffff7df),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Submissions enter as Pending and must be reviewed before card production.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Form title',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _instructions,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Instructions',
                      ),
                    ),
                    SwitchListTile(
                      value: _active,
                      onChanged: _setActive,
                      title: const Text('Public form enabled'),
                    ),
                    SwitchListTile(
                      value: _requireAll,
                      onChanged: (value) => setState(() => _requireAll = value),
                      title: const Text('Require all displayed fields'),
                    ),
                    SwitchListTile(
                      value: _allowPhoto,
                      onChanged: (value) => setState(() => _allowPhoto = value),
                      title: const Text('Allow student photo'),
                    ),
                    ListTile(
                      title: Text(
                        _expiresAt == null
                            ? 'No expiry'
                            : 'Expires ${_expiresAt!.toLocal().toString().split(' ').first}',
                      ),
                      trailing: Wrap(
                        children: [
                          if (_expiresAt != null)
                            IconButton(
                              onPressed: () =>
                                  setState(() => _expiresAt = null),
                              icon: const Icon(Icons.clear),
                            ),
                          IconButton(
                            onPressed: () async {
                              final value = await showDatePicker(
                                context: context,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 3650),
                                ),
                                initialDate:
                                    _expiresAt ??
                                    DateTime.now().add(
                                      const Duration(days: 30),
                                    ),
                              );
                              if (value != null) {
                                setState(
                                  () => _expiresAt = DateTime(
                                    value.year,
                                    value.month,
                                    value.day,
                                    23,
                                    59,
                                    59,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.calendar_month),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Text(
                      'Student fields',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ..._systemFields.entries.map(
                      (entry) => CheckboxListTile(
                        key: Key('public-system-${entry.key}'),
                        value: _selectedSystem.contains(entry.key),
                        onChanged: _required.contains(entry.key)
                            ? null
                            : (value) => setState(
                                () => value == true
                                    ? _selectedSystem.add(entry.key)
                                    : _selectedSystem.remove(entry.key),
                              ),
                        title: Text(entry.value),
                        subtitle: Text(
                          _required.contains(entry.key)
                              ? 'Required to create a valid student'
                              : _requireAll &&
                                    _selectedSystem.contains(entry.key)
                              ? 'Required by form setting'
                              : 'Optional',
                        ),
                      ),
                    ),
                    if (_customFields.isNotEmpty) ...[
                      const Divider(),
                      Text(
                        'Custom fields',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ..._customFields.map(
                        (field) => CheckboxListTile(
                          key: Key('public-custom-${field.uuid}'),
                          value: _selectedCustom.contains(field.uuid),
                          onChanged: (value) => setState(
                            () => value == true
                                ? _selectedCustom.add(field.uuid)
                                : _selectedCustom.remove(field.uuid),
                          ),
                          title: Text(field.label),
                          subtitle: Text(
                            '${field.dataType}${field.isRequired ? ' • required' : ''}',
                          ),
                        ),
                      ),
                    ],
                    TextField(
                      controller: _success,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Success message (optional)',
                      ),
                    ),
                    if (_publicLink != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Public link',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SelectableText(_publicLink!),
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: _publicLink!),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Link copied.'),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.copy),
                                    label: const Text('Copy Link'),
                                  ),
                                  TextButton.icon(
                                    onPressed: _regenerate,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Regenerate Link'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('save-public-form'),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save public form'),
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
}
