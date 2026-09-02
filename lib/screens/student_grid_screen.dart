import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_routes.dart';
import '../models/student_grid.dart';
import '../navigation/app_navigation.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/authenticated_app_bar.dart';

class StudentGridScreen extends StatefulWidget {
  const StudentGridScreen({
    super.key,
    required this.schoolUuid,
    required this.schoolName,
    required this.api,
  });

  final String schoolUuid;
  final String schoolName;
  final ApiService api;

  @override
  State<StudentGridScreen> createState() => _StudentGridScreenState();
}

class _Column {
  const _Column(
    this.key,
    this.label, {
    this.kind = 'text',
    this.required = false,
  });
  final String key;
  final String label;
  final String kind;
  final bool required;
  bool get isCustom => key.startsWith('custom:');
  String get customUuid => key.substring('custom:'.length);
}

class _StudentGridScreenState extends State<StudentGridScreen> {
  static const _pageSize = 50;
  static const _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];
  static const _systemColumns = <_Column>[
    _Column('admission_no', 'Admission No.', required: true),
    _Column('full_name', 'Full Name', required: true),
    _Column('roll_no', 'Roll No.'),
    _Column(
      'session_uuid',
      'Academic Session',
      kind: 'session',
      required: true,
    ),
    _Column('class_uuid', 'Class', kind: 'class', required: true),
    _Column('section_uuid', 'Section', kind: 'section', required: true),
    _Column('stream', 'Stream'),
    _Column('father_name', "Father's Name"),
    _Column('mother_name', "Mother's Name"),
    _Column('dob', 'Date of Birth', kind: 'date'),
    _Column('gender', 'Gender'),
    _Column('blood_group', 'Blood Group', kind: 'blood'),
    _Column('mobile', 'Mobile', kind: 'phone'),
    _Column('aadhaar', 'Aadhaar'),
    _Column('address', 'Address', kind: 'multiline'),
  ];

  final _searchController = TextEditingController();
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();
  final Map<String, Map<String, String?>> _drafts = {};
  final Map<String, String> _errors = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, TextEditingController> _cellControllers = {};
  Timer? _searchDebounce;
  StudentGridPage? _page;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  int _offset = 0;
  String? _sessionFilter;
  String? _classFilter;
  String? _sectionFilter;

  List<_Column> get _columns => [
    ..._systemColumns,
    ...?_page?.customFields.map(
      (field) => _Column(
        'custom:${field.uuid}',
        field.label,
        kind: field.dataType,
        required: field.isRequired,
      ),
    ),
  ];
  bool get _dirty => _drafts.values.any((values) => values.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    for (final controller in _cellControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool resetOffset = false}) async {
    if (_dirty &&
        !await _confirmDiscard('Discard unsaved edits and refresh?')) {
      return;
    }
    if (resetOffset) _offset = 0;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final page = await widget.api.getStudentGrid(
        schoolUuid: widget.schoolUuid,
        limit: _pageSize,
        offset: _offset,
        search: _searchController.text,
        sessionUuid: _sessionFilter,
        classUuid: _classFilter,
        sectionUuid: _sectionFilter,
      );
      if (!mounted) return;
      setState(() {
        _page = page;
        _drafts.clear();
        _errors.clear();
        for (final controller in _cellControllers.values) {
          controller.dispose();
        }
        _cellControllers.clear();
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = '$error';
        _loading = false;
      });
    }
  }

  String _cellId(String rowUuid, String field) => '$rowUuid::$field';

  String? _serverValue(StudentGridRow row, _Column column) => column.isCustom
      ? row.customFields[column.customUuid] ?? ''
      : row.values[column.key];

  String? _value(StudentGridRow row, _Column column) =>
      _drafts[row.uuid]?[column.key] ?? _serverValue(row, column);

  void _edit(
    StudentGridRow row,
    _Column column,
    String? value, {
    bool syncEditor = false,
  }) {
    final normalized = value ?? '';
    final server = _serverValue(row, column) ?? '';
    setState(() {
      if (syncEditor) {
        final controller = _cellControllers[_cellId(row.uuid, column.key)];
        if (controller != null && controller.text != normalized) {
          controller.text = normalized;
          controller.selection = TextSelection.collapsed(
            offset: normalized.length,
          );
        }
      }
      if (normalized == server) {
        _drafts[row.uuid]?.remove(column.key);
        if (_drafts[row.uuid]?.isEmpty == true) _drafts.remove(row.uuid);
      } else {
        (_drafts[row.uuid] ??= {})[column.key] = normalized;
      }
      final id = _cellId(row.uuid, column.key);
      final validation = _validate(column, normalized);
      if (validation == null) {
        _errors.remove(id);
      } else {
        _errors[id] = validation;
      }
    });
  }

  String? _validate(_Column column, String value) {
    final text = value.trim();
    if (column.required && text.isEmpty) return '${column.label} is required';
    if (text.isEmpty) return null;
    if (column.kind == 'number') {
      final parsed = num.tryParse(text);
      if (parsed == null || !parsed.isFinite) {
        return '${column.label} must be a number';
      }
    }
    if (column.kind == 'date') {
      if (!_isValidIsoDate(text)) {
        return '${column.label} must use YYYY-MM-DD';
      }
    }
    if (column.kind == 'phone' &&
        (!RegExp(r'^\+?[0-9][0-9 ().-]{4,24}$').hasMatch(text) ||
            text.replaceAll(RegExp(r'\D'), '').length < 5)) {
      return '${column.label} must be a valid phone number';
    }
    return null;
  }

  bool _isValidIsoDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return false;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime.tryParse(value);
    return parsed != null &&
        parsed.year == year &&
        parsed.month == month &&
        parsed.day == day;
  }

  void _changeClass(StudentGridRow row, _Column column, String? value) {
    _edit(row, column, value);
    final sectionColumn = _columns.firstWhere(
      (item) => item.key == 'section_uuid',
    );
    final currentSection = _value(row, sectionColumn);
    final valid = _page!.sections.any(
      (section) => section.uuid == currentSection && section.classUuid == value,
    );
    if (!valid) _edit(row, sectionColumn, '');
  }

  Future<void> _save() async {
    if (!_dirty || _saving) return;
    final page = _page!;
    final errors = <String, String>{};
    for (final row in page.rows) {
      for (final column in _columns) {
        final message = _validate(column, _value(row, column) ?? '');
        if (message != null) errors[_cellId(row.uuid, column.key)] = message;
      }
    }
    if (errors.isNotEmpty) {
      setState(() => _errors.addAll(errors));
      _showMessage(
        'Fix ${errors.length} highlighted cell(s) before saving.',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final rows = page.rows
          .where((row) => _drafts[row.uuid]?.isNotEmpty == true)
          .map((row) {
            final values = _drafts[row.uuid]!;
            return StudentGridRowPatch(
              studentUuid: row.uuid,
              expectedUpdatedAt: row.updatedAt,
              systemFields: {
                for (final entry in values.entries)
                  if (!entry.key.startsWith('custom:'))
                    entry.key: _nullable(entry.value),
              },
              customFields: {
                for (final entry in values.entries)
                  if (entry.key.startsWith('custom:'))
                    entry.key.substring('custom:'.length): entry.value ?? '',
              },
            );
          })
          .toList();
      final result = await widget.api.patchStudentGrid(
        schoolUuid: widget.schoolUuid,
        rows: rows,
      );
      if (!mounted) return;
      _drafts.clear();
      _errors.clear();
      _showMessage('${result.updatedCount} student row(s) saved.');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        for (final issue in error.gridErrors) {
          _errors[_cellId(
                issue.studentUuid,
                issue.field.replaceFirst('custom_fields.', 'custom:'),
              )] =
              issue.message;
        }
      });
      _showMessage(
        error.gridErrors.isEmpty
            ? error.message
            : '${error.message}: ${error.gridErrors.first.message}',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  dynamic _nullable(String? value) =>
      value?.trim().isEmpty == true ? null : value?.trim();

  void _discard() {
    setState(() {
      final page = _page;
      if (page != null) {
        for (final row in page.rows) {
          for (final column in _columns) {
            final controller = _cellControllers[_cellId(row.uuid, column.key)];
            if (controller != null) {
              controller.text = _serverValue(row, column) ?? '';
            }
          }
        }
      }
      _drafts.clear();
      _errors.clear();
    });
  }

  Future<bool> _confirmDiscard(String message) async {
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unsaved changes'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : null,
      ),
    );
  }

  void _moveFocus(int rowIndex, int columnIndex) {
    final page = _page;
    if (page == null || rowIndex >= page.rows.length) return;
    _focusNodes[_cellId(page.rows[rowIndex].uuid, _columns[columnIndex].key)]
        ?.requestFocus();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || !_dirty) return;
      if (await _confirmDiscard('Discard unsaved edits and leave the grid?') &&
          context.mounted) {
        _discard();
        AppNavigation.navigateBack<void>(context, AppRoutes.studentGrid);
      }
    },
    child: Scaffold(
      appBar: AuthenticatedAppBar(
        title: Text('Excel Grid — ${widget.schoolName}'),
        leading: BackButton(
          onPressed: () async {
            if (await _confirmDiscard(
                  'Discard unsaved edits and leave the grid?',
                ) &&
                context.mounted) {
              _discard();
              AppNavigation.navigateBack<void>(context, AppRoutes.studentGrid);
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(),
            const SizedBox(height: 12),
            Expanded(child: _content()),
            if (_page != null) _pagination(),
          ],
        ),
      ),
    ),
  );

  Widget _toolbar() => Wrap(
    spacing: 10,
    runSpacing: 10,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 310,
        child: TextField(
          key: const Key('student-grid-search'),
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Search students',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) {
            _searchDebounce?.cancel();
            _searchDebounce = Timer(
              const Duration(milliseconds: 400),
              () => _load(resetOffset: true),
            );
          },
        ),
      ),
      _filter('Session', _sessionFilter, _page?.sessions ?? const [], (value) {
        setState(() => _sessionFilter = value);
        _load(resetOffset: true);
      }),
      _filter('Class', _classFilter, _page?.classes ?? const [], (value) {
        setState(() {
          _classFilter = value;
          _sectionFilter = null;
        });
        _load(resetOffset: true);
      }),
      _filter(
        'Section',
        _sectionFilter,
        (_page?.sections ?? const [])
            .where(
              (item) => _classFilter == null || item.classUuid == _classFilter,
            )
            .toList(),
        (value) {
          setState(() => _sectionFilter = value);
          _load(resetOffset: true);
        },
      ),
      FilledButton.icon(
        key: const Key('student-grid-save'),
        onPressed: _dirty && !_saving ? _save : null,
        icon: _saving
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(_saving ? 'Saving…' : 'Save'),
      ),
      OutlinedButton.icon(
        key: const Key('student-grid-discard'),
        onPressed: _dirty && !_saving ? _discard : null,
        icon: const Icon(Icons.undo),
        label: const Text('Discard'),
      ),
      IconButton(
        key: const Key('student-grid-refresh'),
        tooltip: 'Refresh',
        onPressed: _saving ? null : _load,
        icon: const Icon(Icons.refresh),
      ),
      Chip(
        key: const Key('student-grid-dirty-indicator'),
        avatar: Icon(_dirty ? Icons.edit : Icons.check_circle, size: 18),
        label: Text(
          _dirty ? '${_drafts.length} unsaved row(s)' : 'All changes saved',
        ),
        backgroundColor: _dirty
            ? const Color(0xfffff3cd)
            : const Color(0xffe8f5e9),
      ),
    ],
  );

  Widget _filter(
    String label,
    String? value,
    List<StudentGridLookupItem> items,
    ValueChanged<String?> changed,
  ) => SizedBox(
    width: 180,
    child: DropdownButtonFormField<String>(
      key: Key('student-grid-filter-${label.toLowerCase()}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(value: null, child: Text('All $label')),
        ...items.map(
          (item) => DropdownMenuItem(value: item.uuid, child: Text(item.name)),
        ),
      ],
      onChanged: _loading ? null : changed,
    ),
  );

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final page = _page!;
    if (page.rows.isEmpty) {
      return const Center(child: Text('No students match these filters.'));
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _verticalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _verticalController,
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xffeef2f7),
                  ),
                  columnSpacing: 12,
                  horizontalMargin: 10,
                  columns: [
                    const DataColumn(label: Text('#')),
                    ..._columns.map(
                      (column) => DataColumn(
                        label: SizedBox(
                          width: 150,
                          child: Text(
                            '${column.label}${column.required ? ' *' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                  rows: [
                    for (
                      var rowIndex = 0;
                      rowIndex < page.rows.length;
                      rowIndex++
                    )
                      _dataRow(page.rows[rowIndex], rowIndex),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _dataRow(StudentGridRow row, int rowIndex) {
    final dirty = _drafts[row.uuid]?.isNotEmpty == true;
    final hasError = _errors.keys.any((key) => key.startsWith('${row.uuid}::'));
    return DataRow(
      key: ValueKey('grid-row-${row.uuid}'),
      color: WidgetStateProperty.all(
        hasError
            ? const Color(0xffffebee)
            : dirty
            ? const Color(0xfffffbeb)
            : Colors.white,
      ),
      cells: [
        DataCell(Text('${_offset + rowIndex + 1}${dirty ? ' •' : ''}')),
        for (var columnIndex = 0; columnIndex < _columns.length; columnIndex++)
          DataCell(_editor(row, rowIndex, columnIndex, _columns[columnIndex])),
      ],
    );
  }

  Widget _editor(
    StudentGridRow row,
    int rowIndex,
    int columnIndex,
    _Column column,
  ) {
    final id = _cellId(row.uuid, column.key);
    final focusNode = _focusNodes.putIfAbsent(id, FocusNode.new);
    final error = _errors[id];
    final value = _value(row, column) ?? '';
    Widget child;
    if (column.kind == 'blood' ||
        column.kind == 'session' ||
        column.kind == 'class' ||
        column.kind == 'section') {
      final items = switch (column.kind) {
        'blood' =>
          _bloodGroups
              .map((item) => StudentGridLookupItem(uuid: item, name: item))
              .toList(),
        'session' => _page!.sessions,
        'class' => _page!.classes,
        'section' =>
          _page!.sections
              .where(
                (item) =>
                    item.classUuid ==
                    _value(
                      row,
                      _columns.firstWhere(
                        (column) => column.key == 'class_uuid',
                      ),
                    ),
              )
              .toList(),
        _ => <StudentGridLookupItem>[],
      };
      child = DropdownButtonFormField<String>(
        key: ValueKey('$id:$value'),
        focusNode: focusNode,
        initialValue: value.isEmpty ? null : value,
        isExpanded: true,
        decoration: _decoration(error),
        items: [
          if (!column.required)
            const DropdownMenuItem(value: '', child: Text('—')),
          ...items.map(
            (item) => DropdownMenuItem(
              value: item.uuid,
              child: Text(item.name, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: (next) => column.kind == 'class'
            ? _changeClass(row, column, next)
            : _edit(row, column, next),
      );
    } else {
      child = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              _edit(row, column, _serverValue(row, column), syncEditor: true),
        },
        child: TextFormField(
          key: ValueKey(id),
          focusNode: focusNode,
          controller: _cellControllers.putIfAbsent(
            id,
            () => TextEditingController(text: value),
          ),
          minLines: 1,
          maxLines: column.kind == 'multiline' ? 2 : 1,
          textInputAction: column.kind == 'multiline'
              ? TextInputAction.newline
              : TextInputAction.next,
          keyboardType: column.kind == 'number'
              ? const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                )
              : column.kind == 'multiline'
              ? TextInputType.multiline
              : column.kind == 'phone'
              ? TextInputType.phone
              : column.kind == 'date'
              ? TextInputType.datetime
              : TextInputType.text,
          decoration: _decoration(error).copyWith(
            suffixIcon: column.kind == 'date'
                ? IconButton(
                    tooltip: 'Choose date',
                    icon: const Icon(Icons.calendar_today, size: 16),
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: DateTime.tryParse(value) ?? DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (selected != null) {
                        _edit(
                          row,
                          column,
                          '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
                          syncEditor: true,
                        );
                      }
                    },
                  )
                : null,
          ),
          onChanged: (next) => _edit(row, column, next),
          onFieldSubmitted: (_) => _moveFocus(rowIndex + 1, columnIndex),
        ),
      );
    }
    return FocusTraversalOrder(
      key: Key('student-grid-cell-${row.uuid}-${column.key}'),
      order: NumericFocusOrder(
        rowIndex * _columns.length + columnIndex.toDouble(),
      ),
      child: SizedBox(width: 170, child: child),
    );
  }

  InputDecoration _decoration(String? error) => InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    errorText: error,
    errorMaxLines: 2,
    border: const OutlineInputBorder(),
  );

  Widget _pagination() {
    final page = _page!;
    final start = page.total == 0 ? 0 : page.offset + 1;
    final end = page.offset + page.rows.length;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$start–$end of ${page.total}'),
          IconButton(
            tooltip: 'Previous page',
            onPressed: page.offset > 0 && !_dirty
                ? () {
                    _offset = (_offset - _pageSize).clamp(0, page.total);
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: page.hasMore && !_dirty
                ? () {
                    _offset += _pageSize;
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
