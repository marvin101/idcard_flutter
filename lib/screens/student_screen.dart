import 'package:flutter/material.dart';

import '../models/api_student.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'student_form.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({
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
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  bool _loading = true;
  String? _error;
  List<ApiStudent> _students = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final students = await widget.api.getStudents(
        schoolUuid: widget.schoolUuid,
      );

      if (!mounted) return;

      setState(() {
        _students = students;
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

  @override
  Widget build(BuildContext context) {
    final students = _filteredStudents;

    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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
    return Row(
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
        if (widget.canManage) ...[
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudentFormScreen(
                    schoolUuid: widget.schoolUuid,
                    api: widget.api,
                  ),
                ),
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
            leading: CircleAvatar(
              child: Text(
                student.fullName.isEmpty
                    ? '?'
                    : student.fullName[0].toUpperCase(),
              ),
            ),
            title: Text(
              student.fullName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'Admission: ${student.admissionNo}'
              '${student.rollNo == null ? '' : '  •  Roll: ${student.rollNo}'}',
            ),
            trailing: widget.canManage
                ? PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editStudent(student);
                      } else if (value == 'delete') {
                        _deleteStudent(student);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
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
