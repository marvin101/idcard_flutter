import 'dart:async';

import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/academic_session.dart';
import '../models/api_student.dart';
import '../models/school_class.dart';
import '../models/section.dart';
import '../navigation/app_navigation.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/authenticated_app_bar.dart';
import '../widgets/student_lifecycle_badge.dart';
import '../widgets/student_verification_link_dialog.dart';

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
  Timer? _searchTimer;

  int _request = 0;
  int _offset = 0;
  int _total = 0;

  bool _hasMore = false;

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

  StudentLifecycleSelection get _selection =>
      StudentLifecycleSelection.from(_students, _selectedStudentUuids);

  @override
  void initState() {
    super.initState();
    _loadFilterData();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _request++;
    super.dispose();
  }

  Future<void> _loadFilterData() async {
    setState(() {
      _loadingFilters = true;
      _error = null;
    });

    try {
      final sessions = await widget.api.getAcademicSessions(widget.schoolUuid);

      final classes = await widget.api.getClasses(widget.schoolUuid);

      if (!mounted) {
        return;
      }

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
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingFilters = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingFilters = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadStudents({int offset = 0}) async {
    final request = ++_request;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page = await widget.api.getStudentsPage(
        offset: offset,
        limit: 100,
        search: _search,
        schoolUuid: widget.schoolUuid,
        sessionUuid: _selectedSessionUuid,
        classUuid: _selectedClassUuid,
        sectionUuid: _selectedSectionUuid,
        verificationStatus: _verificationStatus,
        printed: _printed,
      );

      if (!mounted || request != _request) {
        return;
      }

      final students = page.items;

      setState(() {
        _students = students;

        _offset = offset;
        _total = page.total;
        _hasMore = page.hasMore;

        _selectedStudentUuids.removeWhere(
          (uuid) => !students.any((student) => student.uuid == uuid),
        );

        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || request != _request) {
        return;
      }

      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) {
        return;
      }

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

        if (!mounted) {
          return;
        }

        setState(() {
          _sections = sections;
          _loadingSections = false;
        });
      } on ApiException catch (e) {
        if (!mounted) {
          return;
        }

        setState(() {
          _loadingSections = false;
          _sectionError = e.message;
        });
      } catch (e) {
        if (!mounted) {
          return;
        }

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
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.api.deleteStudent(
        schoolUuid: widget.schoolUuid,
        studentUuid: student.uuid,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student deleted successfully')),
      );

      await _loadStudents();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

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

    if (note == null || !mounted) {
      return;
    }

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('confirm-mark-printed-dialog'),
        title: Text(
          student.isPrinted ? 'Record card reprint?' : 'Mark card printed?',
        ),
        content: Text(
          'This records print #${student.printCount + 1} for '
          '${student.fullName}. '
          'Downloading a PDF does not mark a card printed.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-mark-printed-action'),
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: Text(student.isPrinted ? 'Record Reprint' : 'Mark Printed'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

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

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));

      await _loadStudents();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _runBatch(bool verify) async {
    if (_selectedStudentUuids.isEmpty) {
      return;
    }

    final selection = _selection;

    if (verify && !selection.canBatchVerify) {
      return;
    }

    if (!verify && !selection.canBatchMarkPrinted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: Key(
          verify ? 'confirm-batch-verify-dialog' : 'confirm-batch-print-dialog',
        ),
        title: Text(
          verify
              ? 'Verify ${selection.selectedCount} students?'
              : 'Mark ${selection.selectedCount} cards printed?',
        ),
        content: Text(
          verify
              ? 'All selected Pending and Needs Correction records '
                    'will become Verified.'
              : '${selection.reprintCount} selected card(s) are '
                    'reprints. This action records production; '
                    'PDF download alone does not.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: Key(
              verify
                  ? 'confirm-batch-verify-action'
                  : 'confirm-batch-print-action',
            ),
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: Text(verify ? 'Verify All' : 'Mark All Printed'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

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

      if (!mounted) {
        return;
      }

      setState(_selectedStudentUuids.clear);

      await _loadStudents();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = _filteredStudents;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AuthenticatedAppBar(
        title: Text('Students — ${widget.schoolName}'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(constraints.maxWidth > 700 ? 28 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPageHeading(),
                    const SizedBox(height: 20),
                    _buildHeader(),
                    const SizedBox(height: 20),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 260),
                      child: _buildContent(students),
                    ),
                    const SizedBox(height: 12),
                    _buildPagination(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageHeading() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;

        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Students',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Manage student records, verification and '
              'ID-card preparation.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        );

        final addButton = widget.canEdit
            ? FilledButton.icon(
                key: const Key('add-student-primary-action'),
                onPressed: () async {
                  await AppNavigation.navigateToWorkflow<void>(
                    context,
                    AppRoutes.addStudent,
                  );

                  if (mounted) {
                    await _loadStudents();
                  }
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Student'),
              )
            : null;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              if (addButton != null) ...[
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: addButton),
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: heading),
            ?addButton,
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    final selection = _selection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;

            final searchField = TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, admission number or roll number',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _search = value;
                });

                _searchTimer?.cancel();

                _searchTimer = Timer(
                  const Duration(milliseconds: 300),
                  () => _loadStudents(),
                );
              },
            );

            final moreActions = widget.canEdit ? _buildMoreActions() : null;

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchField,
                  if (moreActions != null) ...[
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerLeft, child: moreActions),
                  ],
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: searchField),
                if (moreActions != null) ...[
                  const SizedBox(width: 12),
                  moreActions,
                ],
              ],
            );
          },
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
                  setState(() {
                    _verificationStatus = value;
                  });

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
                  setState(() {
                    _printed = value;
                  });

                  await _loadStudents();
                },
              ),
            ),
            if (_selectedStudentUuids.isNotEmpty && widget.canVerify)
              FilledButton.icon(
                key: const Key('batch-verify-action'),
                onPressed: selection.canBatchVerify
                    ? () => _runBatch(true)
                    : null,
                icon: const Icon(Icons.verified_outlined),
                label: Text(
                  'Verify Selected '
                  '(${_selectedStudentUuids.length})',
                ),
              ),
            if (_selectedStudentUuids.isNotEmpty && widget.canMarkPrinted)
              OutlinedButton.icon(
                key: const Key('batch-mark-printed-action'),
                onPressed: selection.canBatchMarkPrinted
                    ? () => _runBatch(false)
                    : null,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Mark Selected Printed'),
              ),
          ],
        ),
        if (widget.canVerify && selection.verifyIneligibleCount > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${selection.verifyIneligibleCount} of '
            '${selection.selectedCount} selected '
            'record(s) are already verified. '
            'Deselect them before batch Verify.',
            key: const Key('batch-verify-ineligible-message'),
            style: const TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (widget.canMarkPrinted && selection.printIneligibleCount > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${selection.printIneligibleCount} of '
            '${selection.selectedCount} selected '
            'record(s) are not verified. '
            'Deselect them before Mark Selected Printed.',
            key: const Key('batch-print-ineligible-message'),
            style: const TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMoreActions() {
    return PopupMenuButton<String>(
      key: const Key('student-more-actions'),
      tooltip: 'More actions',
      onSelected: (value) async {
        if (value == 'grid') {
          await AppNavigation.navigateToWorkflow<void>(
            context,
            AppRoutes.studentGrid,
          );

          if (mounted) {
            await _loadStudents();
          }

          return;
        }

        if (value == 'photos') {
          final imported = await AppNavigation.navigateToWorkflow<bool>(
            context,
            AppRoutes.bulkPhotoImport,
          );

          if (imported == true && mounted) {
            await _loadStudents();
          }

          return;
        }

        if (value == 'import') {
          final imported = await AppNavigation.navigateToWorkflow<bool>(
            context,
            AppRoutes.studentImport,
          );

          if (imported == true && mounted) {
            await _loadStudents();
          }
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          key: Key('student-grid-action'),
          value: 'grid',
          child: ListTile(
            leading: Icon(Icons.grid_on_outlined),
            title: Text('Excel Grid'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          key: Key('bulk-photo-import-action'),
          value: 'photos',
          child: ListTile(
            leading: Icon(Icons.add_a_photo_outlined),
            title: Text('Bulk Photos'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          key: Key('student-import-action'),
          value: 'import',
          child: ListTile(
            leading: Icon(Icons.upload_file_outlined),
            title: Text('Bulk Import'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: AppColors.textPrimary,
            ),
            SizedBox(width: 8),
            Text(
              'More actions',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    if (_loadingFilters) {
      return const Card(
        elevation: 0,
        color: AppColors.surface,
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
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.groups_2_outlined,
                  size: 28,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No students found.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Adjust the current filters or add a student to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        itemCount: students.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final student = students[index];

          return ListTile(
            leading: Checkbox(
              value: _selectedStudentUuids.contains(student.uuid),
              onChanged: widget.canVerify || widget.canMarkPrinted
                  ? (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedStudentUuids.add(student.uuid);
                        } else {
                          _selectedStudentUuids.remove(student.uuid);
                        }
                      });
                    }
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
              '${student.correctionNote?.isNotEmpty == true ? '\nCorrection note: ${student.correctionNote}' : ''}'
              '${student.verifiedAt == null ? '' : '\nVerified ${student.verifiedByName == null ? '' : 'by ${student.verifiedByName} '}at ${student.verifiedAt!.toLocal()}'}'
              '${student.printedAt == null ? '' : '\nLast printed ${student.printedByName == null ? '' : 'by ${student.printedByName} '}at ${student.printedAt!.toLocal()} • Count: ${student.printCount}'}',
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
                      } else if (value == 'verification_link') {
                        showStudentVerificationLinkDialog(
                          context: context,
                          api: widget.api,
                          schoolUuid: widget.schoolUuid,
                          studentUuid: student.uuid,
                          studentName: student.fullName,
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      if (widget.canEdit)
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (widget.canDelete)
                        const PopupMenuItem(
                          value: 'verification_link',
                          child: Text('Verification link'),
                        ),
                      if (widget.canDelete)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      if (widget.canVerify)
                        PopupMenuItem(
                          value: student.isVerified ? null : 'verify',
                          enabled: !student.isVerified,
                          child: Text(
                            student.isVerified ? 'Already Verified' : 'Verify',
                          ),
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

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          key: const Key('students-previous-page'),
          onPressed: _loading || _offset == 0
              ? null
              : () {
                  _loadStudents(offset: _offset - 100);
                },
          child: const Text('Previous'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '$_total students · '
            'Page ${_offset ~/ 100 + 1}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        TextButton(
          key: const Key('students-next-page'),
          onPressed: _loading || !_hasMore
              ? null
              : () {
                  _loadStudents(offset: _offset + 100);
                },
          child: const Text('Next'),
        ),
      ],
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
  Widget build(BuildContext context) {
    return AlertDialog(
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
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('save-correction-note'),
          onPressed: () {
            final value = _controller.text.trim();

            if (value.isEmpty) {
              setState(() {
                _error = 'Correction note is required';
              });

              return;
            }

            Navigator.pop(context, value);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
