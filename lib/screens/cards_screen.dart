import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/academic_session.dart';
import '../models/api_student.dart';
import '../models/bulk_card_export.dart';
import '../models/school_class.dart';
import '../models/section.dart';
import '../navigation/app_navigation.dart';
import '../models/card_template.dart';
import '../models/school_profile.dart';
import '../models/design_bindings.dart';
import '../models/print_sheet.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/authenticated_app_bar.dart';
import '../widgets/id_card_preview.dart';
import '../widgets/student_lifecycle_badge.dart';
import 'package:printing/printing.dart';

import '../services/pdf_service.dart';
import '../services/print_preset_store.dart';
import '../services/print_basket_store.dart';
import 'bulk_pdf_filter_dialog.dart';

typedef BulkPdfAction =
    Future<void> Function({
      required List<PdfCardData> cards,
      required String schoolName,
      required CardTemplate template,
      required String? schoolLogoUrl,
      required SchoolProfile? schoolProfile,
      required String? assetBaseUrl,
      required PrintSheetSettings printSettings,
      required void Function(int completed, int total) onCardPrepared,
    });

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
    this.bulkPdfAction,
  });

  final String schoolUuid;
  final String schoolName;
  final ApiService api;
  final bool canEdit;
  final bool canDesign;
  final bool canPrint;
  final bool canVerify;
  final bool canMarkPrinted;
  final BulkPdfAction? bulkPdfAction;

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final _printBasketStore = PrintBasketStore();
  // Backend allows a maximum of 200.
  // 100 is a good balance between network requests and memory usage.
  static const int _pageSize = 10;

  // Start loading the next page before the user reaches the bottom.
  static const double _loadMoreThreshold = 600;

  bool _loadingFilters = true;
  bool _loadingStudents = false;
  bool _loadingMore = false;
  bool _exportingBulk = false;
  String? _bulkExportStatus;
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
  final Map<String, ApiStudent> _printBasketStudents = {};

  StudentLifecycleSelection get _selection =>
      StudentLifecycleSelection.from(_students, _selectedStudentUuids);

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _loadFilterData();
    unawaited(_restorePrintBasket());
  }

  @override
  void didUpdateWidget(CardsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolUuid != widget.schoolUuid) {
      _selectedStudentUuids.clear();
      _printBasketStudents.clear();
      unawaited(_restorePrintBasket());
    }
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

      final templateElements = [
        ...cardTemplate.document.elements,
        ...?cardTemplate.backDocument?.elements,
      ];
      final sectionGroups =
          templateElements.any(
            (element) =>
                {'section', 'class_section'}.contains(element.data['field']),
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
    final printSettings = _cardTemplate.hasBackDesign
        ? await _chooseIndividualPrintSides()
        : const PrintSheetSettings();
    if (printSettings == null || !mounted) return;

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
            printSettings: printSettings,
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

  Future<PrintSheetSettings?> _chooseIndividualPrintSides() async {
    final presets = await const PrintPresetStore().load(widget.schoolUuid);
    if (!mounted) return null;
    var sides = PrintSides.frontOnly;
    var flipEdge = DuplexFlipEdge.longEdge;
    String? selectedPresetId;
    return showDialog<PrintSheetSettings>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          key: const Key('individual-print-sides-dialog'),
          title: const Text('Print card'),
          content: SizedBox(
            width: 420,
            child: Column(
              key: ValueKey(
                'individual-print-$selectedPresetId-${sides.name}-${flipEdge.name}',
              ),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (presets.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    key: const Key('individual-print-preset'),
                    isExpanded: true,
                    initialValue: selectedPresetId,
                    decoration: const InputDecoration(
                      labelText: 'Print preset',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Custom settings'),
                    items: presets
                        .map(
                          (preset) => DropdownMenuItem(
                            value: preset.id,
                            child: Text(preset.name),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      if (id == null) return;
                      final settings = presets
                          .firstWhere((preset) => preset.id == id)
                          .settings;
                      setDialogState(() {
                        selectedPresetId = id;
                        sides = settings.sides;
                        flipEdge = settings.flipEdge;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'For individual cards, the preset applies side and flip-edge preferences. Sheet calibration remains available in bulk export.',
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<PrintSides>(
                  key: const Key('individual-print-sides'),
                  isExpanded: true,
                  initialValue: sides,
                  decoration: const InputDecoration(
                    labelText: 'Card sides',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: PrintSides.frontOnly,
                      child: Text('Front only'),
                    ),
                    DropdownMenuItem(
                      value: PrintSides.duplex,
                      child: Text('Front and back (duplex)'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => sides = value!),
                ),
                if (sides == PrintSides.duplex) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<DuplexFlipEdge>(
                    key: const Key('individual-print-flip-edge'),
                    isExpanded: true,
                    initialValue: flipEdge,
                    decoration: const InputDecoration(
                      labelText: 'Printer flip edge',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: DuplexFlipEdge.longEdge,
                        child: Text('Flip on long edge'),
                      ),
                      DropdownMenuItem(
                        value: DuplexFlipEdge.shortEdge,
                        child: Text('Flip on short edge'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => flipEdge = value!),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'The PDF contains alternating front and back pages. Select the same flip edge in the printer dialog.',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('individual-print-continue'),
              onPressed: () => Navigator.pop(
                context,
                PrintSheetSettings(sides: sides, flipEdge: flipEdge),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
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
        selectedStudentCount: _selectedStudentUuids.length,
        printBasketCount: _printBasketStudents.length,
        cardWidthMm: _cardTemplate.document.canvas.width,
        cardHeightMm: _cardTemplate.document.canvas.height,
        hasBackDesign: _cardTemplate.hasBackDesign,
        verificationStatus: _verificationStatus,
        printed: _printed,
      ),
    );
    if (filter == null || !mounted) return;
    await _runBulkExport(filter);
  }

  Future<void> _runBulkExport(BulkPdfFilter filter) async {
    setState(() {
      _exportingBulk = true;
      _bulkExportStatus = 'Preparing cardsâ€¦';
    });
    try {
      final loaded = switch (filter.scope) {
        BulkCardExportScope.selectedStudents => await _loadSelectedStudents(),
        BulkCardExportScope.printBasket => await _loadPrintBasketStudents(),
        BulkCardExportScope.matchingFilters => await _loadBulkStudents(filter),
      };
      final students = loaded.students;

      if (students.isEmpty) {
        throw const ApiException(
          404,
          'No students match the selected criteria.',
        );
      }

      final inspection = BulkExportInspection.inspect(
        students: students,
        template: _cardTemplate,
        schoolName: widget.schoolName,
        schoolProfile: _schoolProfile,
        sessionName: _sessionName,
        className: _className,
        sectionName: _sectionName,
        photoUrl: _photoUrl,
        includeBack: filter.printSettings.isDuplex,
      );
      final confirmed = await _confirmBulkExport(
        filter: filter,
        students: students,
        inspection: inspection,
        expectedTotal: loaded.expectedTotal,
      );
      if (confirmed != true || !mounted) return;

      setState(
        () => _bulkExportStatus = 'Generating PDFâ€¦ 0/${students.length}',
      );

      final cards = students
          .map(
            (student) => PdfCardData(
              student: student,
              sessionName: _sessionName(student),
              className: _className(student),
              sectionName: _sectionName(student),
              photoUrl: _photoUrl(student),
            ),
          )
          .toList();
      void onCardPrepared(int completed, int total) {
        if (mounted) {
          setState(
            () => _bulkExportStatus = 'Generating PDFâ€¦ $completed/$total',
          );
        }
      }

      if (widget.bulkPdfAction case final action?) {
        await action(
          cards: cards,
          schoolName: widget.schoolName,
          template: _cardTemplate,
          schoolLogoUrl: _schoolLogoUrl,
          schoolProfile: _schoolProfile,
          assetBaseUrl: widget.api.baseUrl,
          printSettings: filter.printSettings,
          onCardPrepared: onCardPrepared,
        );
      } else {
        final bytes = await PdfService.generateStudentCards(
          cards: cards,
          schoolName: widget.schoolName,
          schoolProfile: _schoolProfile,
          assetBaseUrl: widget.api.baseUrl,
          template: _cardTemplate,
          schoolLogoUrl: _schoolLogoUrl,
          printSettings: filter.printSettings,
          onCardPrepared: onCardPrepared,
        );
        if (mounted) setState(() => _bulkExportStatus = 'Opening downloadâ€¦');
        await Printing.sharePdf(
          bytes: bytes,
          filename:
              'id-cards-${widget.schoolName.replaceAll(' ', '-').toLowerCase()}.pdf',
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to download ID cards: ${e.message}')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to download ID cards. Your filters and selection were kept; please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _exportingBulk = false;
          _bulkExportStatus = null;
        });
      }
    }
  }

  Future<_LoadedBulkStudents> _loadBulkStudents(BulkPdfFilter filter) async {
    const pageSize = 200;
    var offset = 0;
    int? expectedTotal;
    final studentsByUuid = <String, ApiStudent>{};
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
      expectedTotal ??= page.total;
      for (final student in page.items) {
        studentsByUuid.putIfAbsent(student.uuid, () => student);
      }
      if (!page.hasMore || page.items.isEmpty) break;
      offset += page.items.length;
    }
    return _LoadedBulkStudents(
      students: studentsByUuid.values.toList(),
      expectedTotal: expectedTotal,
    );
  }

  Future<_LoadedBulkStudents> _loadSelectedStudents() async {
    final selected = _students
        .where((student) => _selectedStudentUuids.contains(student.uuid))
        .toList();
    final refreshed = <ApiStudent>[];
    const requestBatchSize = 20;
    for (var start = 0; start < selected.length; start += requestBatchSize) {
      final end = math.min(start + requestBatchSize, selected.length);
      final batch = await Future.wait(
        selected
            .sublist(start, end)
            .map((student) => _refreshSelectedStudent(student.uuid)),
      );
      refreshed.addAll(batch.whereType<ApiStudent>());
    }
    return _LoadedBulkStudents(
      students: refreshed,
      expectedTotal: selected.length,
    );
  }

  Future<_LoadedBulkStudents> _loadPrintBasketStudents() async {
    final uuids = _printBasketStudents.keys.toList();
    final refreshed = <ApiStudent>[];
    const requestBatchSize = 20;
    for (var start = 0; start < uuids.length; start += requestBatchSize) {
      final end = math.min(start + requestBatchSize, uuids.length);
      final batch = await Future.wait(
        uuids.sublist(start, end).map(_refreshSelectedStudent),
      );
      refreshed.addAll(batch.whereType<ApiStudent>());
    }
    final refreshedByUuid = {
      for (final student in refreshed) student.uuid: student,
    };
    if (mounted) {
      setState(() {
        _printBasketStudents
          ..clear()
          ..addAll(refreshedByUuid);
      });
    }
    await _persistPrintBasket();
    return _LoadedBulkStudents(
      students: refreshed,
      expectedTotal: uuids.length,
    );
  }

  Future<void> _addSelectionToPrintBasket() async {
    if (_selectedStudentUuids.isEmpty) return;
    setState(() {
      for (final student in _students) {
        if (_selectedStudentUuids.contains(student.uuid)) {
          _printBasketStudents[student.uuid] = student;
        }
      }
      _selectedStudentUuids.clear();
    });
    await _persistPrintBasket();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Print Basket now contains ${_printBasketStudents.length} card(s).',
        ),
      ),
    );
  }

  Future<void> _showPrintBasket() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final students = _printBasketStudents.values.toList();
          return AlertDialog(
            key: const Key('print-basket-dialog'),
            title: Text('Print Basket (${students.length})'),
            content: SizedBox(
              width: 520,
              child: students.isEmpty
                  ? const Text(
                      'The basket is empty. Select cards and use Add to Print Basket.',
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: students.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return ListTile(
                          title: Text(student.fullName),
                          subtitle: Text(
                            'Admission ${student.admissionNo} • Roll ${student.rollNo}',
                          ),
                          trailing: IconButton(
                            key: Key(
                              'remove-from-print-basket-${student.uuid}',
                            ),
                            tooltip: 'Remove from Print Basket',
                            onPressed: () {
                              setState(
                                () => _printBasketStudents.remove(student.uuid),
                              );
                              unawaited(_persistPrintBasket());
                              setDialogState(() {});
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                key: const Key('clear-print-basket'),
                onPressed: students.isEmpty
                    ? null
                    : () {
                        setState(_printBasketStudents.clear);
                        unawaited(_persistPrintBasket());
                        setDialogState(() {});
                      },
                child: const Text('Clear'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                key: const Key('export-print-basket'),
                onPressed: students.isEmpty || _exportingBulk
                    ? null
                    : () {
                        Navigator.pop(dialogContext);
                        _downloadFilteredCards();
                      },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Configure PDF'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<ApiStudent?> _refreshSelectedStudent(String studentUuid) async {
    try {
      return await widget.api.getStudent(
        schoolUuid: widget.schoolUuid,
        studentUuid: studentUuid,
      );
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      // A student removed after selection is omitted and disclosed by the
      // expected-versus-found count in the confirmation dialog.
      return null;
    }
  }

  Future<void> _restorePrintBasket() async {
    final schoolUuid = widget.schoolUuid;
    final uuids = await _printBasketStore.load(
      schoolUuid: schoolUuid,
      identityType: 'student',
    );
    if (uuids.isEmpty) return;

    final restored = <String, ApiStudent>{};
    const requestBatchSize = 20;
    for (var start = 0; start < uuids.length; start += requestBatchSize) {
      final end = math.min(start + requestBatchSize, uuids.length);
      late final List<ApiStudent?> batch;
      try {
        batch = await Future.wait(
          uuids.sublist(start, end).map((uuid) async {
            try {
              return await widget.api.getStudent(
                schoolUuid: schoolUuid,
                studentUuid: uuid,
              );
            } on ApiException catch (error) {
              if (error.statusCode != 404) rethrow;
              return null;
            }
          }),
        );
      } catch (_) {
        // Keep the saved UUIDs when a transient refresh fails. The basket can
        // be restored on the next visit without persisting stale snapshots.
        return;
      }
      for (final student in batch.whereType<ApiStudent>()) {
        restored[student.uuid] = student;
      }
    }
    if (!mounted || widget.schoolUuid != schoolUuid) return;
    setState(() {
      _printBasketStudents
        ..clear()
        ..addAll(restored);
    });
    await _persistPrintBasket();
  }

  Future<void> _persistPrintBasket() => _printBasketStore.save(
    schoolUuid: widget.schoolUuid,
    identityType: 'student',
    recordUuids: _printBasketStudents.keys,
  );

  Future<bool?> _confirmBulkExport({
    required BulkPdfFilter filter,
    required List<ApiStudent> students,
    required BulkExportInspection inspection,
    required int expectedTotal,
  }) => showDialog<bool>(
    context: context,
    builder: (context) {
      final canvas = _cardTemplate.document.canvas;
      final scope = switch (filter.scope) {
        BulkCardExportScope.selectedStudents => 'Selected students only',
        BulkCardExportScope.printBasket => 'Print Basket',
        BulkCardExportScope.matchingFilters => 'All students matching filters',
      };
      final plan = PrintSheetPlan.calculate(
        settings: filter.printSettings,
        cardWidthMm: canvas.width,
        cardHeightMm: canvas.height,
        cardCount: students.length,
      );
      return AlertDialog(
        key: const Key('bulk-export-confirmation'),
        title: const Text('Review PDF export'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Scope: $scope', key: const Key('bulk-scope-summary')),
                Text('Session: ${_sessionLabel(filter.sessionUuid)}'),
                Text('Class: ${_classLabel(filter.classUuid)}'),
                Text('Section: ${_sectionLabel(filter.sectionUuid)}'),
                if (_verificationStatus != null)
                  Text(
                    'Verification: ${_verificationStatus!.replaceAll('_', ' ')}',
                  ),
                if (_printed != null)
                  Text(
                    'Print status: ${_printed! ? 'Printed' : 'Not printed'}',
                  ),
                Text(
                  'Students/cards: ${students.length}',
                  key: const Key('bulk-student-count'),
                ),
                Text(
                  filter.printSettings.isDuplex
                      ? 'PDF pages: ${plan.pdfPageCount} • Physical sheets: '
                            '${plan.physicalSheetCount}'
                            '${filter.printSettings.mode == PrintLayoutMode.oneCardPerPage ? ' (one card per sheet)' : ' • ${plan.columns} × ${plan.rows} = ${plan.cardsPerPage} cards per sheet'}'
                      : filter.printSettings.mode ==
                            PrintLayoutMode.oneCardPerPage
                      ? 'Pages: ${plan.pageCount} (one card per page)'
                      : 'Sheets: ${plan.pageCount} • ${plan.columns} × ${plan.rows} '
                            '= ${plan.cardsPerPage} cards per sheet',
                  key: const Key('bulk-page-count'),
                ),
                Text(
                  filter.printSettings.isDuplex
                      ? 'Sides: Front and back • ${filter.printSettings.flipEdge == DuplexFlipEdge.longEdge ? 'flip on long edge' : 'flip on short edge'}'
                      : 'Sides: Front only',
                  key: const Key('bulk-side-settings'),
                ),
                if (filter.printSettings.isDuplex)
                  const Text(
                    'Print double-sided using the same flip-edge setting. Front and back pages alternate in the PDF.',
                  ),
                if (filter.printSettings.mode == PrintLayoutMode.sheet)
                  Text(
                    'Paper: ${filter.printSettings.paperLabel} '
                    '${filter.printSettings.orientationLabel} • '
                    '${filter.printSettings.marginMm.toStringAsFixed(1)} mm margins • '
                    '${filter.printSettings.gapMm.toStringAsFixed(1)} mm spacing • '
                    '${filter.printSettings.cropMarks ? 'crop marks' : 'no crop marks'}',
                    key: const Key('bulk-sheet-settings'),
                  ),
                if (filter.printSettings.mode == PrintLayoutMode.sheet)
                  Text(
                    'Calibration: front X '
                    '${filter.printSettings.frontOffsetXmm.toStringAsFixed(1)} mm, '
                    'Y ${filter.printSettings.frontOffsetYmm.toStringAsFixed(1)} mm'
                    '${filter.printSettings.isDuplex ? ' • back X ${filter.printSettings.backOffsetXmm.toStringAsFixed(1)} mm, Y ${filter.printSettings.backOffsetYmm.toStringAsFixed(1)} mm' : ''}',
                    key: const Key('bulk-calibration-settings'),
                  ),
                Text('Template: ${_cardTemplate.name}'),
                Text(
                  'Card: ${canvas.orientation}, '
                  '${canvas.width.toStringAsFixed(2)} × '
                  '${canvas.height.toStringAsFixed(2)} mm',
                ),
                if (students.length != expectedTotal) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Student data changed while this export was prepared. '
                    'Expected $expectedTotal but found ${students.length}; only the cards listed above will be exported.',
                    key: const Key('bulk-stale-count-warning'),
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ],
                if (inspection.warnings.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Warnings',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...inspection.warnings.map(
                    (issue) => Text(
                      '• ${issue.studentCount} student(s): ${issue.message.toLowerCase()}',
                    ),
                  ),
                ],
                if (inspection.blockingIssues.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...inspection.blockingIssues.map(
                    (issue) => Text(
                      '• ${issue.studentCount} student(s): ${issue.message}',
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            key: const Key('bulk-export-confirm'),
            onPressed: inspection.canContinue
                ? () => Navigator.pop(context, true)
                : null,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Generate PDF'),
          ),
        ],
      );
    },
  );

  String _sessionLabel(String? uuid) => uuid == null
      ? 'All sessions'
      : _sessions
                .where((item) => item.uuid == uuid)
                .map((item) => item.name)
                .firstOrNull ??
            'Selected session';

  String _classLabel(String? uuid) => uuid == null
      ? 'All classes'
      : _classes
                .where((item) => item.uuid == uuid)
                .map((item) => item.name)
                .firstOrNull ??
            'Selected class';

  String _sectionLabel(String? uuid) =>
      uuid == null ? 'All sections' : _sectionNames[uuid] ?? 'Selected section';

  // ------------------------------------------------------------
  // Build
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final selection = _selection;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AuthenticatedAppBar(
        actions: [
          if (widget.canPrint)
            IconButton(
              key: const Key('print-basket-action'),
              tooltip: 'Print Basket (${_printBasketStudents.length})',
              onPressed: _showPrintBasket,
              icon: Badge.count(
                count: _printBasketStudents.length,
                isLabelVisible: _printBasketStudents.isNotEmpty,
                child: const Icon(Icons.shopping_basket_outlined),
              ),
            ),
          if (widget.canPrint)
            IconButton(
              key: const Key('bulk-export-action'),
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
          if (widget.canPrint && _selectedStudentUuids.isNotEmpty)
            IconButton(
              key: const Key('add-selection-to-print-basket'),
              tooltip: 'Add selected to Print Basket',
              onPressed: _addSelectionToPrintBasket,
              icon: const Icon(Icons.add_shopping_cart_outlined),
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
          final pagePadding = constraints.maxWidth > 900 ? 28.0 : 16.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Padding(
                padding: EdgeInsets.all(pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPageHeading(),
                    const SizedBox(height: 18),
                    _buildToolbar(),
                    const SizedBox(height: 12),
                    _buildLifecycleNotice(),
                    if (_bulkExportStatus != null) ...[
                      const SizedBox(height: 10),
                      _buildBulkExportStatus(),
                    ],
                    if (_selectedStudentUuids.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildSelectionBar(selection),
                    ],
                    const SizedBox(height: 14),
                    _buildResultsHeader(),
                    const SizedBox(height: 10),
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

  Widget _buildPageHeading() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;

        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID cards',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Preview, verify and prepare student ID cards for '
              '${widget.schoolName}.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        );

        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (widget.canDesign)
              OutlinedButton.icon(
                onPressed: _openDesigner,
                icon: const Icon(Icons.design_services_outlined),
                label: const Text('Design card'),
              ),
            if (widget.canPrint)
              OutlinedButton.icon(
                onPressed: _showPrintBasket,
                icon: Badge.count(
                  count: _printBasketStudents.length,
                  isLabelVisible: _printBasketStudents.isNotEmpty,
                  child: const Icon(Icons.shopping_basket_outlined),
                ),
                label: const Text('Print Basket'),
              ),
            if (widget.canPrint)
              FilledButton.icon(
                onPressed: _exportingBulk ? null : _downloadFilteredCards,
                icon: _exportingBulk
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Bulk PDF'),
              ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              if (actions.children.isNotEmpty) ...[
                const SizedBox(height: 16),
                actions,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: heading),
            if (actions.children.isNotEmpty) actions,
          ],
        );
      },
    );
  }

  Widget _buildToolbar() {
    if (_loadingFilters) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Loading card filters...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 900;

          final search = TextField(
            decoration: InputDecoration(
              hintText: 'Search student, admission no. or roll no.',
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
            onChanged: _onSearchChanged,
          );

          final session = _dropdown<String>(
            label: 'Academic Session',
            value: _selectedSessionUuid,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Sessions')),
              ..._sessions.map(
                (item) =>
                    DropdownMenuItem(value: item.uuid, child: Text(item.name)),
              ),
            ],
            onChanged: _selectSession,
          );

          final schoolClass = _dropdown<String>(
            label: 'Class',
            value: _selectedClassUuid,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Classes')),
              ..._classes.map(
                (item) =>
                    DropdownMenuItem(value: item.uuid, child: Text(item.name)),
              ),
            ],
            onChanged: _selectClass,
          );

          final section = _dropdown<String>(
            label: 'Section',
            value: _selectedSectionUuid,
            items: [
              const DropdownMenuItem(value: null, child: Text('All Sections')),
              ..._sections.map(
                (item) =>
                    DropdownMenuItem(value: item.uuid, child: Text(item.name)),
              ),
            ],
            onChanged: _selectSection,
            enabled: _selectedClassUuid != null && _sections.isNotEmpty,
          );

          final verification = _dropdown<String>(
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
              setState(() {
                _verificationStatus = value;
              });
              _loadStudents(reset: true);
            },
          );

          final printed = _dropdown<bool>(
            label: 'Printed',
            value: _printed,
            items: const [
              DropdownMenuItem(value: null, child: Text('All Records')),
              DropdownMenuItem(value: false, child: Text('Not Printed')),
              DropdownMenuItem(value: true, child: Text('Printed')),
            ],
            onChanged: (value) {
              setState(() {
                _printed = value;
              });
              _loadStudents(reset: true);
            },
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    session,
                    schoolClass,
                    section,
                    verification,
                    printed,
                  ],
                ),
                if (_sectionError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _sectionError!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                    ),
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
                  Expanded(child: session),
                  const SizedBox(width: 10),
                  Expanded(child: schoolClass),
                  const SizedBox(width: 10),
                  Expanded(child: section),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [verification, printed],
              ),
              if (_sectionError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _sectionError!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildLifecycleNotice() {
    return Container(
      key: const Key('pdf-lifecycle-explanation'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: AppColors.info),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'PDF export is non-destructive and does not mark cards printed. '
              'Use Mark Printed only after physical production.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkExportStatus() {
    return Container(
      key: const Key('bulk-export-status'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _bulkExportStatus!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar(StudentLifecycleSelection selection) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.20)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${_selectedStudentUuids.length} selected',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.canVerify)
            OutlinedButton.icon(
              onPressed: selection.canBatchVerify
                  ? () => _runSelectedLifecycle(verify: true)
                  : null,
              icon: const Icon(Icons.verified_outlined, size: 18),
              label: const Text('Verify selected'),
            ),
          if (widget.canPrint)
            OutlinedButton.icon(
              onPressed: _addSelectionToPrintBasket,
              icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
              label: const Text('Add to Print Basket'),
            ),
          if (widget.canMarkPrinted)
            OutlinedButton.icon(
              onPressed: selection.canBatchMarkPrinted
                  ? () => _runSelectedLifecycle(verify: false)
                  : null,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark printed'),
            ),
          if (widget.canVerify && selection.verifyIneligibleCount > 0)
            Text(
              '${selection.verifyIneligibleCount} selected record(s) are '
              'already verified.',
              key: const Key('cards-batch-verify-ineligible-message'),
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (widget.canMarkPrinted && selection.printIneligibleCount > 0)
            Text(
              '${selection.printIneligibleCount} selected record(s) are '
              'not verified.',
              key: const Key('cards-batch-print-ineligible-message'),
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          Text(
            'Selection is cleared when search or filters change. '
            'Add cards to Print Basket to keep them.',
            key: const Key('cards-selection-scope-note'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader() {
    final resultText = _totalStudents == 0
        ? 'No students'
        : '${_students.length} of $_totalStudents students loaded';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Card previews',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                resultText,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (_hasMore && !_loadingStudents)
          const Text(
            'Scroll to load more',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
      ],
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
          fillColor: enabled ? AppColors.surface : AppColors.surfaceMuted,
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
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  Widget _buildContent() {
    if (_loadingStudents) {
      return const _CardsLoadingState();
    }

    if (_error != null && _students.isEmpty) {
      return _CardsStateCard(
        icon: Icons.error_outline,
        iconColor: AppColors.danger,
        iconBackground: AppColors.dangerSoft,
        title: 'Unable to load cards',
        message: _error!,
        action: FilledButton.icon(
          onPressed: () => _loadStudents(reset: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    if (_students.isEmpty) {
      return const _CardsStateCard(
        icon: Icons.badge_outlined,
        iconColor: AppColors.accent,
        iconBackground: AppColors.accentSoft,
        title: 'No cards found',
        message: 'No students match the current search and filter selection.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;

        // Never create a second column until two minimum-width cards actually
        // fit. `ceil` made narrow mobile viewports split into tiny columns and
        // could collapse the document renderer below a usable size.
        final columns = math.max(
          1,
          ((constraints.maxWidth + spacing) / (250 + spacing)).floor(),
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
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: _students.length + (_loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
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

            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.035),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IdCardPreview(
                        key: Key('mobile-card-preview-${student.uuid}'),
                        student: student,
                        schoolName: widget.schoolName,
                        api: widget.api,
                        template: _cardTemplate,
                        sessionName: session?.name,
                        className: _className(student),
                        sectionName: _sectionName(student),
                        logoUrl: _schoolLogoUrl,
                        schoolProfile: _schoolProfile,
                        onEdit: widget.canEdit
                            ? () => _editStudent(student)
                            : null,
                        onPrint: widget.canPrint
                            ? () => _printStudentCard(student, session?.name)
                            : null,
                        onMarkPrinted:
                            widget.canMarkPrinted && student.isVerified
                            ? () => _markPrinted(student)
                            : null,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Checkbox(
                          value: _selectedStudentUuids.contains(student.uuid),
                          onChanged:
                              widget.canPrint ||
                                  widget.canVerify ||
                                  widget.canMarkPrinted
                              ? (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedStudentUuids.add(student.uuid);
                                    } else {
                                      _selectedStudentUuids.remove(
                                        student.uuid,
                                      );
                                    }
                                  });
                                }
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: StudentLifecycleBadge(
                        status: student.lifecycleStatus,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CardsLoadingState extends StatelessWidget {
  const _CardsLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(height: 14),
            Text(
              'Loading card previews...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardsStateCard extends StatelessWidget {
  const _CardsStateCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon, color: iconColor, size: 29),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class _LoadedBulkStudents {
  const _LoadedBulkStudents({
    required this.students,
    required this.expectedTotal,
  });

  final List<ApiStudent> students;
  final int expectedTotal;
}
