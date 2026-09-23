import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/student_import.dart';
import '../models/api_personnel.dart';
import '../navigation/app_navigation.dart';
import '../services/api_service.dart';
import '../services/file_download.dart';
import '../theme/app_colors.dart';
import '../widgets/authenticated_app_bar.dart';

typedef StudentImportFilePicker = Future<PlatformFile?> Function();
typedef StudentImportTemplateSaver =
    Future<void> Function(StudentImportTemplateFile file);

class StudentImportScreen extends StatefulWidget {
  const StudentImportScreen({
    super.key,
    required this.schoolUuid,
    required this.schoolName,
    required this.api,
    this.personnelType,
    this.pickFile,
    this.saveTemplate,
  });

  final String schoolUuid;
  final String schoolName;
  final ApiService api;
  final PersonnelType? personnelType;
  final StudentImportFilePicker? pickFile;
  final StudentImportTemplateSaver? saveTemplate;

  @override
  State<StudentImportScreen> createState() => _StudentImportScreenState();
}

class _StudentImportScreenState extends State<StudentImportScreen> {
  int _step = 0;
  bool _busy = false;
  bool _downloadingTemplate = false;
  bool _confirmed = false;
  String? _error;
  StudentImportUpload? _upload;
  StudentImportPreview? _preview;
  StudentImportSummary? _summary;
  final Map<String, String?> _mappingBySource = {};

  bool get _isPersonnel => widget.personnelType != null;
  String get _singular => widget.personnelType?.label ?? 'Student';
  String get _plural => widget.personnelType?.pluralLabel ?? 'Students';
  String get _route => switch (widget.personnelType) {
    PersonnelType.teacher => AppRoutes.teacherImport,
    PersonnelType.staff => AppRoutes.staffImport,
    null => AppRoutes.studentImport,
  };

  List<StudentImportMapping> get _mappings => [
    for (final entry in _mappingBySource.entries)
      if (entry.value != null)
        StudentImportMapping(
          sourceColumn: entry.key,
          targetField: entry.value!,
        ),
  ];

