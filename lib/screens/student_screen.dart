import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/api_student.dart';
import '../models/academic_session.dart';
import '../models/school_class.dart';
import '../models/section.dart';
import '../navigation/app_navigation.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/authenticated_app_bar.dart';
import '../widgets/student_lifecycle_badge.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({
    super.key,
    required this.schoolUuid,
    required this.schoolName,
    required this.api,
    required this.canEdit,
    required this.canDelete,
    this.canVerify = false,
    this.canViewHistory = false,
    this.canMarkPrinted = false,
  });

  final String schoolUuid;
  final String schoolName;
  final ApiService api;
  final bool canEdit;
  final bool canDelete;
  final bool canVerify;
  final bool canViewHistory;
  final bool canMarkPrinted;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  bool _loading = true;
  String? _error;
  List<ApiStudent> _students = [];
  String _search = '';

  List<AcademicSession> _sessions = [];
  List<SchoolClass> _classes = [];
  List<SchoolSection> _sections = [];

  String? _selectedSessionUuid;
  String? _selectedClassUuid;
  String? _selectedSectionUuid;
  String? _verificationStatus;
  bool? _printed;
  final Set<String> _selectedStudentUuids = {};

  bool _loadingFilters = true;
  bool _loadingSections = false;
  String? _sectionError;

  @override
  void initState() {
    super.initState();
    _loadFilterData();
  }

  Future<void> _loadFilterData() async {
    setState(() {
      _loadingFilters = true;
      _error = null;
    });

    try {
      final sessions = await widget.api.getAcademicSessions(widget.schoolUuid);

      final classes = await widget.api.getClasses(widget.schoolUuid);

      if (!mounted) return;

      setState(() {
        _sessions = sessions;
        _classes = classes;
        _selectedSessionUuid = null;
        _selectedClassUuid = null;
        _selectedSectionUuid = null;
        _sections = [];
        _loadingFilters = false;
      });

      await _loadStudents();
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingFilters = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingFilters = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final students = await widget.api.getStudents(
        schoolUuid: widget.schoolUuid,
        sessionUuid: _selectedSessionUuid,
        classUuid: _selectedClassUuid,
        sectionUuid: _selectedSectionUuid,
        verificationStatus: _verificationStatus,
        printed: _printed,
      );

      if (!mounted) return;

      setState(() {
        _students = students;
        _selectedStudentUuids.removeWhere(
          (uuid) => !students.any((student) => student.uuid == uuid),
        );
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectSession(String? sessionUuid) async {
    setState(() {
      _selectedSessionUuid = sessionUuid;
      _selectedClassUuid = null;
      _selectedSectionUuid = null;
      _sections = [];
      _sectionError = null;
    });

    await _loadStudents();
  }

  Future<void> _selectClass(String? classUuid) async {
    setState(() {
      _selectedClassUuid = classUuid;
      _selectedSectionUuid = null;
      _sections = [];
      _sectionError = null;
    });

    if (classUuid != null) {
      setState(() {
        _loadingSections = true;
      });

      try {
        final sections = await widget.api.getSections(
          schoolUuid: widget.schoolUuid,
          classUuid: classUuid,
        );

        if (!mounted) return;

        setState(() {
          _sections = sections;
          _loadingSections = false;
        });
      } on ApiException catch (e) {
        if (!mounted) return;

        setState(() {
          _loadingSections = false;
          _sectionError = e.message;
        });
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _loadingSections = false;
          _sectionError = e.toString();
        });
      }
    }

    await _loadStudents();
  }

  Future<void> _selectSection(String? sectionUuid) async {
    setState(() {
      _selectedSectionUuid = sectionUuid;
    });

    await _loadStudents();
  }

  List<ApiStudent> get _filteredStudents {
    final query = _search.trim().toLowerCase();

    if (query.isEmpty) {
      return _students;
    }

    return _students.where((student) {
      return student.fullName.toLowerCase().contains(query) ||
          student.admissionNo.toLowerCase().contains(query) ||
          (student.rollNo?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> _editStudent(ApiStudent student) async {
    await AppNavigation.navigateToWorkflow<void>(
      context,
      AppRoutes.editStudent,
      arguments: student,
    );

    if (mounted) {
      await _loadStudents();
    }
  }

  Future<void> _deleteStudent(ApiStudent student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete student?'),
        content: Text('Are you sure you want to delete ${student.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.api.deleteStudent(
        schoolUuid: widget.schoolUuid,
        studentUuid: student.uuid,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student deleted successfully')),
      );

      await _loadStudents();
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _verify(ApiStudent student) async {
    await _runLifecycleAction(
      () => widget.api.updateStudentVerification(
        schoolUuid: widget.schoolUuid,
        studentUuid: student.uuid,
        status: 'verified',
      ),
      'Student verified',
    );
  }

  Future<void> _needsCorrection(ApiStudent student) async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) =>
          _CorrectionNoteDialog(initialNote: student.correctionNote),
    );
    if (note == null || !mounted) return;
    await _runLifecycleAction(
      () => widget.api.updateStudentVerification(
        schoolUuid: widget.schoolUuid,
        studentUuid: student.uuid,
        status: 'needs_correction',
        note: note,
      ),
      'Correction requested',
    );
  }

  Future<void> _markPrinted(ApiStudent student) async {
    await _runLifecycleAction(
      () => widget.api.markStudentPrinted(
        schoolUuid: widget.schoolUuid,
        studentUuid: student.uuid,
      ),
      student.isPrinted ? 'Reprint recorded' : 'Card marked printed',
    );
  }

  Future<void> _runLifecycleAction(
    Future<ApiStudent> Function() action,
    String success,
  ) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
      await _loadStudents();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _runBatch(bool verify) async {
    if (_selectedStudentUuids.isEmpty) return;
    try {
      if (verify) {
        await widget.api.batchVerifyStudents(
          schoolUuid: widget.schoolUuid,
          studentUuids: _selectedStudentUuids.toList(),
        );
      } else {
        await widget.api.batchMarkStudentsPrinted(
          schoolUuid: widget.schoolUuid,
          studentUuids: _selectedStudentUuids.toList(),
        );
      }
      if (!mounted) return;
      setState(_selectedStudentUuids.clear);
      await _loadStudents();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = _filteredStudents;

    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      appBar: AuthenticatedAppBar(
        title: Text('Students — ${widget.schoolName}'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: EdgeInsets.all(constraints.maxWidth > 700 ? 28 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    Expanded(child: _buildContent(students)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name, admission number or roll number',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xffe4e8f0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xffe4e8f0)),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _search = value;
                  });
                },
              ),
            ),
            if (widget.canEdit) ...[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                key: const Key('bulk-photo-import-action'),
                onPressed: () async {
                  final imported = await AppNavigation.navigateToWorkflow<bool>(
                    context,
                    AppRoutes.bulkPhotoImport,
                  );
                  if (imported == true && mounted) await _loadStudents();
                },
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Bulk Photos'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final imported = await AppNavigation.navigateToWorkflow<bool>(
                    context,
                    AppRoutes.studentImport,
                  );
                  if (imported == true && mounted) await _loadStudents();
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Bulk Import'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () async {
                  await AppNavigation.navigateToWorkflow<void>(
                    context,
                    AppRoutes.addStudent,
                  );

                  if (mounted) {
                    await _loadStudents();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Student'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _buildFilters(),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 210,
              child: _buildDropdown<String>(
                label: 'Verification Status',
                value: _verificationStatus,
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Statuses')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(
                    value: 'needs_correction',
                    child: Text('Needs Correction'),
                  ),
                  DropdownMenuItem(value: 'verified', child: Text('Verified')),
                ],
                onChanged: (value) async {
                  setState(() => _verificationStatus = value);
                  await _loadStudents();
                },
              ),
            ),
            SizedBox(
              width: 180,
              child: _buildDropdown<bool>(
                label: 'Printed',
                value: _printed,
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Records')),
                  DropdownMenuItem(value: false, child: Text('Not Printed')),
                  DropdownMenuItem(value: true, child: Text('Printed')),
                ],
                onChanged: (value) async {
                  setState(() => _printed = value);
                  await _loadStudents();
                },
              ),
            ),
            if (_selectedStudentUuids.isNotEmpty && widget.canVerify)
              FilledButton.icon(
                key: const Key('batch-verify-action'),
                onPressed: () => _runBatch(true),
                icon: const Icon(Icons.verified_outlined),
                label: Text(
                  'Verify Selected (${_selectedStudentUuids.length})',
                ),
              ),
            if (_selectedStudentUuids.isNotEmpty && widget.canMarkPrinted)
              OutlinedButton.icon(
                key: const Key('batch-mark-printed-action'),
                onPressed: () => _runBatch(false),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Mark Selected Printed'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilters() {
    if (_loadingFilters) {
      return const Card(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading academic filters...'),
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 750;

        final sessionDropdown = _buildDropdown<String>(
          label: 'Academic Session',
          value: _selectedSessionUuid,
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All Sessions'),
            ),
            ..._sessions.map(
              (session) => DropdownMenuItem<String>(
                value: session.uuid,
                child: Text(session.name),
              ),
            ),
          ],
          onChanged: _selectSession,
        );

        final classDropdown = _buildDropdown<String>(
          label: 'Class',
          value: _selectedClassUuid,
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All Classes'),
            ),
            ..._classes.map(
              (schoolClass) => DropdownMenuItem<String>(
                value: schoolClass.uuid,
                child: Text(schoolClass.name),
              ),
            ),
          ],
          onChanged: _selectClass,
        );

        final sectionDropdown = _loadingSections
            ? const InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Section',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Loading sections...'),
                  ],
                ),
              )
            : _sectionError != null
            ? InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Section',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _sectionError!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              )
            : _buildDropdown<String>(
                label: 'Section',
                value: _selectedSectionUuid,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Sections'),
                  ),
                  ..._sections.map(
                    (section) => DropdownMenuItem<String>(
                      value: section.uuid,
                      child: Text(section.name),
                    ),
                  ),
                ],
                onChanged: _selectedClassUuid == null ? null : _selectSection,
              );

        if (narrow) {
          return Column(
            children: [
              sessionDropdown,
              const SizedBox(height: 10),
              classDropdown,
              const SizedBox(height: 10),
              sectionDropdown,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: sessionDropdown),
            const SizedBox(width: 10),
            Expanded(child: classDropdown),
            const SizedBox(width: 10),
            Expanded(child: sectionDropdown),
          ],
        );
      },
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffe4e8f0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffe4e8f0)),
        ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildContent(List<ApiStudent> students) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _loadStudents);
    }

    if (students.isEmpty) {
      return const Center(
        child: Text(
          'No students found.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xffe4e8f0)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: students.length,
        // ignore: unnecessary_underscores
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final student = students[index];

          return ListTile(
            leading: Checkbox(
              value: _selectedStudentUuids.contains(student.uuid),
              onChanged: widget.canVerify || widget.canMarkPrinted
                  ? (selected) => setState(() {
                      if (selected == true) {
                        _selectedStudentUuids.add(student.uuid);
                      } else {
                        _selectedStudentUuids.remove(student.uuid);
                      }
                    })
                  : null,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    student.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                StudentLifecycleBadge(status: student.lifecycleStatus),
              ],
            ),
            subtitle: Text(
              'Admission: ${student.admissionNo}'
              '${student.rollNo == null ? '' : '  •  Roll: ${student.rollNo}'}'
              '${student.verifiedAt == null ? '' : '\nVerified ${student.verifiedByName == null ? '' : 'by ${student.verifiedByName} '}at ${student.verifiedAt!.toLocal()}'}'
              '${student.printedAt == null ? '' : '\nLast printed: ${student.printedAt!.toLocal()} • Count: ${student.printCount}'}',
            ),
            trailing:
                widget.canEdit ||
                    widget.canDelete ||
                    widget.canVerify ||
                    widget.canViewHistory ||
                    widget.canMarkPrinted
                ? PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editStudent(student);
                      } else if (value == 'delete') {
                        _deleteStudent(student);
                      } else if (value == 'verify') {
                        _verify(student);
                      } else if (value == 'correction') {
                        _needsCorrection(student);
                      } else if (value == 'printed') {
                        _markPrinted(student);
                      } else if (value == 'history') {
                        AppNavigation.navigateToPage<void>(
                          context,
                          AppRoutes.studentHistory(student.uuid),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      if (widget.canEdit)
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (widget.canDelete)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      if (widget.canVerify)
                        const PopupMenuItem(
                          value: 'verify',
                          child: Text('Verify'),
                        ),
                      if (widget.canVerify)
                        const PopupMenuItem(
                          value: 'correction',
                          child: Text('Needs Correction'),
                        ),
                      if (widget.canMarkPrinted && student.isVerified)
                        PopupMenuItem(
                          value: 'printed',
                          child: Text(
                            student.isPrinted
                                ? 'Record Reprint'
                                : 'Mark Printed',
                          ),
                        ),
                      if (widget.canViewHistory)
                        const PopupMenuItem(
                          value: 'history',
                          child: Text('History'),
                        ),
                    ],
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _CorrectionNoteDialog extends StatefulWidget {
  const _CorrectionNoteDialog({this.initialNote});

  final String? initialNote;

  @override
  State<_CorrectionNoteDialog> createState() => _CorrectionNoteDialogState();
}

class _CorrectionNoteDialogState extends State<_CorrectionNoteDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialNote,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Needs Correction'),
    content: TextField(
      key: const Key('correction-note-field'),
      controller: _controller,
      autofocus: true,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'Correction note',
        errorText: _error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('save-correction-note'),
        onPressed: () {
          final value = _controller.text.trim();
          if (value.isEmpty) {
            setState(() => _error = 'Correction note is required');
            return;
          }
          Navigator.pop(context, value);
        },
        child: const Text('Save'),
      ),
    ],
  );
}
