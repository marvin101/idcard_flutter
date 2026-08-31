import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/bulk_photo_import.dart';
import '../navigation/app_navigation.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/authenticated_app_bar.dart';

typedef BulkPhotoFilePicker = Future<PlatformFile?> Function();

class BulkPhotoImportScreen extends StatefulWidget {
  const BulkPhotoImportScreen({
    super.key,
    required this.schoolUuid,
    required this.schoolName,
    required this.api,
    this.pickArchive,
  });

  final String schoolUuid;
  final String schoolName;
  final ApiService api;
  final BulkPhotoFilePicker? pickArchive;

  @override
  State<BulkPhotoImportScreen> createState() => _BulkPhotoImportScreenState();
}

class _BulkPhotoImportScreenState extends State<BulkPhotoImportScreen> {
  int _step = 0;
  bool _busy = false;
  bool _confirmed = false;
  String? _selectedFilename;
  int? _selectedSize;
  String? _error;
  Future<void> Function()? _retry;
  BulkPhotoUploadResponse? _upload;
  BulkPhotoPreviewResponse? _preview;
  BulkPhotoCommitResponse? _summary;

  Future<PlatformFile?> _pickFile() async {
    if (widget.pickArchive != null) return widget.pickArchive!();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: true,
    );
    return result?.files.single;
  }

  Future<void> _pickAndUpload() async {
    final file = await _pickFile();
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() {
        _error = 'The selected ZIP could not be read. Please choose it again.';
        _retry = null;
      });
      return;
    }
    if (!file.name.toLowerCase().endsWith('.zip')) {
      setState(() {
        _error = 'Choose a ZIP archive containing student photos.';
        _retry = null;
      });
      return;
    }
    setState(() {
      _selectedFilename = file.name;
      _selectedSize = file.size;
    });
    await _uploadArchive(file.name, bytes);
  }

  Future<void> _uploadArchive(String filename, Uint8List bytes) async {
    _startRequest();
    try {
      final upload = await widget.api.uploadBulkStudentPhotos(
        schoolUuid: widget.schoolUuid,
        filename: filename,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() => _upload = upload);
      await _loadPreview();
    } catch (error) {
      if (!mounted) return;
      _showError(error, retry: () => _uploadArchive(filename, bytes));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadPreview() async {
    final upload = _upload;
    if (upload == null) return;
    _startRequest();
    try {
      final preview = await widget.api.previewBulkStudentPhotos(
        schoolUuid: widget.schoolUuid,
        manifestUuid: upload.manifestUuid,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _step = 1;
      });
    } catch (error) {
      if (!mounted) return;
      _showError(error, retry: _loadPreview);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startRequest() {
    setState(() {
      _busy = true;
      _error = null;
      _retry = null;
    });
  }

  void _showError(Object error, {required Future<void> Function() retry}) {
    final message = error is ApiException
        ? switch (error.statusCode) {
            403 => 'Permission denied: ${error.message}',
            404 => 'Import not found: ${error.message}',
            409 => 'This import was already completed. ${error.message}',
            410 => 'This import has expired. ${error.message}',
            422 => 'The archive could not be processed: ${error.message}',
            _ => error.message,
          }
        : 'Could not reach the server. Check your connection and try again.';
    setState(() {
      _busy = false;
      _error = message;
      _retry = retry;
    });
  }

  Future<void> _commit() async {
    final preview = _preview;
    if (!_confirmed || preview == null || !preview.canCommit) return;
    _startRequest();
    try {
      final summary = await widget.api.commitBulkStudentPhotos(
        schoolUuid: widget.schoolUuid,
        manifestUuid: preview.manifestUuid,
        confirmed: true,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _step = 3;
      });
    } catch (error) {
      if (!mounted) return;
      _showError(error, retry: _commit);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startAnother() {
    setState(() {
      _step = 0;
      _confirmed = false;
      _selectedFilename = null;
      _selectedSize = null;
      _error = null;
      _retry = null;
      _upload = null;
      _preview = null;
      _summary = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AuthenticatedAppBar(
      title: Text('Bulk Photo Import — ${widget.schoolName}'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                TextButton.icon(
                  key: const Key('bulk-photo-back-to-students'),
                  onPressed: () => AppNavigation.navigateBack(
                    context,
                    AppRoutes.bulkPhotoImport,
                    result: _summary != null,
                  ),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Students'),
                ),
              ],
            ),
            if (_error != null) _errorCard(),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Stepper(
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
                      title: const Text('Preview'),
                      isActive: _step >= 1,
                      state: _step > 1 ? StepState.complete : StepState.indexed,
                      content: _previewStep(),
                    ),
                    Step(
                      title: const Text('Confirm'),
                      isActive: _step >= 2,
                      state: _step > 2 ? StepState.complete : StepState.indexed,
                      content: _confirmStep(),
                    ),
                    Step(
                      title: const Text('Summary'),
                      isActive: _step >= 3,
                      state: _step == 3
                          ? StepState.complete
                          : StepState.indexed,
                      content: _summaryStep(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _errorCard() => Card(
    key: const Key('bulk-photo-error'),
    elevation: 0,
    color: const Color(0xffffeeee),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
          if (_retry != null)
            TextButton(
              onPressed: _busy ? null : _retry,
              child: const Text('Retry'),
            ),
        ],
      ),
    ),
  );

  Widget _uploadStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Choose a ZIP archive. Each image filename must match the student admission number.',
      ),
      const SizedBox(height: 8),
      const Text('Accepted images: JPG, JPEG, PNG and WEBP.'),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('bulk-photo-choose-archive'),
        onPressed: _busy ? null : _pickAndUpload,
        icon: _busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.folder_zip_outlined),
        label: Text(_busy ? 'Uploading…' : 'Choose ZIP'),
      ),
      if (_selectedFilename != null) ...[
        const SizedBox(height: 12),
        Text(
          'Selected: $_selectedFilename${_selectedSize == null ? '' : ' (${_formatBytes(_selectedSize!)})'}',
          key: const Key('bulk-photo-selected-file'),
        ),
      ],
    ],
  );

  Widget _previewStep() {
    final preview = _preview;
    if (preview == null) {
      return _busy
          ? const LinearProgressIndicator()
          : const Text('Upload an archive to generate its preview.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _countCards([
          ('Total Files', preview.totalFiles),
          ('Ready', preview.readyCount),
          ('Unmatched', preview.unmatchedCount),
          ('Invalid', preview.invalidCount),
          ('Replacements', preview.replacementCount),
        ]),
        const SizedBox(height: 16),
        _previewTable(preview.items),
        if (!preview.canCommit) ...[
          const SizedBox(height: 12),
          const Text(
            'Unmatched or invalid files must be corrected before commit.',
            key: Key('bulk-photo-cannot-commit-message'),
            style: TextStyle(color: AppColors.danger),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const Key('bulk-photo-continue'),
            onPressed: _busy || !preview.canCommit
                ? null
                : () => setState(() => _step = 2),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continue to confirmation'),
          ),
        ),
      ],
    );
  }

  Widget _confirmStep() {
    final preview = _preview;
    if (preview == null) return const Text('Preview the archive first.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${preview.readyCount} photos will be uploaded.'),
        Text('${preview.replacementCount} existing photos will be replaced.'),
        const SizedBox(height: 12),
        CheckboxListTile(
          key: const Key('bulk-photo-confirmation'),
          contentPadding: EdgeInsets.zero,
          value: _confirmed,
          onChanged: _busy
              ? null
              : (value) => setState(() => _confirmed = value == true),
          title: const Text(
            'I confirm that these student photos should be uploaded.',
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('bulk-photo-commit'),
          onPressed: _busy || !_confirmed ? null : _commit,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload_outlined),
          label: Text(_busy ? 'Uploading photos…' : 'Upload photos'),
        ),
      ],
    );
  }

  Widget _summaryStep() {
    final summary = _summary;
    if (summary == null) {
      return const Text('Complete the import to see results.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              summary.completed ? Icons.check_circle : Icons.warning_rounded,
              color: summary.completed ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 8),
            Text(
              summary.completed ? 'Import completed' : 'Import incomplete',
              key: const Key('bulk-photo-completed-status'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _countCards([
          ('Total Files', summary.totalFiles),
          ('Uploaded', summary.uploadedCount),
          ('Failed', summary.failedCount),
          ('Unmatched', summary.unmatchedCount),
          ('Invalid', summary.invalidCount),
          ('Replacements', summary.replacementCount),
        ]),
        if (summary.items.isNotEmpty) ...[
          const SizedBox(height: 16),
          _commitTable(summary.items),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              key: const Key('bulk-photo-summary-students'),
              onPressed: () => AppNavigation.navigateBack(
                context,
                AppRoutes.bulkPhotoImport,
                result: true,
              ),
              icon: const Icon(Icons.people_outline),
              label: const Text('Back to Students'),
            ),
            OutlinedButton.icon(
              key: const Key('bulk-photo-summary-cards'),
              onPressed: () =>
                  AppNavigation.navigateToModule(context, AppRoutes.cards),
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Open Cards'),
            ),
            OutlinedButton.icon(
              key: const Key('bulk-photo-start-another'),
              onPressed: _startAnother,
              icon: const Icon(Icons.replay),
              label: const Text('Start Another Import'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _countCards(List<(String, int)> values) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final value in values)
        Container(
          key: Key(
            'bulk-photo-count-${value.$1.toLowerCase().replaceAll(' ', '-')}',
          ),
          width: 145,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffe4e8f0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.$1,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                '${value.$2}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
    ],
  );

  Widget _previewTable(List<BulkPhotoItem> items) => _table(
    columns: const [
      'Filename',
      'Admission No.',
      'Student Name',
      'Status',
      'Existing Photo',
      'Detail / Error',
    ],
    rows: [
      for (final item in items)
        [
          Text(item.filename),
          Text(item.admissionNo ?? '—'),
          Text(item.studentName ?? '—'),
          _statusChip(
            item.hasExistingPhoto && item.status.toLowerCase() == 'ready'
                ? 'replacement'
                : item.status,
          ),
          Text(item.hasExistingPhoto ? 'Replacement' : 'No'),
          Text(item.detail ?? '—'),
        ],
    ],
  );

  Widget _commitTable(List<BulkPhotoCommitItem> items) => _table(
    columns: const [
      'Filename',
      'Admission No.',
      'Student Name',
      'Status',
      'Detail / Error',
    ],
    rows: [
      for (final item in items)
        [
          Text(item.filename),
          Text(item.admissionNo ?? '—'),
          Text(item.studentName ?? '—'),
          _statusChip(item.status),
          Text(item.detail ?? '—'),
        ],
    ],
  );

  Widget _table({
    required List<String> columns,
    required List<List<Widget>> rows,
  }) => SizedBox(
    height: rows.length > 6 ? 420 : null,
    child: Scrollbar(
      thumbVisibility: rows.length > 6,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              for (final column in columns) DataColumn(label: Text(column)),
            ],
            rows: [
              for (final row in rows)
                DataRow(cells: [for (final cell in row) DataCell(cell)]),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _statusChip(String status) {
    final normalized = status.toLowerCase();
    final label = _titleCase(status);
    final color = switch (normalized) {
      'ready' || 'uploaded' || 'success' => AppColors.success,
      'replacement' => AppColors.warning,
      'unmatched' || 'invalid' || 'failed' || 'error' => AppColors.danger,
      _ => AppColors.primaryLight,
    };
    return Chip(
      key: Key('bulk-photo-status-$normalized'),
      label: Text(label),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
    );
  }

  String _titleCase(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}
