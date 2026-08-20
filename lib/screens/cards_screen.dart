import 'package:flutter/material.dart';

import '../models/academic_session.dart';
import '../models/api_student.dart';
import '../models/school_class.dart';
import '../models/section.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'student_form.dart';
import '../widgets/id_card_preview.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({
    super.key,
    required this.schoolUuid,
    required this.schoolName,
    required this.api,
    required this.canManage,
  });

  final String schoolUuid;
  final String schoolName;
  final ApiService api;
  final bool canManage;

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  static const int _batchSize = 800;

  bool _loadingFilters = true;
  bool _loadingStudents = false;

  String? _error;
  String? _sectionError;

  String _search = '';

  List<AcademicSession> _sessions = const [];
  List<SchoolClass> _classes = const [];
  List<SchoolSection> _sections = const [];
  List<ApiStudent> _students = const [];

  String? _selectedSessionUuid;
  String? _selectedClassUuid;
  String? _selectedSectionUuid;

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
      _loadingStudents = true;
      _error = null;
    });

    try {
      final students = await widget.api.getStudents(
        schoolUuid: widget.schoolUuid,
        sessionUuid: _selectedSessionUuid,
        classUuid: _selectedClassUuid,
        sectionUuid: _selectedSectionUuid,
      );

      if (!mounted) return;

      setState(() {
        _students = students;
        _loadingStudents = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingStudents = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingStudents = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _selectSession(String? value) async {
    setState(() {
      _selectedSessionUuid = value;
      _selectedClassUuid = null;
      _selectedSectionUuid = null;
      _sections = const [];
      _sectionError = null;
    });

    await _loadStudents();
  }

  Future<void> _selectClass(String? value) async {
    setState(() {
      _selectedClassUuid = value;
      _selectedSectionUuid = null;
      _sections = const [];
      _sectionError = null;
    });

    if (value != null) {
      try {
        final sections = await widget.api.getSections(
          schoolUuid: widget.schoolUuid,
          classUuid: value,
        );

        if (!mounted) return;

        setState(() {
          _sections = sections;
        });
      } on ApiException catch (e) {
        if (!mounted) return;

        setState(() {
          _sectionError = e.message;
        });
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _sectionError = e.toString();
        });
      }
    }

    await _loadStudents();
  }

  Future<void> _selectSection(String? value) async {
    setState(() {
      _selectedSectionUuid = value;
    });

    await _loadStudents();
  }

  Future<void> _editStudent(ApiStudent student) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentFormScreen(
          schoolUuid: widget.schoolUuid,
          api: widget.api,
          student: student,
        ),
      ),
    );

    if (mounted) {
      await _loadStudents();
    }
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

  List<ApiStudent> get _visibleStudents =>
      _filteredStudents.take(_batchSize).toList(growable: false);

  int get _batchCount => (_filteredStudents.length / _batchSize).ceil();

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredStudents;
    final visible = _visibleStudents;

    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('ID Cards — ${widget.schoolName}'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Padding(
                padding: EdgeInsets.all(constraints.maxWidth > 700 ? 24 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildToolbar(),
                    const SizedBox(height: 14),
                    Text(
                      'Showing ${visible.length} of ${filtered.length} students',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (filtered.length > _batchSize) ...[
                      const SizedBox(height: 10),
                      _buildBatchWarning(filtered.length),
                    ],
                    const SizedBox(height: 14),
                    Expanded(child: _buildContent(visible)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolbar() {
    if (_loadingFilters) {
      return const Card(
        elevation: 0,
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
              Text('Loading card filters...'),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;

        final search = TextField(
          decoration: InputDecoration(
            hintText: 'Search student, admission no. or roll no.',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xffdfe4ec)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xffdfe4ec)),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _search = value;
            });
          },
        );

        final filters = [
          _dropdown<String>(
            label: 'Academic Session',
            value: _selectedSessionUuid,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Sessions')),
              ..._sessions.map(
                (session) => DropdownMenuItem(
                  value: session.uuid,
                  child: Text(session.name),
                ),
              ),
            ],
            onChanged: _selectSession,
          ),
          _dropdown<String>(
            label: 'Class',
            value: _selectedClassUuid,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Classes')),
              ..._classes.map(
                (schoolClass) => DropdownMenuItem(
                  value: schoolClass.uuid,
                  child: Text(schoolClass.name),
                ),
              ),
            ],
            onChanged: _selectClass,
          ),
          _dropdown<String>(
            label: 'Section',
            value: _selectedSectionUuid,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Sections')),
              ..._sections.map(
                (section) => DropdownMenuItem(
                  value: section.uuid,
                  child: Text(section.name),
                ),
              ),
            ],
            onChanged: _selectSection,
            enabled: _selectedClassUuid != null && _sections.isNotEmpty,
          ),
        ];

        final filterRow = Wrap(spacing: 10, runSpacing: 10, children: filters);

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 10),
              filterRow,
              if (_sectionError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _sectionError!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 2, child: search),
            const SizedBox(width: 10),
            Expanded(child: filters[0]),
            const SizedBox(width: 10),
            Expanded(child: filters[1]),
            const SizedBox(width: 10),
            Expanded(child: filters[2]),
          ],
        );
      },
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
  }) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: enabled ? Colors.white : const Color(0xfff1f3f6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: items,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  Widget _buildBatchWarning(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xfffffbeb),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xfff1d27a)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xffb77900)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count students is more than the $_batchSize-card '
              'download limit, so they\'re split into $_batchCount '
              'batches. Use the batch controls when PDF downloading '
              'is added.',
              style: const TextStyle(
                color: Color(0xff9a5f00),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<ApiStudent> students) {
    if (_loadingStudents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadStudents,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (students.isEmpty) {
      return const Center(
        child: Text(
          'No students found for the selected filters.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        mainAxisExtent: 300,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];

        AcademicSession? session;

        for (final item in _sessions) {
          if (item.uuid == student.sessionUuid) {
            session = item;
            break;
          }
        }

        return IdCardPreview(
          student: student,
          schoolName: widget.schoolName,
          api: widget.api,
          sessionName: session?.name,
          onEdit: widget.canManage ? () => _editStudent(student) : null,
        );
      },
    );
  }
}
