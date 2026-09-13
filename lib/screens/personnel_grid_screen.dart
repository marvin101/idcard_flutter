import 'package:flutter/material.dart';

import '../models/api_personnel.dart';
import '../models/personnel_grid.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/authenticated_app_bar.dart';

class PersonnelGridScreen extends StatefulWidget {
  const PersonnelGridScreen({
    super.key,
    required this.schoolUuid,
    required this.schoolName,
    required this.api,
    required this.initialType,
  });

  final String schoolUuid;
  final String schoolName;
  final ApiService api;
  final PersonnelType initialType;

  @override
  State<PersonnelGridScreen> createState() => _PersonnelGridScreenState();
}

class _PersonnelGridScreenState extends State<PersonnelGridScreen> {
  static const _systemColumns = <(String, String)>[
    ('employee_no', 'Employee No.'),
    ('full_name', 'Full Name'),
    ('designation', 'Designation'),
    ('department', 'Department'),
    ('dob', 'Date of Birth'),
    ('gender', 'Gender'),
    ('blood_group', 'Blood Group'),
    ('mobile', 'Mobile'),
    ('email', 'Email'),
    ('address', 'Address'),
  ];

  late PersonnelType _type;
  final _search = TextEditingController();
  PersonnelGridPage? _page;
  bool _loading = true;
  bool _saving = false;
  bool? _active = true;
  String? _department;
  String? _designation;
  String? _error;
  int _revision = 0;
  final Map<String, Map<String, String>> _drafts = {};

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _load();
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
      final page = await widget.api.getPersonnelGrid(
        schoolUuid: widget.schoolUuid,
        personnelType: _type,
        search: _search.text,
        active: _active,
        department: _department,
        designation: _designation,
      );
      if (!mounted) return;
      setState(() {
        _page = page;
        _drafts.clear();
        _revision++;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load the personnel grid.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _original(PersonnelGridRow row, String key) {
    if (key.startsWith('custom:')) {
      return row.customFields[key.substring(7)] ?? '';
    }
    return row.systemFields[key] ?? '';
  }

  void _edit(PersonnelGridRow row, String key, String value) {
    setState(() {
      final rowDraft = _drafts.putIfAbsent(row.uuid, () => {});
      if (value == _original(row, key)) {
        rowDraft.remove(key);
        if (rowDraft.isEmpty) _drafts.remove(row.uuid);
      } else {
        rowDraft[key] = value;
      }
      _error = null;
    });
  }

  void _discard() {
    setState(() {
      _drafts.clear();
      _error = null;
      _revision++;
    });
  }

  Future<void> _save() async {
    final page = _page;
    if (page == null || _drafts.isEmpty) return;
    final byUuid = {for (final row in page.rows) row.uuid: row};
    final patches = <PersonnelGridRowPatch>[];
    for (final entry in _drafts.entries) {
      final row = byUuid[entry.key];
      if (row == null) continue;
      final system = <String, dynamic>{};
      final custom = <String, dynamic>{};
      for (final value in entry.value.entries) {
        if (value.key.startsWith('custom:')) {
          custom[value.key.substring(7)] = value.value;
        } else {
          system[value.key] = value.value;
        }
      }
      patches.add(
        PersonnelGridRowPatch(
          personnelUuid: row.uuid,
          expectedUpdatedAt: row.updatedAt,
          systemFields: system,
          customFields: custom,
        ),
      );
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.api.patchPersonnelGrid(
        schoolUuid: widget.schoolUuid,
        rows: patches,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${result.updatedCount} personnel row(s).'),
        ),
      );
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      final details = error.gridErrors
          .map((item) => '${item.field}: ${item.message}')
          .join('\n');
      setState(() {
        _error = details.isEmpty
            ? error.message
            : '${error.statusCode == 409 ? 'Conflict — refresh before saving.' : error.message}\n$details';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save the personnel grid.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AuthenticatedAppBar(
      title: Text('Personnel Excel Grid — ${widget.schoolName}'),
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<PersonnelType>(
                  key: const Key('personnel-grid-type'),
                  isExpanded: true,
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Personnel type',
                  ),
                  items: PersonnelType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null || value == _type) return;
                          _type = value;
                          _department = null;
                          _designation = null;
                          _load();
                        },
                ),
              ),
              SizedBox(
                width: 230,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              _filter(
                label: 'Department',
                value: _department,
                values: _page?.departments ?? const [],
                onChanged: (value) {
                  _department = value;
                  _load();
                },
              ),
              _filter(
                label: 'Designation',
                value: _designation,
                values: _page?.designations ?? const [],
                onChanged: (value) {
                  _designation = value;
                  _load();
                },
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<bool?>(
                  isExpanded: true,
                  initialValue: _active,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('Active')),
                    DropdownMenuItem(value: false, child: Text('Inactive')),
                    DropdownMenuItem(value: null, child: Text('All')),
                  ],
                  onChanged: (value) {
                    _active = value;
                    _load();
                  },
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loading || _saving ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              OutlinedButton(
                key: const Key('personnel-grid-discard'),
                onPressed: _drafts.isEmpty || _saving ? null : _discard,
                child: const Text('Discard'),
              ),
              FilledButton.icon(
                key: const Key('personnel-grid-save'),
                onPressed: _drafts.isEmpty || _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving…' : 'Save (${_drafts.length})'),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                key: const Key('personnel-grid-error'),
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(child: _content()),
        ],
      ),
    ),
  );

  Widget _filter({
    required String label,
    required String? value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) => SizedBox(
    width: 170,
    child: DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: values.contains(value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('All')),
        ...values.map(
          (item) => DropdownMenuItem(value: item, child: Text(item)),
        ),
      ],
      onChanged: onChanged,
    ),
  );

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final page = _page;
    if (page == null) {
      return Center(child: Text(_error ?? 'No personnel data available.'));
    }
    if (page.rows.isEmpty) {
      return Center(
        child: Text(
          'No ${_type.pluralLabel.toLowerCase()} match these filters.',
        ),
      );
    }
    final columns = <(String, String)>[
      ..._systemColumns,
      ...page.customFields.map(
        (field) => ('custom:${field.uuid}', field.label),
      ),
    ];
    return Card(
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              columns: [
                for (final column in columns)
                  DataColumn(label: Text(column.$2)),
              ],
              rows: [
                for (final row in page.rows)
                  DataRow(
                    key: ValueKey(row.uuid),
                    cells: [
                      for (final column in columns) _cell(row, column.$1),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataCell _cell(PersonnelGridRow row, String key) {
    final initial = _drafts[row.uuid]?[key] ?? _original(row, key);
    return DataCell(
      SizedBox(
        width: key == 'address' ? 230 : 150,
        child: TextFormField(
          key: ValueKey('${row.uuid}-$key-$_revision'),
          initialValue: initial,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _edit(row, key, value),
        ),
      ),
    );
  }
}
