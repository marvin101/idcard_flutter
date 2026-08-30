import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/student_import.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/authenticated_app_bar.dart';

class StudentImportScreen extends StatefulWidget {
  const StudentImportScreen({
    super.key,
    required this.schoolUuid,
    required this.schoolName,
    required this.api,
  });

  final String schoolUuid;
  final String schoolName;
  final ApiService api;

  @override
  State<StudentImportScreen> createState() => _StudentImportScreenState();
}

class _StudentImportScreenState extends State<StudentImportScreen> {
  int _step = 0;
  bool _busy = false;
  bool _confirmed = false;
  String? _error;
  StudentImportUpload? _upload;
  StudentImportPreview? _preview;
  StudentImportSummary? _summary;
  final Map<String, String?> _mappingBySource = {};

  List<StudentImportMapping> get _mappings => [
    for (final entry in _mappingBySource.entries)
      if (entry.value != null)
        StudentImportMapping(
          sourceColumn: entry.key,
          targetField: entry.value!,
        ),
  ];

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    if (result == null) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'The selected file could not be read.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final upload = await widget.api.uploadStudentImport(
        schoolUuid: widget.schoolUuid,
        filename: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _upload = upload;
        _mappingBySource
          ..clear()
          ..addEntries(upload.headers.map((header) => MapEntry(header, null)));
        for (final suggestion in upload.suggestedMappings) {
          _mappingBySource[suggestion.sourceColumn] = suggestion.targetField;
        }
        _step = 1;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setMapping(String source, String? target) {
    setState(() {
      if (target != null) {
        final duplicateSource = _mappingBySource.entries
            .where((entry) => entry.key != source && entry.value == target)
            .map((entry) => entry.key)
            .firstOrNull;
        if (duplicateSource != null) {
          _mappingBySource[duplicateSource] = null;
        }
      }
      _mappingBySource[source] = target;
      _preview = null;
      _confirmed = false;
    });
  }

  Future<void> _runPreview() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await widget.api.previewStudentImport(
        schoolUuid: widget.schoolUuid,
        uploadId: _upload!.uploadId,
        mappings: _mappings,
      );
      if (mounted) {
        setState(() {
          _preview = preview;
          _step = 2;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commit() async {
    if (!_confirmed) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final summary = await widget.api.commitStudentImport(
        schoolUuid: widget.schoolUuid,
        uploadId: _upload!.uploadId,
        mappings: _mappings,
        confirmed: true,
      );
      if (mounted) {
        setState(() {
          _summary = summary;
          _step = 4;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _step = 2;
          _confirmed = false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AuthenticatedAppBar(
      title: Text('Bulk Student Import — ${widget.schoolName}'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_error != null)
              Card(
                color: const Color(0xffffeeee),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            Stepper(
              currentStep: _step,
              controlsBuilder: (_, _) => const SizedBox.shrink(),
              steps: [
                Step(
                  title: const Text('Upload'),
                  isActive: _step >= 0,
                  state: _step > 0 ? StepState.complete : StepState.indexed,
                  content: _uploadStep(),
                ),
                Step(
                  title: const Text('Map'),
                  isActive: _step >= 1,
                  state: _step > 1 ? StepState.complete : StepState.indexed,
                  content: _mapStep(),
                ),
                Step(
                  title: const Text('Preview'),
                  isActive: _step >= 2,
                  state: _step > 2 ? StepState.complete : StepState.indexed,
                  content: _previewStep(),
                ),
                Step(
                  title: const Text('Confirm'),
                  isActive: _step >= 3,
                  state: _step > 3 ? StepState.complete : StepState.indexed,
                  content: _confirmStep(),
                ),
                Step(
                  title: const Text('Summary'),
                  isActive: _step >= 4,
                  state: _step == 4 ? StepState.complete : StepState.indexed,
                  content: _summaryStep(),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _uploadStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Choose a UTF-8 CSV or XLSX file. The first row must contain unique column headers.',
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _busy ? null : _pickAndUpload,
        icon: const Icon(Icons.upload_file),
        label: Text(_busy ? 'Uploading…' : 'Choose file'),
      ),
      if (_upload != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('${_upload!.filename} • ${_upload!.rowCount} rows'),
        ),
    ],
  );

  Widget _mapStep() {
    if (_upload == null) return const Text('Upload a file first.');
    final fields = _upload!.targetFields;
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Map each spreadsheet column to at most one student field. Required targets are marked *.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        for (final source in _upload!.headers)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<String>(
              initialValue: _mappingBySource[source],
              isExpanded: true,
              decoration: InputDecoration(
                labelText: source,
                border: const OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Do not import'),
                ),
                ...fields.map(
                  (field) => DropdownMenuItem(
                    value: field.key,
                    child: Text('${field.label}${field.required ? ' *' : ''}'),
                  ),
                ),
              ],
              onChanged: (value) => _setMapping(source, value),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _busy ? null : _runPreview,
            child: Text(_busy ? 'Validating…' : 'Preview import'),
          ),
        ),
      ],
    );
  }

  Widget _previewStep() {
    final preview = _preview;
    if (preview == null) {
      return const Text('Complete column mapping to preview.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _metric('Total', preview.totalRows),
            _metric('Valid', preview.validRows),
            _metric('Invalid', preview.invalidRows),
            _metric('Duplicates', preview.duplicateRows),
          ],
        ),
        const SizedBox(height: 12),
        if (preview.rows.any((row) => row.errors.isNotEmpty))
          ...preview.rows
              .where((row) => row.errors.isNotEmpty)
              .take(100)
              .map(
                (row) => ListTile(
                  leading: const Icon(
                    Icons.error_outline,
                    color: AppColors.danger,
                  ),
                  title: Text('Spreadsheet row ${row.rowNumber}'),
                  subtitle: Text(row.errors.join('\n')),
                ),
              ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('Back to mapping'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: preview.canImport
                  ? () => setState(() => _step = 3)
                  : null,
              child: const Text('Continue to confirmation'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metric(String label, int value) =>
      Chip(label: Text('$label: $value'));

  Widget _confirmStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Ready to import ${_preview?.validRows ?? 0} students. The backend will revalidate every row and import all rows together or none.',
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _confirmed,
        onChanged: (value) => setState(() => _confirmed = value ?? false),
        title: const Text('I confirm that these students should be imported.'),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _confirmed && !_busy ? _commit : null,
          icon: const Icon(Icons.check),
          label: Text(_busy ? 'Importing…' : 'Import students'),
        ),
      ),
    ],
  );

  Widget _summaryStep() => Column(
    children: [
      const Icon(Icons.check_circle, size: 52, color: Colors.green),
      const SizedBox(height: 8),
      Text(
        _summary?.message ?? 'Import complete',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 4),
      Text(
        '${_summary?.importedCount ?? 0} imported • ${_summary?.skippedCount ?? 0} skipped',
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('Return to students'),
      ),
    ],
  );
}