  Future<void> _pickAndUpload() async {
    setState(() => _error = null);
    PlatformFile? file;
    try {
      if (widget.pickFile != null) {
        file = await widget.pickFile!();
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['csv', 'xlsx'],
          withData: true,
        );
        file = result?.files.single;
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not open the file picker. Please try again.';
        });
      }
      return;
    }
    if (!mounted) return;
    if (file == null) {
      return;
    }
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() {
        _busy = false;
        _error = 'The selected file could not be read.';
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final upload = _isPersonnel
          ? await widget.api.uploadPersonnelImport(
              schoolUuid: widget.schoolUuid,
              personnelType: widget.personnelType!,
              filename: file.name,
              bytes: bytes,
            )
          : await widget.api.uploadStudentImport(
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
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not upload the file. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadTemplate() async {
    setState(() {
      _downloadingTemplate = true;
      _error = null;
    });
    try {
      final file = _isPersonnel
          ? await widget.api.downloadPersonnelImportTemplate(
              schoolUuid: widget.schoolUuid,
              personnelType: widget.personnelType!,
            )
          : await widget.api.downloadStudentImportTemplate(
              schoolUuid: widget.schoolUuid,
            );
      if (widget.saveTemplate != null) {
        await widget.saveTemplate!(file);
      } else {
        await saveDownloadedFile(
          bytes: file.bytes,
          filename: file.filename,
          contentType: file.contentType,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('XLSX template downloaded.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not download the XLSX template. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingTemplate = false);
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

  void _chooseAnotherFile() {
    setState(() {
      _step = 0;
      _confirmed = false;
      _error = null;
      _upload = null;
      _preview = null;
      _summary = null;
      _mappingBySource.clear();
    });
  }

  Future<void> _runPreview() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = _isPersonnel
          ? await widget.api.previewPersonnelImport(
              schoolUuid: widget.schoolUuid,
              personnelType: widget.personnelType!,
              uploadId: _upload!.uploadId,
              mappings: _mappings,
            )
          : await widget.api.previewStudentImport(
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
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not generate the preview. Check your connection and try again.',
        );
      }
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
      final summary = _isPersonnel
          ? await widget.api.commitPersonnelImport(
              schoolUuid: widget.schoolUuid,
              personnelType: widget.personnelType!,
              uploadId: _upload!.uploadId,
              mappings: _mappings,
              confirmed: true,
            )
          : await widget.api.commitStudentImport(
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Could not complete the import. Check your connection and try again.';
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
      title: Text('Bulk $_singular Import — ${widget.schoolName}'),
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
        'Download this school’s pre-formatted template, fill it in, then upload the completed XLSX or a UTF-8 CSV.',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            key: const Key('student-import-download-template'),
            onPressed: _busy || _downloadingTemplate ? null : _downloadTemplate,
            icon: const Icon(Icons.download),
            label: Text(
              _downloadingTemplate ? 'Downloading…' : 'Download XLSX Template',
            ),
          ),
          FilledButton.icon(
            onPressed: _busy || _downloadingTemplate ? null : _pickAndUpload,
            icon: const Icon(Icons.upload_file),
            label: Text(_busy ? 'Uploading…' : 'Choose file'),
          ),
        ],
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
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Map each spreadsheet column to at most one ${_singular.toLowerCase()} field. Required targets are marked *.',
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
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : _chooseAnotherFile,
                child: const Text('Choose another file'),
              ),
              FilledButton(
                onPressed: _busy ? null : _runPreview,
                child: Text(_busy ? 'Validating…' : 'Preview import'),
              ),
            ],
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
        _previewTable(preview),
        if (preview.rows.length > 100)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Showing the first 100 of ${preview.rows.length} rows. All rows were validated.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _chooseAnotherFile,
              child: const Text('Choose another file'),
            ),
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

  Widget _previewTable(StudentImportPreview preview) {
    final labelByKey = {
      for (final field
          in _upload?.targetFields ?? const <StudentImportTargetField>[])
        field.key: field.label,
    };
    final visibleFields = <String>[];
    for (final mapping in _mappings) {
      if (!visibleFields.contains(mapping.targetField)) {
        visibleFields.add(mapping.targetField);
      }
    }

    return Card(
      key: const Key('student-import-preview-table'),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            const DataColumn(label: Text('Row')),
            const DataColumn(label: Text('Status')),
            for (final field in visibleFields)
              DataColumn(label: Text(labelByKey[field] ?? field)),
            const DataColumn(label: Text('Validation')),
          ],
          rows: [
            for (final row in preview.rows.take(100))
              DataRow(
                color: row.errors.isEmpty
                    ? null
                    : WidgetStateProperty.all(
                        AppColors.danger.withValues(alpha: 0.06),
                      ),
                cells: [
                  DataCell(Text('${row.rowNumber}')),
                  DataCell(
                    Icon(
                      row.errors.isEmpty
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      color: row.errors.isEmpty
                          ? Colors.green
                          : AppColors.danger,
                      semanticLabel: row.errors.isEmpty ? 'Valid' : 'Invalid',
                    ),
                  ),
                  for (final field in visibleFields)
                    DataCell(Text('${row.values[field] ?? ''}')),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        row.errors.isEmpty
                            ? 'Ready to import'
                            : row.errors.join('\n'),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _confirmStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Ready to import ${_preview?.validRows ?? 0} ${_plural.toLowerCase()}. The backend will revalidate every row and import all rows together or none.',
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _confirmed,
        onChanged: (value) => setState(() => _confirmed = value ?? false),
        title: Text(
          'I confirm that these ${_plural.toLowerCase()} should be imported.',
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _confirmed && !_busy ? _commit : null,
          icon: const Icon(Icons.check),
          label: Text(_busy ? 'Importing…' : 'Import ${_plural.toLowerCase()}'),
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
        key: const Key('student-import-return-to-students'),
        onPressed: () =>
            AppNavigation.navigateBack(context, _route, result: true),
        child: Text('Return to ${_plural.toLowerCase()}'),
      ),
    ],
  );
}
