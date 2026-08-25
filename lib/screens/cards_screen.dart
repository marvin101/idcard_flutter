import 'dart:async';

import 'package:flutter/material.dart';

import '../models/academic_session.dart';
import '../models/api_student.dart';
import '../models/school_class.dart';
import '../models/section.dart';
import '../models/card_template.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'student_form.dart';
import '../widgets/id_card_preview.dart';
import 'package:printing/printing.dart';

import '../services/pdf_service.dart';
import 'card_designer_screen.dart';

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
  // Backend allows a maximum of 200.
  // 100 is a good balance between network requests and memory usage.
  static const int _pageSize = 10;

  // Start loading the next page before the user reaches the bottom.
  static const double _loadMoreThreshold = 600;

  bool _loadingFilters = true;
  bool _loadingStudents = false;
  bool _loadingMore = false;
  bool _hasMore = true;

  String? _error;
  String? _sectionError;

  String _search = '';

  int _offset = 0;
  int _totalStudents = 0;

  // Used to invalidate older requests when filters/search change.
  int _requestVersion = 0;

  Timer? _searchDebounce;
  late final ScrollController _scrollController;

  List<AcademicSession> _sessions = const [];
  List<SchoolClass> _classes = const [];
  List<SchoolSection> _sections = const [];
  List<ApiStudent> _students = [];
  CardTemplate _cardTemplate = CardTemplate.uploadedDesign;

  String? _selectedSessionUuid;
  String? _selectedClassUuid;
  String? _selectedSectionUuid;

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _loadFilterData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Infinite scrolling
  // ------------------------------------------------------------

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;

    if (position.maxScrollExtent - position.pixels <= _loadMoreThreshold) {
      _loadMoreStudents();
    }
  }

  // ------------------------------------------------------------
  // Initial filter loading
  // ------------------------------------------------------------

  Future<void> _loadFilterData() async {
    if (mounted) {
      setState(() {
        _loadingFilters = true;
        _error = null;
      });
    }

    try {
      final sessions = await widget.api.getAcademicSessions(widget.schoolUuid);

      final classes = await widget.api.getClasses(widget.schoolUuid);

      CardTemplate cardTemplate = CardTemplate.uploadedDesign;
      try {
        cardTemplate = await widget.api.getCardTemplate(widget.schoolUuid);
      } on ApiException catch (e) {
        if (e.statusCode != 404) rethrow;
      }

      if (!mounted) return;

      setState(() {
        _sessions = sessions;
        _classes = classes;
        _cardTemplate = cardTemplate;
        _loadingFilters = false;
      });

      await _loadStudents(reset: true);
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

  // ------------------------------------------------------------
  // Load first page / reload after filter changes
  // ------------------------------------------------------------

  Future<void> _loadStudents({bool reset = true}) async {
    if (!reset) {
      await _loadMoreStudents();
      return;
    }

    final requestVersion = ++_requestVersion;

    if (mounted) {
      setState(() {
        _loadingStudents = true;
        _loadingMore = false;
        _error = null;
        _students = [];
        _offset = 0;
        _totalStudents = 0;
        _hasMore = true;
      });
    }

    try {
      final page = await widget.api.getStudentsPage(
        schoolUuid: widget.schoolUuid,
        limit: _pageSize,
        offset: 0,
        search: _search,
        sessionUuid: _selectedSessionUuid,
        classUuid: _selectedClassUuid,
        sectionUuid: _selectedSectionUuid,
      );

      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _students = List<ApiStudent>.from(page.items);
        _offset = page.items.length;
        _totalStudents = page.total;
        _hasMore = page.hasMore;
        _loadingStudents = false;
      });

      _loadMoreIfViewportIsNotFilled();
    } on ApiException catch (e) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _loadingStudents = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _loadingStudents = false;
        _error = e.toString();
      });
    }
  }

  // ------------------------------------------------------------
  // Load next page
  // ------------------------------------------------------------

  Future<void> _loadMoreStudents() async {
    if (_loadingStudents || _loadingMore || !_hasMore) {
      return;
    }

    final requestVersion = _requestVersion;
    final requestOffset = _offset;

    if (mounted) {
      setState(() {
        _loadingMore = true;
      });
    }

    try {
      final page = await widget.api.getStudentsPage(
        schoolUuid: widget.schoolUuid,
        limit: _pageSize,
        offset: requestOffset,
        search: _search,
        sessionUuid: _selectedSessionUuid,
        classUuid: _selectedClassUuid,
        sectionUuid: _selectedSectionUuid,
      );

      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _students.addAll(page.items);

        _offset = requestOffset + page.items.length;
        _totalStudents = page.total;
        _hasMore = page.hasMore;

        _loadingMore = false;
      });

      // Handles cases where the first page does not fill
      // the available viewport.
      _loadMoreIfViewportIsNotFilled();
    } on ApiException catch (e) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _loadingMore = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted || requestVersion != _requestVersion) {
        return;
      }

      setState(() {
        _loadingMore = false;
        _error = e.toString();
      });
    }
  }

  // ------------------------------------------------------------
  // If there are few cards, automatically continue loading
  // until the viewport can actually scroll.
  // ------------------------------------------------------------

  void _loadMoreIfViewportIsNotFilled() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_scrollController.hasClients ||
          _loadingStudents ||
          _loadingMore ||
          !_hasMore) {
        return;
      }

      final position = _scrollController.position;

      if (position.maxScrollExtent <= 0) {
        _loadMoreStudents();
      }
    });
  }

  // ------------------------------------------------------------
  // Search
  // ------------------------------------------------------------

  void _onSearchChanged(String value) {
    _search = value;

    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _loadStudents(reset: true);
    });
  }

  // ------------------------------------------------------------
  // Filters
  // ------------------------------------------------------------

  Future<void> _selectSession(String? value) async {
    setState(() {
      _selectedSessionUuid = value;
      _selectedClassUuid = null;
      _selectedSectionUuid = null;
      _sections = const [];
      _sectionError = null;
    });

    await _loadStudents(reset: true);
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

    await _loadStudents(reset: true);
  }

  Future<void> _selectSection(String? value) async {
    setState(() {
      _selectedSectionUuid = value;
    });

    await _loadStudents(reset: true);
  }

  // ------------------------------------------------------------
  // Edit student
  // ------------------------------------------------------------

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
      await _loadStudents(reset: true);
    }
  }

  Future<void> _openDesigner() async {
    final saved = await Navigator.of(context).push<CardTemplate>(
      MaterialPageRoute(
        builder: (_) => CardDesignerScreen(
          schoolUuid: widget.schoolUuid,
          api: widget.api,
          initialTemplate: _cardTemplate,
        ),
      ),
    );
    if (saved != null && mounted) setState(() => _cardTemplate = saved);
  }

  Future<void> _printStudentCard(
    ApiStudent student,
    String? sessionName,
  ) async {
    String? photoUrl;

    final path = student.photoPath?.trim();

    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        photoUrl = path;
      } else {
        photoUrl = path.startsWith('/')
            ? '${widget.api.baseUrl}$path'
            : '${widget.api.baseUrl}/$path';
      }
    }

    try {
      await Printing.layoutPdf(
        onLayout: (format) async {
          return PdfService.generateStudentCard(
            student: student,
            schoolName: widget.schoolName,
            sessionName: sessionName,
            photoUrl: photoUrl,
            template: _cardTemplate,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to generate ID card: $e')));
    }
  }

  // ------------------------------------------------------------
  // Build
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (widget.canManage)
            IconButton(
              tooltip: 'Design card',
              icon: const Icon(Icons.design_services_outlined),
              onPressed: _openDesigner,
            ),
        ],
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
                      _totalStudents == 0
                          ? 'Showing 0 students'
                          : 'Showing ${_students.length} of $_totalStudents students',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Expanded(child: _buildContent()),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // Toolbar
  // ------------------------------------------------------------

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
          onChanged: _onSearchChanged,
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

  // ------------------------------------------------------------
  // Dropdown
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // Content
  // ------------------------------------------------------------

  Widget _buildContent() {
    if (_loadingStudents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _students.isEmpty) {
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
              onPressed: () => _loadStudents(reset: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_students.isEmpty) {
      return const Center(
        child: Text(
          'No students found for the selected filters.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        childAspectRatio: 1.22,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _students.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Loading indicator at the bottom of the grid.
        if (index >= _students.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final student = _students[index];

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
          template: _cardTemplate,
          sessionName: session?.name,
          onEdit: widget.canManage ? () => _editStudent(student) : null,
          onPrint: () => _printStudentCard(student, session?.name),
        );
      },
    );
  }
}
