import 'package:flutter/material.dart';

import '../models/academic_session.dart';
import '../models/bulk_card_export.dart';
import '../models/print_sheet.dart';
import '../models/school_class.dart';
import '../models/section.dart';
import '../services/api_service.dart';

class BulkPdfFilter {
  const BulkPdfFilter({
    this.scope = BulkCardExportScope.matchingFilters,
    this.search,
    this.sessionUuid,
    this.classUuid,
    this.sectionUuid,
    this.createdFrom,
    this.createdTo,
    this.printSettings = const PrintSheetSettings(),
  });

  final BulkCardExportScope scope;
  final String? search;
  final String? sessionUuid;
  final String? classUuid;
  final String? sectionUuid;
  final DateTime? createdFrom;
  final DateTime? createdTo;
  final PrintSheetSettings printSettings;
}

class BulkPdfFilterDialog extends StatefulWidget {
  const BulkPdfFilterDialog({
    super.key,
    required this.schoolUuid,
    required this.api,
    required this.sessions,
    required this.classes,
    this.initialSearch,
    this.initialSessionUuid,
    this.initialClassUuid,
    this.initialSectionUuid,
    this.selectedStudentCount = 0,
    this.printBasketCount = 0,
    required this.cardWidthMm,
    required this.cardHeightMm,
    required this.hasBackDesign,
    this.verificationStatus,
    this.printed,
  });

  final String schoolUuid;
  final ApiService api;
  final List<AcademicSession> sessions;
  final List<SchoolClass> classes;
  final String? initialSearch;
  final String? initialSessionUuid;
  final String? initialClassUuid;
  final String? initialSectionUuid;
  final int selectedStudentCount;
  final int printBasketCount;
  final double cardWidthMm;
  final double cardHeightMm;
  final bool hasBackDesign;
  final String? verificationStatus;
  final bool? printed;

  @override
  State<BulkPdfFilterDialog> createState() => _BulkPdfFilterDialogState();
}

