import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/academic_session.dart';
import '../models/api_student.dart';
import '../models/school_class.dart';
import '../models/section.dart';
import '../navigation/app_navigation.dart';
import '../models/card_template.dart';
import '../models/school_profile.dart';
import '../models/design_bindings.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/authenticated_app_bar.dart';
import '../widgets/id_card_preview.dart';
import '../widgets/student_lifecycle_badge.dart';
import 'package:printing/printing.dart';

import '../services/pdf_service.dart';
import 'bulk_pdf_filter_dialog.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({
    super.key,
    required this.schoolUuid,
    required this.schoolName,
    required this.api,
    required this.canEdit,
    required this.canDesign,
    required this.canPrint,
    this.canVerify = false,
    this.canMarkPrinted = false,
  });

  final String schoolUuid;
  final String schoolName;
  final ApiService api;
  final bool canEdit;
  final bool canDesign;
  final bool canPrint;
  final bool canVerify;
  final bool canMarkPrinted;

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
  bool _exportingBulk = false;
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
  String? _schoolLogoUrl;
  SchoolProfile? _schoolProfile;
  final Map<String, String> _sectionNames = {};

  String? _selectedSessionUuid;
  String? _selectedClassUuid;
  String? _selectedSectionUuid;
  String? _verificationStatus;
  bool? _printed;
  final Set<String> _selectedStudentUuids = {};

  StudentLifecycleSelection get _selection =>
      StudentLifecycleSelection.from(_students, _selectedStudentUuids);

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
      SchoolProfile? schoolProfile;
      try {
        schoolProfile = await widget.api.getSchoolProfile(widget.schoolUuid);
      } on ApiException {
        // A missing logo must not prevent card work.
      }

      final sectionGroups =
          cardTemplate.document.elements.any(
            (e) => e.data['field'] == 'section',
          )
          ? await Future.wait(
              classes.map(
                (c) => widget.api
                    .getSections(
                      schoolUuid: widget.schoolUuid,
                      classUuid: c.uuid,
                    )
                    .catchError((_) => <SchoolSection>[]),
              ),
            )
          : <List<SchoolSection>>[];

      if (!mounted) return;

      setState(() {
        _sessions = sessions;
        _classes = classes;
        _cardTemplate = cardTemplate;
        _schoolProfile = schoolProfile;
        _schoolLogoUrl = resolveDesignAssetUrl(
          schoolProfile?.logoUrl ?? schoolProfile?.logoPath,
          widget.api.baseUrl,
        );
        _sectionNames.clear();
        for (final group in sectionGroups) {
          for (final section in group) {
            _sectionNames[section.uuid] = section.name;
          }
        }
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
        _selectedStudentUuids.clear();
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
        verificationStatus: _verificationStatus,
        printed: _printed,
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
        verificationStatus: _verificationStatus,
        printed: _printed,
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
          for (final section in sections) {
            _sectionNames[section.uuid] = section.name;
          }
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

  Future<void> _markPrinted(ApiStudent student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('cards-confirm-mark-printed-dialog'),
        title: Text(
          student.isPrinted ? 'Record card reprint?' : 'Mark card printed?',
        ),
        content: Text(
          'This records print #${student.printCount + 1} for ${student.fullName}. '
          'Printing or downloading a PDF does not update this lifecycle status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('cards-confirm-mark-printed-action'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(student.isPrinted ? 'Record Reprint' : 'Mark Printed'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.api.markStudentPrinted(
        schoolUuid: widget.schoolUuid,
        studentUuid: student.uuid,
      );
      if (mounted) await _loadStudents(reset: true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _runSelectedLifecycle({required bool verify}) async {
    if (_selectedStudentUuids.isEmpty) return;
    final selection = _selection;
    if (verify && !selection.canBatchVerify) return;
    if (!verify && !selection.canBatchMarkPrinted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: Key(
          verify
              ? 'cards-confirm-batch-verify-dialog'
              : 'cards-confirm-batch-print-dialog',
        ),
        title: Text(
          verify
              ? 'Verify ${selection.selectedCount} students?'
              : 'Mark ${selection.selectedCount} cards printed?',
        ),
        content: Text(
          verify
              ? 'All selected Pending and Needs Correction records will become Verified.'
              : '${selection.reprintCount} selected card(s) are reprints. The batch is all-or-nothing, and PDF export alone does not mark cards printed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: Key(
              verify
                  ? 'cards-confirm-batch-verify-action'
                  : 'cards-confirm-batch-print-action',
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(verify ? 'Verify All' : 'Mark All Printed'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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
      await _loadStudents(reset: true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  // ------------------------------------------------------------
  // Edit student
  // ------------------------------------------------------------

  Future<void> _editStudent(ApiStudent student) async {
    await AppNavigation.navigateToWorkflow<void>(
      context,
      AppRoutes.editStudent,
      arguments: student,
    );

    if (mounted) {
      await _loadStudents(reset: true);
    }
  }

  Future<void> _openDesigner() async {
    await AppNavigation.navigateToPage<void>(context, AppRoutes.design);
    // Designer saves through the API; route dismissal does not return a template.
    if (mounted) await _loadFilterData();
  }

  Future<void> _printStudentCard(
    ApiStudent student,
    String? sessionName,
  ) async {
    final photoUrl = _photoUrl(student);

    try {
      await Printing.layoutPdf(
        onLayout: (format) async {
          return PdfService.generateStudentCard(
            student: student,
            schoolName: widget.schoolName,
            sessionName: sessionName,
            className: _className(student),
            sectionName: _sectionName(student),
            schoolProfile: _schoolProfile,
            assetBaseUrl: widget.api.baseUrl,
            photoUrl: photoUrl,
            schoolLogoUrl: _schoolLogoUrl,
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

  String? _photoUrl(ApiStudent student) =>
      resolveDesignAssetUrl(student.photoPath, widget.api.baseUrl);

  String? _sessionName(ApiStudent student) {
    for (final session in _sessions) {
      if (session.uuid == student.sessionUuid) return session.name;
    }
    return null;
  }

  String? _className(ApiStudent student) {
    for (final item in _classes) {
      if (item.uuid == student.classUuid) return item.name;
    }
    return null;
  }

  String? _sectionName(ApiStudent student) =>
      _sectionNames[student.sectionUuid];

  Future<void> _downloadFilteredCards() async {
    if (_exportingBulk) return;
    final filter = await showDialog<BulkPdfFilter>(
      context: context,
      builder: (_) => BulkPdfFilterDialog(
        schoolUuid: widget.schoolUuid,
        api: widget.api,
        sessions: _sessions,
        classes: _classes,
        initialSearch: _search,
        initialSessionUuid: _selectedSessionUuid,
        initialClassUuid: _selectedClassUuid,
        initialSectionUuid: _selectedSectionUuid,
      ),
    );
    if (filter == null || !mounted) return;

    setState(() => _exportingBulk = true);
    try {
      const pageSize = 200;
      var offset = 0;
      final students = <ApiStudent>[];
      while (true) {
        final page = await widget.api.getStudentsPage(
          schoolUuid: widget.schoolUuid,
          limit: pageSize,
          offset: offset,
          search: filter.search,
          sessionUuid: filter.sessionUuid,
          classUuid: filter.classUuid,
          sectionUuid: filter.sectionUuid,
          createdFrom: filter.createdFrom,
          createdTo: filter.createdTo,
          verificationStatus: _verificationStatus,
          printed: _printed,
        );
        students.addAll(page.items);
        if (!page.hasMore || page.items.isEmpty) break;
        offset += page.items.length;
      }

      if (students.isEmpty) {
        throw const ApiException(
          404,
          'No students match the selected criteria.',
        );
      }

      final bytes = await PdfService.generateStudentCards(
        cards: students
            .map(
              (student) => PdfCardData(
                student: student,
                sessionName: _sessionName(student),
                className: _className(student),
                sectionName: _sectionName(student),
                photoUrl: _photoUrl(student),
              ),
            )
            .toList(),
        schoolName: widget.schoolName,
        schoolProfile: _schoolProfile,
        assetBaseUrl: widget.api.baseUrl,
        template: _cardTemplate,
        schoolLogoUrl: _schoolLogoUrl,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'id-cards-${widget.schoolName.replaceAll(' ', '-').toLowerCase()}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to download ID cards: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingBulk = false);
    }
  }

  // ------------------------------------------------------------
  // Build
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final selection = _selection;
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      appBar: AuthenticatedAppBar(
        actions: [
          if (widget.canPrint)
            IconButton(
              tooltip: 'Download filtered cards as PDF',
              onPressed: _exportingBulk ? null : _downloadFilteredCards,
              icon: _exportingBulk
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
            ),
          if (widget.canVerify && _selectedStudentUuids.isNotEmpty)
            IconButton(
              key: const Key('cards-batch-verify'),
              tooltip: 'Verify selected',
              onPressed: selection.canBatchVerify
                  ? () => _runSelectedLifecycle(verify: true)
                  : null,
              icon: const Icon(Icons.verified_outlined),
            ),
          if (widget.canMarkPrinted && _selectedStudentUuids.isNotEmpty)
            IconButton(
              key: const Key('cards-batch-mark-printed'),
              tooltip: 'Mark selected printed',
              onPressed: selection.canBatchMarkPrinted
                  ? () => _runSelectedLifecycle(verify: false)
                  : null,
              icon: const Icon(Icons.done_all),
            ),
          if (widget.canDesign)
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

                    const SizedBox(height: 10),

                    const Card(
                      key: Key('pdf-lifecycle-explanation'),
                      elevation: 0,
                      color: Color(0xffeef5ff),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'PDF export is non-destructive and does not mark cards printed. '
                          'Use Mark Printed only after physical production.',
                        ),
                      ),
                    ),

                    if (widget.canVerify && selection.verifyIneligibleCount > 0)
                      Text(
                        '${selection.verifyIneligibleCount} of ${selection.selectedCount} selected '
                        'record(s) are already verified. Deselect them before batch Verify.',
                        key: const Key('cards-batch-verify-ineligible-message'),
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    if (widget.canMarkPrinted &&
                        selection.printIneligibleCount > 0)
                      Text(
                        '${selection.printIneligibleCount} of ${selection.selectedCount} selected '
                        'record(s) are not verified. Deselect them before Mark Selected Printed.',
                        key: const Key('cards-batch-print-ineligible-message'),
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

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
          _dropdown<String>(
            label: 'Verification',
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
            onChanged: (value) {
              setState(() => _verificationStatus = value);
              _loadStudents(reset: true);
            },
          ),
          _dropdown<bool>(
            label: 'Printed',
            value: _printed,
            items: const [
              DropdownMenuItem(value: null, child: Text('All Records')),
              DropdownMenuItem(value: false, child: Text('Not Printed')),
              DropdownMenuItem(value: true, child: Text('Printed')),
            ],
            onChanged: (value) {
              setState(() => _printed = value);
              _loadStudents(reset: true);
            },
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(flex: 2, child: search),
                const SizedBox(width: 10),
                Expanded(child: filters[0]),
                const SizedBox(width: 10),
                Expanded(child: filters[1]),
                const SizedBox(width: 10),
                Expanded(child: filters[2]),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: filters.skip(3).toList(),
            ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final columns = math.max(
          1,
          (constraints.maxWidth / (250 + spacing)).ceil(),
        );
        final tileWidth =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        final canvas = _cardTemplate.document.canvas;
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent:
                tileWidth * canvas.height / canvas.width +
                IdCardPreview.actionsHeight,
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

            return Stack(
              children: [
                Positioned.fill(
                  child: IdCardPreview(
                    student: student,
                    schoolName: widget.schoolName,
                    api: widget.api,
                    template: _cardTemplate,
                    sessionName: session?.name,
                    className: _className(student),
                    sectionName: _sectionName(student),
                    logoUrl: _schoolLogoUrl,
                    schoolProfile: _schoolProfile,
                    onEdit: widget.canEdit ? () => _editStudent(student) : null,
                    onPrint: widget.canPrint
                        ? () => _printStudentCard(student, session?.name)
                        : null,
                    onMarkPrinted: widget.canMarkPrinted && student.isVerified
                        ? () => _markPrinted(student)
                        : null,
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Checkbox(
                    value: _selectedStudentUuids.contains(student.uuid),
                    onChanged: widget.canVerify || widget.canMarkPrinted
                        ? (value) => setState(() {
                            if (value == true) {
                              _selectedStudentUuids.add(student.uuid);
                            } else {
                              _selectedStudentUuids.remove(student.uuid);
                            }
                          })
                        : null,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: StudentLifecycleBadge(status: student.lifecycleStatus),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