class _BulkPdfFilterDialogState extends State<BulkPdfFilterDialog> {
  late final TextEditingController _search;
  String? _sessionUuid;
  String? _classUuid;
  String? _sectionUuid;
  DateTime? _createdFrom;
  DateTime? _createdTo;
  List<SchoolSection> _sections = const [];
  bool _loadingSections = false;
  late BulkCardExportScope _scope;
  late PrintLayoutMode _layoutMode;
  late PrintPaperSize _paperSize;
  late PrintPaperOrientation _paperOrientation;
  late final TextEditingController _margin;
  late final TextEditingController _gap;
  bool _cropMarks = false;
  PrintSides _sides = PrintSides.frontOnly;
  DuplexFlipEdge _flipEdge = DuplexFlipEdge.longEdge;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialSearch);
    _sessionUuid = widget.initialSessionUuid;
    _classUuid = widget.initialClassUuid;
    _sectionUuid = widget.initialSectionUuid;
    _scope = widget.printBasketCount > 0
        ? BulkCardExportScope.printBasket
        : widget.selectedStudentCount > 0
        ? BulkCardExportScope.selectedStudents
        : BulkCardExportScope.matchingFilters;
    _layoutMode = PrintLayoutMode.oneCardPerPage;
    _paperSize = PrintPaperSize.a4;
    _paperOrientation = PrintPaperOrientation.portrait;
    _margin = TextEditingController(text: '10');
    _gap = TextEditingController(text: '4');
    if (_classUuid != null) _loadSections(_classUuid!);
  }

  @override
  void dispose() {
    _search.dispose();
    _margin.dispose();
    _gap.dispose();
    super.dispose();
  }

  PrintSheetSettings? _printSettings() {
    final margin = double.tryParse(_margin.text.trim());
    final gap = double.tryParse(_gap.text.trim());
    if (margin == null || gap == null) return null;
    return PrintSheetSettings(
      mode: _layoutMode,
      paperSize: _paperSize,
      orientation: _paperOrientation,
      marginMm: margin,
      gapMm: gap,
      cropMarks: _cropMarks,
      sides: _sides,
      flipEdge: _flipEdge,
    );
  }

  Future<void> _loadSections(String classUuid) async {
    setState(() => _loadingSections = true);
    try {
      final sections = await widget.api.getSections(
        schoolUuid: widget.schoolUuid,
        classUuid: classUuid,
      );
      if (mounted && _classUuid == classUuid) {
        setState(() {
          _sections = sections;
          if (!_sections.any((item) => item.uuid == _sectionUuid)) {
            _sectionUuid = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _loadingSections = false);
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final current = from ? _createdFrom : _createdTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => from ? _createdFrom = picked : _createdTo = picked);
    }
  }

  String _dateLabel(DateTime? value) => value == null
      ? 'Any date'
      : '${value.day.toString().padLeft(2, '0')}/'
            '${value.month.toString().padLeft(2, '0')}/${value.year}';

  void _submit() {
    if (_createdFrom != null &&
        _createdTo != null &&
        _createdFrom!.isAfter(_createdTo!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From date cannot be after till date.')),
      );
      return;
    }
    final printSettings = _printSettings();
    if (printSettings == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid margin and spacing values.')),
      );
      return;
    }
    final plan = PrintSheetPlan.calculate(
      settings: printSettings,
      cardWidthMm: widget.cardWidthMm,
      cardHeightMm: widget.cardHeightMm,
      cardCount: 1,
    );
    if (!plan.isValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(plan.validationError!)));
      return;
    }
    Navigator.of(context).pop(
      BulkPdfFilter(
        scope: _scope,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        sessionUuid: _sessionUuid,
        classUuid: _classUuid,
        sectionUuid: _sectionUuid,
        createdFrom: _createdFrom,
        createdTo: _createdTo,
        printSettings: printSettings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Download bulk ID cards'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose the exact student set. Your current Cards filters are copied here and will not be changed.',
            ),
            if (widget.selectedStudentCount > 0 ||
                widget.printBasketCount > 0) ...[
              const SizedBox(height: 12),
              RadioGroup<BulkCardExportScope>(
                groupValue: _scope,
                onChanged: (value) => setState(() => _scope = value!),
                child: Column(
                  children: [
                    if (widget.printBasketCount > 0)
                      RadioListTile<BulkCardExportScope>(
                        key: const Key('bulk-scope-print-basket'),
                        value: BulkCardExportScope.printBasket,
                        title: Text(
                          'Print Basket (${widget.printBasketCount})',
                        ),
                      ),
                    if (widget.selectedStudentCount > 0)
                      RadioListTile<BulkCardExportScope>(
                        key: const Key('bulk-scope-selected'),
                        value: BulkCardExportScope.selectedStudents,
                        title: Text(
                          'Selected students only (${widget.selectedStudentCount})',
                        ),
                      ),
                    const RadioListTile<BulkCardExportScope>(
                      key: Key('bulk-scope-filtered'),
                      value: BulkCardExportScope.matchingFilters,
                      title: Text('All students matching filters'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              enabled: _scope == BulkCardExportScope.matchingFilters,
              decoration: const InputDecoration(
                labelText: 'Student name, admission no. or roll no.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _dropdown(
              label: 'Academic session',
              value: _sessionUuid,
              items: widget.sessions
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.uuid,
                      child: Text(item.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _sessionUuid = value),
              enabled: _scope == BulkCardExportScope.matchingFilters,
            ),
            const SizedBox(height: 12),
            _dropdown(
              label: 'Class',
              value: _classUuid,
              items: widget.classes
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.uuid,
                      child: Text(item.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _classUuid = value;
                  _sectionUuid = null;
                  _sections = const [];
                });
                if (value != null) _loadSections(value);
              },
              enabled: _scope == BulkCardExportScope.matchingFilters,
            ),
            const SizedBox(height: 12),
            _dropdown(
              label: _loadingSections ? 'Loading sections…' : 'Section',
              value: _sectionUuid,
              items: _sections
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.uuid,
                      child: Text(item.name),
                    ),
                  )
                  .toList(),
              onChanged:
                  _scope != BulkCardExportScope.matchingFilters ||
                      _classUuid == null ||
                      _loadingSections
                  ? null
                  : (value) => setState(() => _sectionUuid = value),
            ),
            if (widget.verificationStatus != null ||
                widget.printed != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  [
                    if (widget.verificationStatus != null)
                      'Verification: ${widget.verificationStatus!.replaceAll('_', ' ')}',
                    if (widget.printed != null)
                      'Print status: ${widget.printed! ? 'Printed' : 'Not printed'}',
                  ].join('  •  '),
                  key: const Key('bulk-inherited-lifecycle-filters'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _dateButton(
                    'Entry date from',
                    _createdFrom,
                    () => _pickDate(from: true),
                    enabled: _scope == BulkCardExportScope.matchingFilters,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateButton(
                    'Entry date till',
                    _createdTo,
                    () => _pickDate(from: false),
                    enabled: _scope == BulkCardExportScope.matchingFilters,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: const Color(0xfff5f7fb),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Print layout',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<PrintLayoutMode>(
                      key: const Key('print-layout-mode'),
                      initialValue: _layoutMode,
                      decoration: const InputDecoration(
                        labelText: 'Output',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: PrintLayoutMode.oneCardPerPage,
                          child: Text('One card per page'),
                        ),
                        DropdownMenuItem(
                          value: PrintLayoutMode.sheet,
                          child: Text('Multiple cards per sheet'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _layoutMode = value!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PrintSides>(
                      key: const Key('print-sides'),
                      isExpanded: true,
                      initialValue: _sides,
                      decoration: const InputDecoration(
                        labelText: 'Card sides',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: PrintSides.frontOnly,
                          child: Text('Front only'),
                        ),
                        if (widget.hasBackDesign)
                          const DropdownMenuItem(
                            value: PrintSides.duplex,
                            child: Text('Front and back (duplex)'),
                          ),
                      ],
                      onChanged: (value) => setState(() => _sides = value!),
                    ),
                    if (!widget.hasBackDesign)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Add a back design in Designer to enable duplex output.',
                        ),
                      ),
                    if (_sides == PrintSides.duplex) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<DuplexFlipEdge>(
                        key: const Key('print-duplex-flip-edge'),
                        isExpanded: true,
                        initialValue: _flipEdge,
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
                            setState(() => _flipEdge = value!),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Use the same flip-edge option in the printer dialog. Back-side slots are mirrored automatically.',
                        ),
                      ),
                    ],
                    if (_layoutMode == PrintLayoutMode.sheet) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<PrintPaperSize>(
                              key: const Key('print-paper-size'),
                              initialValue: _paperSize,
                              decoration: const InputDecoration(
                                labelText: 'Paper',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: PrintPaperSize.a4,
                                  child: Text('A4'),
                                ),
                                DropdownMenuItem(
                                  value: PrintPaperSize.letter,
                                  child: Text('Letter'),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _paperSize = value!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child:
                                DropdownButtonFormField<PrintPaperOrientation>(
                                  key: const Key('print-paper-orientation'),
                                  initialValue: _paperOrientation,
                                  decoration: const InputDecoration(
                                    labelText: 'Orientation',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: PrintPaperOrientation.portrait,
                                      child: Text('Portrait'),
                                    ),
                                    DropdownMenuItem(
                                      value: PrintPaperOrientation.landscape,
                                      child: Text('Landscape'),
                                    ),
                                  ],
                                  onChanged: (value) => setState(
                                    () => _paperOrientation = value!,
                                  ),
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('print-margin-mm'),
                              controller: _margin,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Margins (mm)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              key: const Key('print-gap-mm'),
                              controller: _gap,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Spacing (mm)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      CheckboxListTile(
                        key: const Key('print-crop-marks'),
                        contentPadding: EdgeInsets.zero,
                        value: _cropMarks,
                        onChanged: (value) =>
                            setState(() => _cropMarks = value ?? false),
                        title: const Text('Add crop marks'),
                      ),
                      _sheetSummary(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: const Text('Create PDF'),
      ),
    ],
  );

  Widget _sheetSummary() {
    final settings = _printSettings();
    if (settings == null) {
      return const Text(
        'Enter numeric margin and spacing values.',
        style: TextStyle(color: Colors.red),
      );
    }
    final plan = PrintSheetPlan.calculate(
      settings: settings,
      cardWidthMm: widget.cardWidthMm,
      cardHeightMm: widget.cardHeightMm,
      cardCount: 1,
    );
    if (!plan.isValid) {
      return Text(
        plan.validationError!,
        key: const Key('print-sheet-error'),
        style: const TextStyle(color: Colors.red),
      );
    }
    return Text(
      '${plan.columns} × ${plan.rows} = ${plan.cardsPerPage} cards per '
      '${settings.paperLabel} ${settings.orientationLabel} sheet. Cards retain '
      'their exact physical size.${settings.isDuplex ? ' Back slots are mirrored for ${settings.flipEdge == DuplexFlipEdge.longEdge ? 'long-edge' : 'short-edge'} printing.' : ''}',
      key: const Key('print-sheet-summary'),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?>? onChanged,
    bool enabled = true,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      const DropdownMenuItem(value: null, child: Text('All')),
      ...items,
    ],
    onChanged: enabled ? onChanged : null,
  );

  Widget _dateButton(
    String label,
    DateTime? value,
    VoidCallback onPressed, {
    bool enabled = true,
  }) => OutlinedButton(
    onPressed: enabled ? onPressed : null,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(children: [Text(label), Text(_dateLabel(value))]),
    ),
  );
}
