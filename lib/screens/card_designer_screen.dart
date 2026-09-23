// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/api_personnel.dart';
import '../models/api_student.dart';
import '../models/card_template.dart';
import '../models/design_barcode.dart';
import '../models/design_geometry.dart';
import '../models/school_profile.dart';
import '../models/student_field.dart';
import '../navigation/app_navigation.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_scale_viewport.dart';
import '../widgets/authenticated_app_bar.dart';
import '../widgets/design_document_view.dart';
import '../widgets/designer_colour_field.dart';
import '../widgets/designer_guides.dart';
import '../widgets/designer_numeric_field.dart';
import '../widgets/designer_shortcuts.dart';
import '../widgets/public_design_share_button.dart';
import '../widgets/public_verification_settings_button.dart';

class CardDesignerScreen extends StatefulWidget {
  const CardDesignerScreen({
    super.key,
    required this.schoolUuid,
    required this.api,
    required this.initialTemplate,
    this.canManagePublicShare = false,
  });

  // Logical pixels shared by the entry warning and editor layout.
  static const double minimumEditorWidth = 600;
  static const double recommendedEditorWidth = 1050;
  static const double recommendedEditorHeight = 600;

  static const String smallScreenMessage =
      'Card Designer works best on a larger screen. '
      'Open this page on a desktop or larger display for easier editing.';

  final String schoolUuid;
  final ApiService api;
  final CardTemplate initialTemplate;
  final bool canManagePublicShare;

  @override
  State<CardDesignerScreen> createState() => _CardDesignerScreenState();
}

class _CardDesignerScreenState extends State<CardDesignerScreen> {
  late CardTemplate _template;
  late CardTemplate _savedTemplate;

  late final TextEditingController _name;
  late final TextEditingController _canvasWidth;
  late final TextEditingController _canvasHeight;
  late final TextEditingController _canvasBackground;

  final TransformationController _viewTransform = TransformationController();

  final FocusNode _canvasFocus = FocusNode(debugLabel: 'designer canvas');

  final TextEditingController _inlineText = TextEditingController();

  final FocusNode _inlineTextFocus = FocusNode(
    debugLabel: 'designer inline text',
  );

  String? _inlineEditingId;
  String? _inlineOriginalText;

  final GlobalKey _canvasCoordinates = GlobalKey();

  final ValueNotifier<List<DesignerGuide>> _guides =
      ValueNotifier<List<DesignerGuide>>(<DesignerGuide>[]);

  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  final List<_DesignerSnapshot> _history = <_DesignerSnapshot>[];

  final List<String> _recentColours = <String>[];

  final Map<String, double> _previousBorderWidths = <String, double>{};

  String _borderWidthKey(String id) => '${_editingBack ? 'back' : 'front'}:$id';

  CardTemplate? _gestureStart;

  String? _gestureId;
  String? _selectedId;
  String? _logoUrl;

  Offset _gestureRemainder = Offset.zero;

  SchoolProfile? _schoolProfile;

  List<StudentFieldDefinition> _customFields = const <StudentFieldDefinition>[];

  int _historyIndex = 0;

  double _zoom = 1;

  bool _workspacePanning = false;
  bool _syncingName = false;
  bool _smallScreenAccepted = false;
  bool _dirtyValue = false;
  bool _saving = false;
  bool _localDuplicate = false;
  bool _editingBack = false;
  bool _showLayers = false;
  bool _showProperties = false;
  bool _allowPop = false;
  bool _leaveDialogOpen = false;

  String _previewIdentityType = 'student';

  Map<String, String> get _availableSystemFields {
    if (_previewIdentityType == 'student') {
      return _systemFields;
    }

    const studentOnly = {
      'admission_no',
      'roll_no',
      'stream',
      'father_name',
      'mother_name',
      'aadhaar',
      'session',
      'class',
      'section',
    };

    return Map.fromEntries(
      _systemFields.entries.where((entry) => !studentOnly.contains(entry.key)),
    );
  }

  Iterable<StudentFieldDefinition> get _availableCustomFields {
    final prefix = switch (_previewIdentityType) {
      'teacher' => 'Teacher • ',
      'staff' => 'Staff • ',
      _ => null,
    };

    return _customFields.where((field) {
      if (!field.isActive) {
        return false;
      }

      final personnelField =
          field.label.startsWith('Teacher • ') ||
          field.label.startsWith('Staff • ');

      return prefix == null ? !personnelField : field.label.startsWith(prefix);
    });
  }

  String _saveState = 'Saved';
  String? _canvasError;

  int _idCounter = 0;

  static final _sampleStudent = ApiStudent(
    uuid: 'preview',
    sessionUuid: 'preview',
    classUuid: 'preview',
    sectionUuid: 'preview',
    admissionNo: 'COM/52',
    rollNo: '18',
    stream: 'COMMERCE',
    fullName: 'Piyush Kumar Verma',
    fatherName: 'Tirath Verma',
    motherName: 'Dewanti Devi',
    dob: DateTime(2006, 6, 30),
    bloodGroup: 'A+',
    mobile: '9693836200',
    aadhaar: '216232301889',
    address: 'Basai Toli, Sundi, Ranchi',
    verificationUrl:
        'https://campusid.co.in/verify/sample-verification-token',
    isActive: true,
  );

  static final _samplePersonnel = ApiPersonnel(
    uuid: 'personnel-preview',
    personnelType: PersonnelType.teacher,
    employeeNo: 'EMP-1042',
    fullName: 'Asha Singh',
    designation: 'Senior Teacher',
    department: 'Science',
    dob: DateTime(1990, 2, 3),
    gender: 'Female',
    bloodGroup: 'A+',
    mobile: '9000000000',
    email: 'asha@example.edu',
    address: 'Ranchi',
    photoPath: null,
    verificationStatus: 'verified',
    lifecycleStatus: 'ready_for_print',
    correctionNote: null,
    verifiedAt: null,
    verifiedByName: null,
    printedAt: null,
    printedByName: null,
    printCount: 0,
    isActive: true,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  DesignDocument get _document => _editingBack
      ? (_template.backDocument ?? _template.document)
      : _template.document;

  DesignElement? get _selected => _document.elements
      .where((element) => element.id == _selectedId)
      .firstOrNull;

  bool get _dirty => _dirtyValue;

  bool get _canUndo =>
      _historyIndex > 0 ||
      (_gestureStart != null && !identical(_gestureStart, _template));

  bool get _canRedo =>
      _gestureStart == null && _historyIndex + 1 < _history.length;

  @override
  void initState() {
    super.initState();

    _template = widget.initialTemplate.deepCopy();
    _savedTemplate = _template.deepCopy();

    _name = TextEditingController(text: _template.name)..addListener(_rename);

    _canvasWidth = TextEditingController(
      text: _document.canvas.width.toStringAsFixed(2),
    );

    _canvasHeight = TextEditingController(
      text: _document.canvas.height.toStringAsFixed(2),
    );

    _canvasBackground = TextEditingController(
      text: _document.canvas.backgroundColor,
    );

    _history.add(_DesignerSnapshot(_template, _selectedId, false));

    _loadAssets();
  }

  Future<void> _loadAssets() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.api
            .getStudentFields(widget.schoolUuid)
            .catchError((_) => <StudentFieldDefinition>[]),

        widget.api
            .getSchoolProfile(widget.schoolUuid)
            .then<SchoolProfile?>((profile) => profile, onError: (_) => null),

        widget.api
            .getPersonnelFields(
              schoolUuid: widget.schoolUuid,
              personnelType: PersonnelType.teacher,
            )
            .catchError((_) => <StudentFieldDefinition>[]),

        widget.api
            .getPersonnelFields(
              schoolUuid: widget.schoolUuid,
              personnelType: PersonnelType.staff,
            )
            .catchError((_) => <StudentFieldDefinition>[]),
      ]);

      if (!mounted) {
        return;
      }

      _updateUi(() {
        _customFields = [
          ...(results[0] as List<StudentFieldDefinition>),

          ..._labeledFields(
            results[2] as List<StudentFieldDefinition>,
            'Teacher',
          ),

          ..._labeledFields(
            results[3] as List<StudentFieldDefinition>,
            'Staff',
          ),
        ];

        _schoolProfile = results[1] as SchoolProfile?;

        _logoUrl = _schoolProfile?.logoUrl;
      });
    } catch (_) {
      // Optional metadata is not required for the designer
      // to remain usable.
    }
  }

  static List<StudentFieldDefinition> _labeledFields(
    List<StudentFieldDefinition> fields,
    String identityLabel,
  ) {
    return fields
        .map(
          (field) => StudentFieldDefinition(
            uuid: field.uuid,
            fieldKey: field.fieldKey,
            label: '$identityLabel • ${field.label}',
            dataType: field.dataType,
            isRequired: field.isRequired,
            displayOrder: field.displayOrder,
            isActive: field.isActive,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _name.removeListener(_rename);

    _name.dispose();

    _canvasWidth.dispose();
    _canvasHeight.dispose();
    _canvasBackground.dispose();

    _canvasFocus.dispose();
    _inlineText.dispose();
    _inlineTextFocus.dispose();

    _viewTransform.dispose();

    _revision.dispose();
    _guides.dispose();

    super.dispose();
  }

  void _updateUi(VoidCallback change) {
    change();
    _revision.value++;
  }

  void _rename() {
    if (_syncingName) {
      return;
    }

    _commitTemplate(_template.copyWith(name: _name.text));
  }

  void _select(String? id) {
    if (_inlineEditingId != null && _inlineEditingId != id) {
      _commitInlineTextEdit();
    }

    if (_selectedId == id) {
      if (_inlineEditingId == null) {
        _canvasFocus.requestFocus();
      }
      return;
    }

    _endGesture();

    _updateUi(() {
      _selectedId = id;

      _history[_historyIndex] = _DesignerSnapshot(
        _template,
        id,
        _localDuplicate,
      );
    });

    // Selection rebuilds the workspace. Restore keyboard focus after that
    // rebuild so arrow-key nudging and other canvas shortcuts keep working.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _inlineEditingId != null) {
        return;
      }

      _canvasFocus.requestFocus();
    });
  }

  void _beginInlineTextEdit(String id) {
    final element = _document.elements
        .where((element) => element.id == id)
        .firstOrNull;

    if (element == null || element.locked || !element.visible) {
      return;
    }

    // Bound values must remain bindings. Double-clicking them simply
    // selects the element and opens Properties instead of converting
    // their rendered preview value into static text.
    if (element.type == DesignElementType.boundText ||
        element.type == DesignElementType.customFieldText) {
      _select(id);

      if (!_showProperties) {
        setState(() {
          _showProperties = true;
        });
      }

      return;
    }

    if (element.type != DesignElementType.text) {
      return;
    }

    _endGesture();
    _select(id);

    final text = element.data['text'] as String? ?? '';

    _inlineText.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );

    setState(() {
      _inlineEditingId = id;
      _inlineOriginalText = text;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _inlineEditingId != id) {
        return;
      }

      _inlineTextFocus.requestFocus();
    });
  }

  void _commitInlineTextEdit() {
    final id = _inlineEditingId;

    if (id == null) {
      return;
    }

    final original = _inlineOriginalText ?? '';
    final nextText = _inlineText.text;

    _updateUi(() {
      _inlineEditingId = null;
      _inlineOriginalText = null;
    });

    if (nextText != original) {
      _updateElement(id, (element) {
        if (element.type != DesignElementType.text) {
          return element;
        }

        return element.copyWith(data: {...element.data, 'text': nextText});
      });
    }

    _canvasFocus.requestFocus();
  }

  void _cancelInlineTextEdit() {
    if (_inlineEditingId == null) {
      return;
    }

    final original = _inlineOriginalText ?? '';

    _inlineText.value = TextEditingValue(
      text: original,
      selection: TextSelection.collapsed(offset: original.length),
    );

    _updateUi(() {
      _inlineEditingId = null;
      _inlineOriginalText = null;
    });

    _canvasFocus.requestFocus();
  }

  Future<void> _applyCanvasDimensions() async {
    final width = double.tryParse(_canvasWidth.text.trim());

    final height = double.tryParse(_canvasHeight.text.trim());

    if (width == null ||
        height == null ||
        !width.isFinite ||
        !height.isFinite ||
        width <= 10 ||
        height <= 10 ||
        width > 2000 ||
        height > 2000) {
      _updateUi(() {
        _canvasError =
            'Width and height must be greater than 10 and at most 2000 mm.';
      });

      return;
    }

    await _changeCanvasGeometry(
      _document.canvas.copyWith(width: width, height: height),
    );
  }

  Future<void> _setCanvasOrientation(String orientation) async {
    final canvas = _document.canvas;

    if (orientation == canvas.orientation) {
      return;
    }

    final next = canvas.copyWith(width: canvas.height, height: canvas.width);

    await _changeCanvasGeometry(next);
  }

  Future<void> _setCr80Preset() async {
    await _changeCanvasGeometry(
      _document.canvas.copyWith(width: 85.6, height: 53.98),
    );
  }

  Future<void> _changeCanvasGeometry(DesignCanvas nextCanvas) async {
    final current = _document.canvas;

    if (current.width == nextCanvas.width &&
        current.height == nextCanvas.height) {
      _syncCanvasControllers();
      return;
    }

    final strategy = _document.elements.isEmpty
        ? CanvasResizeStrategy.keepPositions
        : await _chooseCanvasResizeStrategy(
            orientationChanged: current.orientation != nextCanvas.orientation,
          );

    if (!mounted || strategy == null) {
      if (mounted) {
        _syncCanvasControllers();
      }

      return;
    }

    final next = resizeDesignDocument(_document, nextCanvas, strategy);

    final otherDocument = _editingBack
        ? _template.document
        : _template.backDocument;

    final resizedOther = otherDocument == null
        ? null
        : resizeDesignDocument(
            otherDocument,
            otherDocument.canvas.copyWith(
              width: nextCanvas.width,
              height: nextCanvas.height,
            ),
            strategy,
          );

    _updateUi(() {
      _canvasError = null;
    });

    _commitTemplate(
      _editingBack
          ? _template.copyWith(document: resizedOther, backDocument: next)
          : _template.copyWith(document: next, backDocument: resizedOther),
    );

    _syncCanvasControllers();

    if (strategy == CanvasResizeStrategy.keepPositions &&
        hasElementsOutsideCanvas(next)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Some elements extend outside the canvas.'),
        ),
      );
    }
  }

  Future<CanvasResizeStrategy?> _chooseCanvasResizeStrategy({
    required bool orientationChanged,
  }) async {
    var selected = CanvasResizeStrategy.keepPositions;

    return showDialog<CanvasResizeStrategy>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            orientationChanged
                ? 'Change canvas orientation'
                : 'Change canvas size',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How should existing elements be adjusted?'),
              const SizedBox(height: 12),
              RadioGroup<CanvasResizeStrategy>(
                groupValue: selected,
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() {
                      selected = value;
                    });
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final strategy in CanvasResizeStrategy.values)
                      RadioListTile<CanvasResizeStrategy>(
                        key: ValueKey('canvas-resize-${strategy.name}'),
                        value: strategy,
                        contentPadding: EdgeInsets.zero,
                        title: Text(switch (strategy) {
                          CanvasResizeStrategy.keepPositions =>
                            'Keep positions',
                          CanvasResizeStrategy.scaleProportionally =>
                            'Scale proportionally',
                          CanvasResizeStrategy.fitToCanvas => 'Fit to canvas',
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('canvas-resize-apply'),
              onPressed: () {
                Navigator.pop(context, selected);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isCr80 =>
      (_document.canvas.width - 85.6).abs() < .001 &&
      (_document.canvas.height - 53.98).abs() < .001;

  void _syncCanvasControllers() {
    _canvasWidth.text = _document.canvas.width.toStringAsFixed(2);

    _canvasHeight.text = _document.canvas.height.toStringAsFixed(2);

    _canvasBackground.text = _document.canvas.backgroundColor;
  }

  bool _sameTemplate(CardTemplate a, CardTemplate b) {
    if (identical(a, b)) {
      return true;
    }

    final sameBack =
        a.backDocument == null && b.backDocument == null ||
        a.backDocument != null &&
            b.backDocument != null &&
            _sameDocument(a.backDocument!, b.backDocument!);

    return a.name == b.name &&
        _sameDocument(a.document, b.document) &&
        sameBack;
  }

  bool _sameDocument(DesignDocument a, DesignDocument b) =>
      identical(a, b) ||
      (_sameJson(a.canvas.toJson(), b.canvas.toJson()) &&
          _sameJson(a.settings, b.settings) &&
          a.elements.length == b.elements.length &&
          Iterable<int>.generate(a.elements.length).every(
            (index) =>
                identical(a.elements[index], b.elements[index]) ||
                _sameElement(a.elements[index], b.elements[index]),
          ));

  bool _sameElement(DesignElement a, DesignElement b) =>
      a.id == b.id &&
      a.type == b.type &&
      a.x == b.x &&
      a.y == b.y &&
      a.width == b.width &&
      a.height == b.height &&
      a.rotation == b.rotation &&
      a.zIndex == b.zIndex &&
      a.locked == b.locked &&
      a.visible == b.visible &&
      _sameJson(a.style, b.style) &&
      _sameJson(a.data, b.data);

  bool _sameJson(Object? a, Object? b) {
    if (identical(a, b) || a == b) {
      return true;
    }

    if (a is List && b is List) {
      return a.length == b.length &&
          Iterable<int>.generate(
            a.length,
          ).every((index) => _sameJson(a[index], b[index]));
    }

    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every(
            (key) => b.containsKey(key) && _sameJson(a[key], b[key]),
          );
    }

    return false;
  }

  String get _cleanState => _localDuplicate ? 'Local duplicate' : 'Saved';

  String get _dirtyState =>
      _localDuplicate ? 'Local duplicate • unsaved' : 'Unsaved changes';

  void _refreshDirtyState() {
    _dirtyValue = !_sameTemplate(_template, _savedTemplate);

    _saveState = _dirty ? _dirtyState : _cleanState;
  }

  void _record(CardTemplate next) {
    _history.removeRange(_historyIndex + 1, _history.length);

    _history.add(_DesignerSnapshot(next, _selectedId, _localDuplicate));

    if (_history.length > 80) {
      _history.removeAt(0);
    }

    _historyIndex = _history.length - 1;
  }

  void _commit(
    DesignDocument next, {
    String? selectedId,
    bool gestureUpdate = false,
  }) => _commitTemplate(
    _editingBack
        ? _template.copyWith(backDocument: next)
        : _template.copyWith(document: next),
    selectedId: selectedId,
    gestureUpdate: gestureUpdate,
  );

  void _commitTemplate(
    CardTemplate next, {
    String? selectedId,
    bool gestureUpdate = false,
  }) {
    if (!gestureUpdate) {
      _endGesture();
    }

    if (_sameTemplate(next, _template)) {
      return;
    }

    _updateUi(() {
      _template = next;

      if (selectedId != null) {
        _selectedId = selectedId;
      }

      if (_selected == null) {
        _selectedId = null;
      }

      if (_gestureStart == null) {
        _record(next);
      }

      // Avoid full-document serialization/comparison
      // for every pointer event.
      _dirtyValue =
          _gestureStart != null || !_sameTemplate(next, _savedTemplate);

      _saveState = _dirty ? _dirtyState : _cleanState;
    });
  }

  void _beginGesture(String id) {
    _endGesture();

    _gestureStart = _template;

    _gestureId = id;

    _gestureRemainder = Offset.zero;
  }

  void _endGesture() {
    if (_guides.value.isNotEmpty) {
      _guides.value = [];
    }

    final start = _gestureStart;

    if (start == null) {
      return;
    }

    _updateUi(() {
      _gestureStart = null;
      _gestureId = null;

      _gestureRemainder = Offset.zero;

      if (!_sameTemplate(start, _template)) {
        _record(_template);
      }

      _refreshDirtyState();
    });
  }

  void _restore(int index) {
    _updateUi(() {
      _historyIndex = index;

      _template = _history[index].template;

      if (_editingBack && !_template.hasBackDesign) {
        _editingBack = false;
      }

      _selectedId = _history[index].selectedId;

      _localDuplicate = _history[index].localDuplicate;

      _syncingName = true;

      _name.text = _template.name;

      _syncingName = false;

      _syncCanvasControllers();

      _canvasError = null;

      _refreshDirtyState();
    });
  }

  void _switchSide(bool showBack) {
    _commitInlineTextEdit();
    if (_editingBack == showBack) {
      return;
    }

    _endGesture();

    if (showBack && !_template.hasBackDesign) {
      _commitTemplate(_template.withBlankBack());
    }

    _updateUi(() {
      _editingBack = showBack;

      _selectedId = null;

      _syncCanvasControllers();

      _canvasError = null;
    });
  }

  Future<void> _removeBackDesign() async {
    if (!_template.hasBackDesign) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove back design?'),
        content: const Text(
          'This removes the complete back side from this template. '
          'You can still use Undo before saving.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-remove-back-design'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Remove back'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    _endGesture();

    _selectedId = null;
    _editingBack = false;

    _commitTemplate(_template.copyWith(clearBackDocument: true));

    _syncCanvasControllers();
  }

  void _undo() {
    _commitInlineTextEdit();
    _endGesture();

    if (_canUndo) {
      _restore(_historyIndex - 1);
    }
  }

  void _redo() {
    _commitInlineTextEdit();
    _endGesture();

    if (_canRedo) {
      _restore(_historyIndex + 1);
    }
  }

  void _updateElement(
    String id,
    DesignElement Function(DesignElement) change, {
    bool gestureUpdate = false,
  }) {
    final live = _document.elements
        .where((element) => element.id == id)
        .firstOrNull;

    if (live != null) {
      var next = change(live);
      if (live.type == DesignElementType.circle) {
        final widthChanged = next.width != live.width;
        final heightChanged = next.height != live.height;
        if (widthChanged != heightChanged) {
          final side = widthChanged ? next.width : next.height;
          final bounded = math.min(
            side,
            math.min(
              _document.canvas.width - next.x,
              _document.canvas.height - next.y,
            ),
          );
          next = next.copyWith(width: bounded, height: bounded);
        }
      }
      _replace(next, gestureUpdate: gestureUpdate);
    }
  }

  void _replace(DesignElement replacement, {bool gestureUpdate = false}) {
    _commit(
      _document.copyWith(
        elements: [
          for (final element in _document.elements)
            if (element.id == replacement.id) replacement else element,
        ],
      ),
      gestureUpdate: gestureUpdate,
    );
  }

  void _add(DesignElementType type, {StudentFieldDefinition? customField}) {
    if (_document.elements.length >= DesignDocument.maxElements) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A design can contain at most 250 elements.'),
        ),
      );

      return;
    }

    final id =
        '${type.wire}-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

    final z = _document.elements.fold<int>(
      0,
      (value, element) => math.max(value, element.zIndex + 1),
    );

    final isImage =
        type == DesignElementType.studentPhoto ||
        type == DesignElementType.schoolLogo ||
        type == DesignElementType.principalSignature;

    final isQr = type == DesignElementType.qrCode;

    final isBarcode = type == DesignElementType.barcode;

    final defaultWidth =
        isImage ||
            isQr ||
            type == DesignElementType.circle ||
            type == DesignElementType.bloodDrop
        ? 20.0
        : isBarcode
        ? 35.0
        : 30.0;

    final defaultHeight =
        isQr ||
            type == DesignElementType.circle ||
            type == DesignElementType.bloodDrop
        ? 20.0
        : isImage
        ? 22.0
        : isBarcode
        ? 15.0
        : type == DesignElementType.line
        ? 1.0
        : {
            DesignElementType.roundedRectangle,
            DesignElementType.ellipse,
            DesignElementType.triangle,
          }.contains(type)
        ? 16.0
        : 6.0;

    final element = DesignElement(
      id: id,
      type: type,
      x: (_document.canvas.width - defaultWidth) / 2,
      y: (_document.canvas.height - defaultHeight) / 2,
      width: defaultWidth,
      height: defaultHeight,
      zIndex: z,
      style: switch (type) {
        DesignElementType.rectangle ||
        DesignElementType.roundedRectangle ||
        DesignElementType.ellipse ||
        DesignElementType.circle ||
        DesignElementType.triangle ||
        DesignElementType.bloodDrop => {
          'fill_color': type == DesignElementType.bloodDrop
              ? '#C62828'
              : '#E8EEF8',
          'border_color': type == DesignElementType.bloodDrop
              ? '#C62828'
              : '#242C61',
          'border_width': 0.5,
          'corner_radius': type == DesignElementType.roundedRectangle
              ? 3.0
              : 0.0,
        },
        DesignElementType.line => {'color': '#242C61', 'border_width': 0.5},
        DesignElementType.studentPhoto ||
        DesignElementType.schoolLogo ||
        DesignElementType.principalSignature => {
          'fit': type == DesignElementType.studentPhoto ? 'cover' : 'contain',
          'border_color': '#242C61',
          'border_width': 0.5,
          'corner_radius': 1.0,
        },
        DesignElementType.qrCode => {
          'color': '#000000',
          'background_color': '#FFFFFF',
          'quiet_zone': 1.0,
          'error_correction': 'medium',
        },
        DesignElementType.barcode => {
          'color': '#000000',
          'background_color': '#FFFFFF',
          'quiet_zone': 1.0,
          'show_text': true,
          'font_size': 2.5,
        },
        _ => {
          'font_size': 3.5,
          'font_weight': 400,
          'alignment': 'left',
          'color': '#111111',
        },
      },
      data: switch (type) {
        DesignElementType.text => {'text': 'New text'},
        DesignElementType.boundText => {
          'field': 'full_name',
          'fallback': '$_previewIdentityType name',
        },
        DesignElementType.customFieldText => {
          'field_uuid': customField!.uuid,
          'label': customField.label,
          'fallback': customField.label,
        },
        DesignElementType.qrCode =>
          _previewIdentityType == 'student'
              ? {'field': 'verification_url'}
              : {'field': 'employee_no', 'fallback': 'Employee number'},
        DesignElementType.bloodDrop => {
          'field': 'blood_group',
          'fallback': 'BG',
        },
        DesignElementType.barcode => {
          'field': _previewIdentityType == 'student'
              ? 'admission_no'
              : 'employee_no',
          'fallback': _previewIdentityType == 'student'
              ? 'Admission number'
              : 'Employee number',
          'symbology': 'code128',
        },
        _ => const {},
      },
    );

    _commit(
      _document.copyWith(elements: [..._document.elements, element]),
      selectedId: id,
    );
  }

  void _move(String id, double dx, double dy) {
    if (!dx.isFinite || !dy.isFinite) {
      return;
    }

    _updateElement(id, (element) {
      if (element.locked) {
        return element;
      }

      final maxX = math.max(0.0, _document.canvas.width - element.width);

      final maxY = math.max(0.0, _document.canvas.height - element.height);

      final remainder = _gestureId == id ? _gestureRemainder : Offset.zero;

      final rawX = (element.x + dx + remainder.dx).clamp(0.0, maxX);

      final rawY = (element.y + dy + remainder.dy).clamp(0.0, maxY);

      var x = rawX;
      var y = rawY;

      if (_document.settings['snap_enabled'] != false) {
        final grid = (_document.settings['grid_size'] as num?)?.toDouble() ?? 2;

        if (grid.isFinite && grid > 0) {
          x = (x / grid).round() * grid;

          y = (y / grid).round() * grid;
        }
      }

      x = x.clamp(0.0, maxX);

      y = y.clamp(0.0, maxY);

      if (_gestureId == id) {
        _gestureRemainder = Offset(rawX - x, rawY - y);
      }

      final next = element.copyWith(x: x, y: y);

      _updateGuides(next);

      return next;
    }, gestureUpdate: true);
  }

  void _resize(String id, String handle, double dx, double dy) {
    if (!dx.isFinite || !dy.isFinite) return;
    _updateElement(id, (element) {
      if (element.locked) return element;
      final left = handle.contains('left');
      final right = handle.contains('right');
      final top = handle.contains('top');
      final bottom = handle.contains('bottom');
      final originalRight = element.x + element.width;
      final originalBottom = element.y + element.height;
      var x = element.x;
      var y = element.y;
      var width = element.width;
      var height = element.height;
      if (left) {
        x += dx;
        width -= dx;
      }
      if (right) width += dx;
      if (top) {
        y += dy;
        height -= dy;
      }
      if (bottom) height += dy;
      final keepRatio = {
        DesignElementType.studentPhoto,
        DesignElementType.schoolLogo,
        DesignElementType.principalSignature,
        DesignElementType.qrCode,
        DesignElementType.circle,
      }.contains(element.type);
      if (keepRatio) {
        final ratio = element.type == DesignElementType.circle
            ? 1.0
            : element.width / element.height;
        if (dx.abs() >= dy.abs()) {
          height = width / ratio;
        } else {
          width = height * ratio;
        }
        if (left) x = originalRight - width;
        if (top) y = originalBottom - height;
      }
      width = width.clamp(2.0, _document.canvas.width);
      height = height.clamp(1.0, _document.canvas.height);
      if (left) x = originalRight - width;
      if (top) y = originalBottom - height;
      x = x.clamp(0.0, _document.canvas.width - width);
      y = y.clamp(0.0, _document.canvas.height - height);
      width = math.min(width, _document.canvas.width - x);
      height = math.min(height, _document.canvas.height - y);
      final next = element.copyWith(x: x, y: y, width: width, height: height);
      _updateGuides(next);
      return next;
    }, gestureUpdate: true);
  }

  void _remove() {
    final selected = _selected;

    if (selected == null || selected.locked) {
      return;
    }

    _commit(
      _document.copyWith(
        elements: _document.elements
            .where((element) => element.id != selected.id)
            .toList(),
      ),
    );
  }

  void _duplicate() {
    final selected = _selected;

    if (selected == null) {
      return;
    }

    if (_document.elements.length >= DesignDocument.maxElements) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A design can contain at most 250 elements.'),
        ),
      );

      return;
    }

    final id =
        '${selected.type.wire}-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

    final copy = selected.copyWith(
      id: id,
      x: math.min(selected.x + 2, _document.canvas.width - selected.width),
      y: math.min(selected.y + 2, _document.canvas.height - selected.height),
      zIndex: _topZ(),
    );

    _commit(
      _document.copyWith(elements: [..._document.elements, copy]),
      selectedId: id,
    );
  }

  int _topZ() {
    return _document.elements.fold<int>(
      0,
      (value, element) => math.max(value, element.zIndex + 1),
    );
  }

  void _layer(String operation) {
    final selected = _selected;

    if (selected == null) {
      return;
    }

    final ordered = [..._document.elements]
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    final index = ordered.indexWhere((element) => element.id == selected.id);

    final target = switch (operation) {
      'front' => ordered.length - 1,
      'back' => 0,
      'forward' => math.min(index + 1, ordered.length - 1),
      _ => math.max(index - 1, 0),
    };

    ordered.removeAt(index);

    ordered.insert(target, selected);

    _commit(
      _document.copyWith(
        elements: [
          for (var i = 0; i < ordered.length; i++)
            ordered[i].copyWith(zIndex: i),
        ],
      ),
    );
  }

  void _align(String where) {
    final element = _selected;

    if (element == null || element.locked) {
      return;
    }

    _replace(
      element.copyWith(
        x: switch (where) {
          'left' => 0,
          'hcenter' => (_document.canvas.width - element.width) / 2,
          'right' => _document.canvas.width - element.width,
          _ => element.x,
        },
        y: switch (where) {
          'top' => 0,
          'vcenter' => (_document.canvas.height - element.height) / 2,
          'bottom' => _document.canvas.height - element.height,
          _ => element.y,
        },
      ),
    );
  }

  void _updateGuides(DesignElement next) {
    if (_gestureId != next.id) {
      return;
    }

    final box = _canvasCoordinates.currentContext?.findRenderObject();

    if (box is! RenderBox || !box.hasSize) {
      return;
    }

    final pixelsPerMm =
        (box.localToGlobal(Offset(box.size.width, 0)) -
                box.localToGlobal(Offset.zero))
            .distance /
        _document.canvas.width;

    _guides.value = DesignerGuides.detect(
      moving: next,
      elements: _document.elements,
      pixelsPerMm: pixelsPerMm,
    );
  }

  void _command(DesignerCommand command, Offset delta) {
    switch (command) {
      case DesignerCommand.undo:
        _undo();

      case DesignerCommand.redo:
        _redo();

      case DesignerCommand.save:
        _save();

      case DesignerCommand.delete:
        _remove();

      case DesignerCommand.duplicate:
        _duplicate();

      case DesignerCommand.deselect:
        _select(null);

      case DesignerCommand.nudge:
        _endGesture();

        final id = _selectedId;

        if (id == null) {
          return;
        }

        // Keyboard nudges remain precise even when
        // pointer grid snapping is enabled.
        _updateElement(
          id,
          (element) => element.locked
              ? element
              : element.copyWith(
                  x: (element.x + delta.dx).clamp(
                    0.0,
                    math.max(0.0, _document.canvas.width - element.width),
                  ),
                  y: (element.y + delta.dy).clamp(
                    0.0,
                    math.max(0.0, _document.canvas.height - element.height),
                  ),
                ),
        );

      case DesignerCommand.editText:
        final id = _selectedId;

        if (id != null) {
          _beginInlineTextEdit(id);
        }

        if (id == null) {
          return;
        }

        // Keyboard nudges remain precise even when
        // pointer grid snapping is enabled.
        _updateElement(
          id,
          (element) => element.locked
              ? element
              : element.copyWith(
                  x: (element.x + delta.dx).clamp(
                    0.0,
                    math.max(0.0, _document.canvas.width - element.width),
                  ),
                  y: (element.y + delta.dy).clamp(
                    0.0,
                    math.max(0.0, _document.canvas.height - element.height),
                  ),
                ),
        );
    }
  }

  Future<bool> _save() async {
    _commitInlineTextEdit();
    if (_localDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This is a local working copy. '
            'The current server supports only one design per school, '
            'so it cannot be saved over the source.',
          ),
        ),
      );

      return false;
    }

    final name = _name.text.trim();

    if (_saving || name.isEmpty) {
      return false;
    }

    if (name.length > CardTemplate.maxNameLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template name must be 120 characters or fewer.'),
        ),
      );

      return false;
    }

    if (_template.document.elements.length > DesignDocument.maxElements ||
        (_template.backDocument?.elements.length ?? 0) >
            DesignDocument.maxElements) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A design can contain at most 250 elements.'),
        ),
      );

      return false;
    }

    if (!_dirty) {
      return true;
    }

    _endGesture();

    _commitTemplate(_template.copyWith(name: name));

    final submitted = _template;

    _updateUi(() {
      _saving = true;
      _saveState = 'Saving…';
    });

    try {
      final saved = await widget.api.saveCardTemplate(
        widget.schoolUuid,
        submitted,
        expectedUpdatedAt: _savedTemplate.updatedAt,
      );

      if (!mounted) {
        return false;
      }

      _updateUi(() {
        final authoritative = saved.deepCopy();

        _template = authoritative;

        _savedTemplate = authoritative.deepCopy();

        if (!_document.elements.any((element) => element.id == _selectedId)) {
          _selectedId = null;
        }

        _localDuplicate = false;

        _history[_historyIndex] = _DesignerSnapshot(
          authoritative,
          _selectedId,
          false,
        );

        _syncingName = true;

        _name.text = authoritative.name;

        _syncingName = false;

        _syncCanvasControllers();

        _canvasError = null;

        _saving = false;

        _refreshDirtyState();
      });

      return !_dirty;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      final conflict = error is ApiException && error.statusCode == 409;

      _updateUi(() {
        _saving = false;

        _saveState = conflict
            ? 'Conflict'
            : error is ApiException && error.statusCode == 422
            ? 'Validation failed'
            : 'Save failed';
      });

      final messenger = ScaffoldMessenger.of(context);

      messenger.hideCurrentSnackBar();

      messenger.showSnackBar(
        SnackBar(
          content: Text(_saveFailureMessage(error)),
          duration: conflict
              ? const Duration(seconds: 15)
              : const Duration(seconds: 4),
          action: conflict
              ? SnackBarAction(
                  key: const Key('reload-latest-template'),
                  label: 'Reload latest',
                  onPressed: _reloadLatest,
                )
              : null,
        ),
      );

      return false;
    }
  }

  String _saveFailureMessage(Object error) {
    if (error is ApiException) {
      final detail = error.message
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceFirst(RegExp(r'^body(?:\.design)?:\s*Value error,\s*'), '')
          .trim();

      final concise = detail.length > 180
          ? '${detail.substring(0, 177)}...'
          : detail;

      if (error.statusCode == 422) {
        return concise.isEmpty
            ? 'The template could not be saved because it is invalid.'
            : 'Template validation failed: $concise';
      }

      if (error.statusCode == 409) {
        return 'Someone else saved this template after you loaded it. '
            'Your edits are still here. '
            'Reload the latest version to replace them.';
      }

      if (concise == 'The server returned an invalid card template.' ||
          concise.contains('unsupported schema version')) {
        return '$concise Your edited design is still safe.';
      }

      return concise.isEmpty
          ? 'Unable to save the template. Please try again.'
          : 'Unable to save the template: $concise';
    }

    return 'Unable to save the template. '
        'Check your connection and try again.';
  }

  Future<void> _reloadLatest() async {
    if (_saving) {
      return;
    }

    _updateUi(() {
      _saving = true;
      _saveState = 'Reloading…';
    });

    try {
      final loaded = await widget.api.getCardTemplate(widget.schoolUuid);

      if (!mounted) {
        return;
      }

      final authoritative = loaded.deepCopy();

      _updateUi(() {
        _template = authoritative;

        _savedTemplate = authoritative.deepCopy();

        _selectedId = null;

        _localDuplicate = false;

        _history
          ..clear()
          ..add(_DesignerSnapshot(authoritative, null, false));

        _historyIndex = 0;

        _syncingName = true;

        _name.text = authoritative.name;

        _syncingName = false;

        _syncCanvasControllers();

        _canvasError = null;

        _saving = false;

        _refreshDirtyState();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _updateUi(() {
        _saving = false;

        _saveState = 'Reload failed';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to reload the latest template. '
            'Your edits are still safe.',
          ),
        ),
      );
    }
  }

  Future<void> _duplicateDesign() async {
    _endGesture();

    final stamp = DateTime.now().microsecondsSinceEpoch;

    final duplicate = _template.duplicateWorkingCopy(
      elementId: (element, index) =>
          '${element.type.wire}-$stamp-${_idCounter++}-$index',
    );

    _updateUi(() {
      _localDuplicate = true;

      _template = duplicate;

      _selectedId = null;

      _syncingName = true;

      _name.text = duplicate.name;

      _syncingName = false;

      _syncCanvasControllers();

      _canvasError = null;

      _history
        ..clear()
        ..add(_DesignerSnapshot(duplicate, null, true));

      _historyIndex = 0;

      _refreshDirtyState();
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Local duplicate created. '
          'It is independent, but cannot be saved until the server '
          'supports multiple designs per school.',
        ),
      ),
    );
  }

  Future<void> _revertToSaved() async {
    if (!_dirty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revert to saved design?'),
        content: const Text(
          'This discards the current working changes and restores '
          'the last successfully saved design. '
          'You can still use Undo.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-revert-design'),
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Revert'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    _endGesture();

    _localDuplicate = false;

    _selectedId = null;

    _commitTemplate(_savedTemplate.deepCopy());

    _syncingName = true;

    _name.text = _template.name;

    _syncingName = false;

    _syncCanvasControllers();
  }

  Future<void> _reset() async {
    final side = _editingBack ? 'back side' : 'front side';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset $side?'),
        content: Text(
          _editingBack
              ? 'This clears every element from the back side. '
                    'You can still use Undo before saving.'
              : 'This replaces the front side with the default template. '
                    'You can still use Undo before saving.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    _endGesture();

    _selectedId = null;

    _commit(
      _editingBack
          ? _template.withBlankBack().backDocument!.copyWith(elements: const [])
          : CardTemplate.uploadedDesign.deepCopy().document,
    );

    _syncCanvasControllers();
  }

  Future<bool> _confirmLeave() async {
    _endGesture();

    if (!_dirty) {
      return true;
    }

    if (_leaveDialogOpen) {
      return false;
    }

    _leaveDialogOpen = true;

    final action = await showDialog<_LeaveAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: Text(
          _localDuplicate
              ? 'You have unsaved changes in a local duplicate. '
                    'This server supports only one design per school, '
                    'so this copy cannot be saved without overwriting the source.'
              : 'You have unsaved changes to this card design.',
        ),
        actions: [
          TextButton(
            key: const Key('unsaved-cancel'),
            onPressed: () {
              Navigator.pop(context, _LeaveAction.cancel);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('unsaved-discard'),
            onPressed: () {
              Navigator.pop(context, _LeaveAction.discard);
            },
            child: const Text('Discard'),
          ),
          FilledButton(
            key: const Key('unsaved-save-leave'),
            onPressed: _localDuplicate
                ? null
                : () {
                    Navigator.pop(context, _LeaveAction.save);
                  },
            child: const Text('Save and leave'),
          ),
        ],
      ),
    );

    _leaveDialogOpen = false;

    if (!mounted || action == null || action == _LeaveAction.cancel) {
      return false;
    }

    if (action == _LeaveAction.discard) {
      return true;
    }

    return _save();
  }

  Future<void> _handlePop(bool didPop) async {
    if (didPop || _allowPop) {
      return;
    }

    if (!await _confirmLeave() || !mounted) {
      return;
    }

    _updateUi(() {
      _allowPop = true;
    });

    Navigator.of(context).pop();
  }

  Widget _section(Object? Function() select, Widget Function() builder) =>
      _DesignerSection(revision: _revision, select: select, builder: builder);

  Object _layerSignature() => <Object?>[
    _selectedId,
    for (final element in _document.elements)
      (
        element.id,
        element.zIndex,
        element.visible,
        element.locked,
        _elementLabel(element),
      ),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;

      final mobile = size.width < CardDesignerScreen.minimumEditorWidth;

      final small =
          size.width < CardDesignerScreen.recommendedEditorWidth ||
          size.height < CardDesignerScreen.recommendedEditorHeight;

      if (mobile || (small && !_smallScreenAccepted)) {
        // A viewport change may remove a pointer target
        // before it receives pointer-up.
        if (_gestureStart != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _endGesture();
            }
          });
        }

        return _guardNavigation(
          Scaffold(
            backgroundColor: AppColors.background,
            appBar: AuthenticatedAppBar(
              title: const Text('Card designer'),
              actions: [
                if (widget.canManagePublicShare)
                  PublicVerificationSettingsButton(
                    schoolUuid: widget.schoolUuid,
                    api: widget.api,
                  ),
                if (widget.canManagePublicShare)
                  PublicDesignShareButton(
                    schoolUuid: widget.schoolUuid,
                    api: widget.api,
                  ),
              ],
            ),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.desktop_windows_outlined,
                            size: 32,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Card Designer',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          CardDesignerScreen.smallScreenMessage,
                          key: Key('designer-screen-warning'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (!mobile) ...[
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                _smallScreenAccepted = true;
                              });
                            },
                            icon: const Icon(Icons.open_in_full_rounded),
                            label: const Text('Continue anyway'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return DesignerShortcuts(
        onCommand: _command,
        child: Focus(autofocus: true, child: _editor()),
      );
    },
  );

  Widget _guardNavigation(Widget child) => AppNavigationGuard(
    onNavigateAway: _confirmLeave,
    child: ValueListenableBuilder<int>(
      valueListenable: _revision,
      builder: (context, _, child) => PopScope(
        canPop: _allowPop || !_dirty,
        onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
        child: child!,
      ),
      child: child,
    ),
  );

  Widget _editor() => _guardNavigation(
    Scaffold(
      backgroundColor: AppColors.background,
      appBar: AuthenticatedAppBar(
        title: const Text('Card designer'),
        actions: [
          if (widget.canManagePublicShare)
            PublicVerificationSettingsButton(
              schoolUuid: widget.schoolUuid,
              api: widget.api,
            ),
          if (widget.canManagePublicShare)
            PublicDesignShareButton(
              schoolUuid: widget.schoolUuid,
              api: widget.api,
            ),
          if (widget.canManagePublicShare) _appBarDivider(),

          _section(
            () => (_editingBack, _template.hasBackDesign),
            _sideSwitcher,
          ),

          _section(
            () => (
              _dirty,
              _saving,
              _localDuplicate,
              _document,
              _template.hasBackDesign,
            ),
            () => PopupMenuButton<_TemplateAction>(
              key: const Key('designer-template-actions'),
              tooltip: 'Design actions',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) {
                switch (action) {
                  case _TemplateAction.duplicate:
                    _duplicateDesign();

                  case _TemplateAction.revert:
                    _revertToSaved();

                  case _TemplateAction.reset:
                    _reset();

                  case _TemplateAction.removeBack:
                    _removeBackDesign();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _TemplateAction.duplicate,
                  enabled: !_saving,
                  child: const ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.copy_outlined),
                    title: Text('Duplicate design'),
                  ),
                ),
                PopupMenuItem(
                  value: _TemplateAction.revert,
                  enabled: _dirty && !_saving,
                  child: const ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.history_rounded),
                    title: Text('Revert to saved'),
                  ),
                ),
                PopupMenuItem(
                  value: _TemplateAction.reset,
                  enabled:
                      !_saving &&
                      !_sameDocument(
                        _document,
                        CardTemplate.uploadedDesign.document,
                      ),
                  child: const ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.restart_alt_rounded),
                    title: Text('Reset design'),
                  ),
                ),
                if (_template.hasBackDesign)
                  PopupMenuItem(
                    value: _TemplateAction.removeBack,
                    enabled: !_saving,
                    child: const ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.remove_circle_outline_rounded),
                      title: Text('Remove back design'),
                    ),
                  ),
              ],
            ),
          ),
          _appBarDivider(),

          _section(
            () => (_saveState, _saving, _dirty, _localDuplicate),
            _designerSaveControls,
          ),
        ],
      ),
      body: Column(
        children: [
          _section(
            () => (
              _canUndo,
              _canRedo,
              _selectedId,
              _selected?.locked,
              _customFields,
              _showLayers,
              _showProperties,
            ),
            _toolbar,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    if (_showLayers)
                      Container(
                        width: 240,
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          border: Border(
                            right: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: _section(_layerSignature, _layers),
                      ),
                    Expanded(
                      child: _section(
                        () => (
                          _document,
                          _selectedId,
                          _inlineEditingId,
                          _zoom,
                          _workspacePanning,
                          _logoUrl,
                          _schoolProfile,
                          _previewIdentityType,
                        ),
                        _workspace,
                      ),
                    ),
                    if (_showProperties)
                      Container(
                        width: 300,
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          border: Border(
                            left: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: _section(
                          () => (_template, _selectedId, _canvasError),
                          _inspector,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _toolbar() => Material(
    color: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    child: Container(
      height: 72,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        children: [
          IconButton(
            key: const Key('toggle-layers'),
            onPressed: () => setState(() => _showLayers = !_showLayers),
            icon: Icon(
              _showLayers ? Icons.layers_rounded : Icons.layers_outlined,
            ),
            tooltip: _showLayers ? 'Hide Layers' : 'Show Layers',
            isSelected: _showLayers,
          ),
          IconButton(
            key: const Key('toggle-properties'),
            onPressed: () => setState(() => _showProperties = !_showProperties),
            icon: Icon(
              _showProperties ? Icons.tune_rounded : Icons.tune_outlined,
            ),
            tooltip: _showProperties ? 'Hide Properties' : 'Show Properties',
            isSelected: _showProperties,
          ),
          _toolbarDivider(),
          _toolbarActionGroup(
            label: 'HISTORY',
            children: [
              IconButton(
                onPressed: _canUndo ? _undo : null,
                icon: const Icon(Icons.undo_rounded),
                tooltip: 'Undo',
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  disabledForegroundColor: AppColors.disabled,
                ),
              ),
              IconButton(
                onPressed: _canRedo ? _redo : null,
                icon: const Icon(Icons.redo_rounded),
                tooltip: 'Redo',
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  disabledForegroundColor: AppColors.disabled,
                ),
              ),
            ],
          ),

          _toolbarDivider(),

          _toolbarActionGroup(
            label: 'TEXT & DATA',
            children: [
              _tool(
                Icons.text_fields_rounded,
                'Text',
                () => _add(DesignElementType.text),
                key: 'add-text',
              ),
              _tool(
                Icons.badge_outlined,
                'Identity field',
                () => _add(DesignElementType.boundText),
                key: 'add-student-field',
              ),
              _customFieldTool(),
            ],
          ),

          _toolbarDivider(),

          _toolbarActionGroup(
            label: 'MEDIA',
            children: [
              _tool(
                Icons.person_outline_rounded,
                'Photo',
                () => _add(DesignElementType.studentPhoto),
                key: 'add-photo',
              ),
              _tool(
                Icons.school_outlined,
                'Logo',
                () => _add(DesignElementType.schoolLogo),
                key: 'add-logo',
              ),
              _tool(
                Icons.draw_outlined,
                'Signature',
                () => _add(DesignElementType.principalSignature),
                key: 'add-principal-signature',
              ),
            ],
          ),

          _toolbarDivider(),

          _toolbarActionGroup(
            label: 'SHAPES',
            children: [
              _tool(
                Icons.rectangle_outlined,
                'Rectangle',
                () => _add(DesignElementType.rectangle),
                key: 'add-rectangle',
              ),
              _tool(
                Icons.horizontal_rule_rounded,
                'Line',
                () => _add(DesignElementType.line),
                key: 'add-line',
              ),
              _tool(
                Icons.rounded_corner,
                'Rounded rectangle',
                () => _add(DesignElementType.roundedRectangle),
                key: 'add-rounded-rectangle',
              ),
              _tool(
                Icons.circle_outlined,
                'Ellipse',
                () => _add(DesignElementType.ellipse),
                key: 'add-ellipse',
              ),
              _tool(
                Icons.circle,
                'Circle',
                () => _add(DesignElementType.circle),
                key: 'add-circle',
              ),
              _tool(
                Icons.change_history_rounded,
                'Triangle',
                () => _add(DesignElementType.triangle),
                key: 'add-triangle',
              ),
              _tool(
                Icons.bloodtype_outlined,
                'Blood group',
                () => _add(DesignElementType.bloodDrop),
                key: 'add-blood-drop',
              ),
            ],
          ),

          _toolbarDivider(),

          _toolbarActionGroup(
            label: 'CODES',
            children: [
              _tool(
                Icons.qr_code_2_rounded,
                'QR code',
                () => _add(DesignElementType.qrCode),
                key: 'add-qr-code',
              ),
              _tool(
                Icons.view_week_outlined,
                'Barcode',
                () => _add(DesignElementType.barcode),
                key: 'add-barcode',
              ),
            ],
          ),

          _toolbarDivider(),

          _toolbarActionGroup(
            label: 'ELEMENT',
            children: [
              IconButton(
                onPressed: _selected == null ? null : _duplicate,
                icon: const Icon(Icons.copy_outlined),
                tooltip: 'Duplicate element',
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  disabledForegroundColor: AppColors.disabled,
                ),
              ),
              IconButton(
                onPressed: _selected == null ? null : _remove,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Delete',
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  disabledForegroundColor: AppColors.disabled,
                ),
              ),
            ],
          ),

          _toolbarDivider(),

          _toolbarActionGroup(
            label: 'ALIGN',
            children: [
              ...['left', 'hcenter', 'right', 'top', 'vcenter', 'bottom'].map(
                (value) => IconButton(
                  onPressed: _selected == null ? null : () => _align(value),
                  icon: Icon(switch (value) {
                    'left' => Icons.align_horizontal_left_rounded,
                    'hcenter' => Icons.align_horizontal_center_rounded,
                    'right' => Icons.align_horizontal_right_rounded,
                    'top' => Icons.align_vertical_top_rounded,
                    'vcenter' => Icons.align_vertical_center_rounded,
                    _ => Icons.align_vertical_bottom_rounded,
                  }, size: 19),
                  tooltip: switch (value) {
                    'left' => 'Align left',
                    'hcenter' => 'Align horizontal center',
                    'right' => 'Align right',
                    'top' => 'Align top',
                    'vcenter' => 'Align vertical center',
                    _ => 'Align bottom',
                  },
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    disabledForegroundColor: AppColors.disabled,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget _toolbarActionGroup({
    required String label,
    required List<Widget> children,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 3),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: .65,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: children),
      ],
    ),
  );

  Widget _toolbarDivider() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 5),
    child: VerticalDivider(color: AppColors.border, indent: 4, endIndent: 4),
  );

  Widget _customFieldTool() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: PopupMenuButton<StudentFieldDefinition>(
      tooltip: 'Custom field',
      enabled: _availableCustomFields.isNotEmpty,
      onSelected: (field) =>
          _add(DesignElementType.customFieldText, customField: field),
      itemBuilder: (context) => [
        for (final field in _availableCustomFields)
          PopupMenuItem<StudentFieldDefinition>(
            value: field,
            child: Text(field.label),
          ),
      ],
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: _availableCustomFields.isNotEmpty
              ? AppColors.surfaceSoft
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dynamic_form_outlined,
              size: 17,
              color: _availableCustomFields.isNotEmpty
                  ? AppColors.textPrimary
                  : AppColors.disabled,
            ),

            const SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: _availableCustomFields.isNotEmpty
                  ? AppColors.textSecondary
                  : AppColors.disabled,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _sideSwitcher() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: SegmentedButton<bool>(
        key: const Key('designer-side-switcher'),
        segments: [
          const ButtonSegment(
            value: false,
            icon: Icon(Icons.looks_one_outlined, size: 17),
            label: Text('Front'),
          ),
          ButtonSegment(
            value: true,
            icon: Icon(
              _template.hasBackDesign
                  ? Icons.flip_to_back_outlined
                  : Icons.add_box_outlined,
              size: 17,
            ),
            label: const Text('Back'),
          ),
        ],
        selected: {_editingBack},
        showSelectedIcon: false,
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          visualDensity: VisualDensity.compact,
          side: WidgetStatePropertyAll(
            BorderSide(color: Colors.white.withValues(alpha: 0.35)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.transparent,
          ),
        ),
        onSelectionChanged: (selection) {
          _switchSide(selection.first);
        },
      ),
    ),
  );
  Widget _appBarDivider() => Center(
    child: Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white.withValues(alpha: .16),
    ),
  );

  Widget _designerSaveControls() {
    final canSave = _dirty && !_saving && !_localDuplicate;

    final statusColour = _saving
        ? Colors.white70
        : _dirty
        ? AppColors.warning
        : Colors.white70;

    return Center(
      child: Container(
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: .15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const Key('designer-save-state'),
              padding: const EdgeInsets.only(left: 10, right: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _saving
                        ? Icons.sync_rounded
                        : _dirty
                        ? Icons.edit_outlined
                        : Icons.check_circle_outline_rounded,
                    size: 14,
                    color: statusColour,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _saveState,
                    style: TextStyle(
                      color: statusColour,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              width: 1,
              height: 20,
              color: Colors.white.withValues(alpha: .14),
            ),

            SizedBox(
              height: 32,
              child: TextButton.icon(
                key: const Key('designer-save'),
                onPressed: canSave ? _save : null,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: const Text('Save'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white38,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tool(
    IconData icon,
    String label,
    VoidCallback onTap, {
    required String key,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: IconButton(
      key: Key(key),
      onPressed: onTap,
      icon: Icon(icon, size: 19),
      tooltip: label,
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surfaceSoft,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
  );
  Widget _workspace() => Column(
    children: [
      Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(constraints.maxWidth, 820),
              child: Row(
                children: [
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ZOOM',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .65,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.zoom_out_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(
                          width: 88,
                          child: Slider(
                            value: _zoom,
                            min: .5,
                            max: 2,
                            divisions: 15,
                            label: '${(_zoom * 100).round()}%',
                            onChanged: (value) {
                              _updateUi(() => _zoom = value);
                            },
                          ),
                        ),
                        const Icon(
                          Icons.zoom_in_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 54,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '${(_zoom * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'PREVIEW',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .65,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Icon(
                          Icons.visibility_outlined,
                          size: 17,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            key: const Key('designer-preview-identity-type'),
                            value: _previewIdentityType,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                            ),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'student',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.school_outlined,
                                      size: 17,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(width: 7),
                                    Text('Student'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'teacher',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person_outline_rounded,
                                      size: 17,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(width: 7),
                                    Text('Teacher'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'staff',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.badge_outlined,
                                      size: 17,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(width: 7),
                                    Text('Staff'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                _updateUi(() {
                                  _previewIdentityType = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _updateUi(() {
                          _zoom = 1;
                          _viewTransform.value = Matrix4.identity();
                        });
                      },
                      icon: const Icon(Icons.fit_screen_outlined, size: 18),
                      label: const Text('Fit canvas'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      Expanded(
        child: Container(
          color: AppColors.surfaceMuted,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const pixelsPerMillimetre = 10.0;

              final naturalWidth = _document.canvas.width * pixelsPerMillimetre;

              final naturalHeight =
                  _document.canvas.height * pixelsPerMillimetre;

              final fitScale = math.min(
                (constraints.maxWidth - 32).clamp(1, double.infinity) /
                    naturalWidth,
                (constraints.maxHeight - 32).clamp(1, double.infinity) /
                    naturalHeight,
              );

              final displayWidth = naturalWidth * fitScale * _zoom;

              return Focus(
                focusNode: _canvasFocus,
                child: AppScaleGestureBoundary(
                  child: MouseRegion(
                    cursor: _workspacePanning
                        ? SystemMouseCursors.grabbing
                        : SystemMouseCursors.grab,
                    child: InteractiveViewer(
                      transformationController: _viewTransform,
                      panEnabled: true,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      onInteractionStart: (_) =>
                          _updateUi(() => _workspacePanning = true),
                      onInteractionEnd: (_) =>
                          _updateUi(() => _workspacePanning = false),
                      minScale: .5,
                      maxScale: 3,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            key: const Key('designer-canvas-frame'),
                            width: displayWidth,
                            child: Stack(
                              children: [
                                KeyedSubtree(
                                  key: _canvasCoordinates,
                                  child: DesignDocumentView(
                                    key: const Key('designer-canvas'),

                                    document: _document,
                                    student: _previewIdentityType == 'student'
                                        ? _sampleStudent
                                        : null,
                                    personnel: _previewIdentityType == 'student'
                                        ? null
                                        : ApiPersonnel(
                                            uuid: _samplePersonnel.uuid,
                                            personnelType:
                                                _previewIdentityType ==
                                                    'teacher'
                                                ? PersonnelType.teacher
                                                : PersonnelType.staff,
                                            employeeNo:
                                                _samplePersonnel.employeeNo,
                                            fullName: _samplePersonnel.fullName,
                                            designation:
                                                _previewIdentityType ==
                                                    'teacher'
                                                ? _samplePersonnel.designation
                                                : 'Office Administrator',
                                            department:
                                                _previewIdentityType ==
                                                    'teacher'
                                                ? _samplePersonnel.department
                                                : 'Administration',
                                            dob: _samplePersonnel.dob,
                                            gender: _samplePersonnel.gender,
                                            bloodGroup:
                                                _samplePersonnel.bloodGroup,
                                            mobile: _samplePersonnel.mobile,
                                            email: _samplePersonnel.email,
                                            address: _samplePersonnel.address,
                                            photoPath:
                                                _samplePersonnel.photoPath,
                                            verificationStatus: _samplePersonnel
                                                .verificationStatus,
                                            lifecycleStatus: _samplePersonnel
                                                .lifecycleStatus,
                                            correctionNote: null,
                                            verifiedAt: null,
                                            verifiedByName: null,
                                            printedAt: null,
                                            printedByName: null,
                                            printCount: 0,
                                            isActive: true,
                                            createdAt:
                                                _samplePersonnel.createdAt,
                                            updatedAt:
                                                _samplePersonnel.updatedAt,
                                          ),
                                    sessionName: '2026-2028',
                                    className: 'XII',
                                    sectionName: 'A',
                                    logoUrl: _logoUrl,
                                    schoolProfile: _schoolProfile,
                                    assetBaseUrl: widget.api.baseUrl,
                                    selectedId: _selectedId,
                                    interactive: true,

                                    inlineEditingId: _inlineEditingId,
                                    inlineTextController: _inlineText,
                                    inlineTextFocusNode: _inlineTextFocus,
                                    onInlineTextEditRequest:
                                        _beginInlineTextEdit,
                                    onInlineTextCommit: _commitInlineTextEdit,
                                    onInlineTextCancel: _cancelInlineTextEdit,

                                    onSelect: _select,
                                    onGestureStart: _beginGesture,
                                    onGestureEnd: _endGesture,
                                    isGestureActive: (id) => _gestureId == id,
                                    onMove: _move,
                                    onResize: (id, dw, dh) =>
                                        _resize(id, 'bottom-right', dw, dh),
                                    onResizeHandle: _resize,
                                  ),
                                ),
                                Positioned.fill(
                                  child:
                                      ValueListenableBuilder<
                                        List<DesignerGuide>
                                      >(
                                        valueListenable: _guides,
                                        builder: (context, guides, _) =>
                                            guides.isEmpty
                                            ? const SizedBox.shrink()
                                            : DesignerGuideOverlay(
                                                key: const Key(
                                                  'designer-smart-guides',
                                                ),
                                                guides: guides,
                                                canvasWidth:
                                                    _document.canvas.width,
                                                viewScale: _viewTransform.value
                                                    .getMaxScaleOnAxis(),
                                              ),
                                      ),
                                ),
                                if (_document.settings['grid_enabled'] != false)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: _GridPainter(
                                          (_document.settings['grid_size']
                                                      as num?)
                                                  ?.toDouble() ??
                                              2,
                                          _document.canvas.width,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  );

  Widget _layers() {
    final elements = [..._document.elements]
      ..sort((a, b) => b.zIndex.compareTo(a.zIndex));

    final selectedIndex = elements.indexWhere(
      (element) => element.id == _selectedId,
    );

    final hasSelection = selectedIndex >= 0;

    // Elements are displayed from highest z-index to lowest.
    final canMoveForward = hasSelection && selectedIndex > 0;

    final canMoveBackward = hasSelection && selectedIndex < elements.length - 1;

    return Material(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.layers_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Layers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${elements.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 8),
                  child: Text(
                    'LAYER ORDER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .7,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final buttonWidth = (constraints.maxWidth - 8) / 2;

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: buttonWidth,
                          child: OutlinedButton(
                            key: const Key('layer-bring-front'),
                            onPressed: canMoveForward
                                ? () => _layer('front')
                                : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              disabledForegroundColor: AppColors.disabled,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            child: Text('Bring front'),
                          ),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          child: OutlinedButton(
                            key: const Key('layer-bring-forward'),
                            onPressed: canMoveForward
                                ? () => _layer('forward')
                                : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              disabledForegroundColor: AppColors.disabled,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            child: Text('Forward'),
                          ),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          child: OutlinedButton(
                            key: const Key('layer-send-backward'),
                            onPressed: canMoveBackward
                                ? () => _layer('backward')
                                : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              disabledForegroundColor: AppColors.disabled,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            child: Text('Backward'),
                          ),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          child: OutlinedButton(
                            key: const Key('layer-send-back'),
                            onPressed: canMoveBackward
                                ? () => _layer('back')
                                : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              disabledForegroundColor: AppColors.disabled,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            child: Text('Send back'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: elements.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.layers_clear_outlined,
                            size: 32,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No elements yet',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Add an element from the toolbar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    itemCount: elements.length,
                    itemBuilder: (context, index) {
                      final element = elements[index];

                      final selected = element.id == _selectedId;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 1,
                        ),
                        child: Material(
                          color: selected
                              ? AppColors.accentSoft
                              : Colors.transparent,
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: selected
                                  ? AppColors.accent.withValues(alpha: .24)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Stack(
                            children: [
                              if (selected)
                                Positioned(
                                  left: 0,
                                  top: 8,
                                  bottom: 8,
                                  child: Container(
                                    width: 3,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ListTile(
                                key: Key('layer-${element.id}'),
                                selected: selected,
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: const EdgeInsets.only(
                                  left: 8,
                                  right: 4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                onTap: () {
                                  _select(element.id);
                                },
                                leading: IconButton(
                                  tooltip: element.visible ? 'Hide' : 'Show',
                                  icon: Icon(
                                    element.visible
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                    color: selected
                                        ? AppColors.accent
                                        : element.visible
                                        ? AppColors.textSecondary
                                        : AppColors.textMuted,
                                  ),
                                  onPressed: () {
                                    _updateElement(
                                      element.id,
                                      (live) =>
                                          live.copyWith(visible: !live.visible),
                                    );
                                  },
                                ),
                                title: Tooltip(
                                  message: _elementLabel(element),
                                  waitDuration: const Duration(
                                    milliseconds: 500,
                                  ),
                                  child: Text(
                                    _elementLabel(element),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected
                                          ? AppColors.accent
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                trailing: IconButton(
                                  tooltip: element.locked ? 'Unlock' : 'Lock',
                                  icon: Icon(
                                    element.locked
                                        ? Icons.lock_outline_rounded
                                        : Icons.lock_open_rounded,
                                    size: 18,
                                    color: element.locked
                                        ? AppColors.warning
                                        : selected
                                        ? AppColors.accent
                                        : AppColors.textMuted,
                                  ),
                                  onPressed: () {
                                    _updateElement(
                                      element.id,
                                      (live) =>
                                          live.copyWith(locked: !live.locked),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _elementLabel(DesignElement element) {
    // Give the migrated/default CampusID template meaningful names.
    switch (element.id) {
      case 'legacy-header':
        return 'Header background';
      case 'legacy-title':
        return 'School name';
      case 'legacy-subtitle':
        return 'School address';
      case 'legacy-photo':
        return _identityPhotoLabel;
      case 'legacy-name':
        return 'Full name';
      case 'legacy-admission':
        return 'Admission number';
      case 'legacy-father':
        return "Father's name";
      case 'legacy-dob':
        return 'Date of birth';
      case 'legacy-footer':
        return 'Footer background';
      case 'legacy-signature':
        return 'Principal signature';
    }

    return switch (element.type) {
      DesignElementType.text => _staticTextLayerLabel(element),

      DesignElementType.boundText => _boundTextLayerLabel(element),

      DesignElementType.customFieldText => _customFieldLayerLabel(element),

      DesignElementType.studentPhoto => _identityPhotoLabel,

      DesignElementType.schoolLogo => 'School logo',
      DesignElementType.principalSignature => 'Principal signature',
      DesignElementType.bloodDrop => 'Blood group',
      DesignElementType.roundedRectangle => 'Rounded rectangle',
      DesignElementType.ellipse => 'Ellipse',
      DesignElementType.circle => 'Circle',
      DesignElementType.triangle => 'Triangle',

      DesignElementType.rectangle => 'Rectangle',

      DesignElementType.line => 'Line',

      DesignElementType.qrCode => _codeLayerLabel(element, codeName: 'QR code'),

      DesignElementType.barcode => _codeLayerLabel(
        element,
        codeName: 'Barcode',
      ),
    };
  }

  String get _identityPhotoLabel => switch (_previewIdentityType) {
    'teacher' => 'Teacher photo',
    'staff' => 'Staff photo',
    _ => 'Student photo',
  };

  String _staticTextLayerLabel(DesignElement element) {
    final text = (element.data['text'] as String?)?.trim();

    if (text == null || text.isEmpty) {
      return 'Text';
    }

    if (text.toLowerCase() == 'principal sig.') {
      return 'Principal signature';
    }

    return text;
  }

  String _boundTextLayerLabel(DesignElement element) {
    final field = element.data['field'];

    if (field is String) {
      final label = _systemFields[field];

      if (label != null) {
        return label;
      }
    }

    final fallback = (element.data['fallback'] as String?)?.trim();

    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }

    return 'Identity field';
  }

  String _customFieldLayerLabel(DesignElement element) {
    final label = (element.data['label'] as String?)?.trim();

    if (label != null && label.isNotEmpty) {
      return label;
    }

    return 'Custom field';
  }

  String _codeLayerLabel(DesignElement element, {required String codeName}) {
    final source = _effectiveQrSource(element);

    switch (source) {
      case 'verification_link':
        return 'Verification $codeName';

      case 'multiple_fields':
        return 'Multi-field $codeName';

      case 'custom_field':
        final label = (element.data['label'] as String?)?.trim();

        if (label != null && label.isNotEmpty) {
          return '$label $codeName';
        }

        return 'Custom field $codeName';

      case 'system_field':
        final field = element.data['field'];

        if (field is String) {
          final label = _systemFields[field];

          if (label != null) {
            return '$label $codeName';
          }
        }

        return 'Identity $codeName';

      default:
        return 'Static $codeName';
    }
  }

  String _qrSource(DesignElement element) {
    if (element.data['fields'] is List) {
      return 'multiple_fields';
    }

    if (element.data['field_uuid'] is String) {
      return 'custom_field';
    }

    if (element.data['field'] == 'verification_url') {
      return 'verification_link';
    }

    if (element.data['field'] is String) {
      return 'system_field';
    }

    return 'static';
  }

  String _effectiveQrSource(DesignElement element) =>
      _previewIdentityType != 'student' &&
          _qrSource(element) == 'verification_link'
      ? 'system_field'
      : _qrSource(element);

  Map<String, dynamic> _qrDataForSource(DesignElement element, String source) {
    final prefix = element.data['prefix'] as String?;

    final suffix = element.data['suffix'] as String?;

    late final Map<String, dynamic> data;

    if (source == 'verification_link') {
      data = {'field': 'verification_url'};
    } else if (source == 'multiple_fields') {
      final idField = _previewIdentityType == 'student'
          ? 'admission_no'
          : 'employee_no';

      data = {
        'fields': [
          {'field': 'full_name', 'label': _systemFields['full_name']},
          {'field': idField, 'label': _systemFields[idField]},
        ],
        'format': 'json',
      };
    } else if (source == 'system_field') {
      final field = _previewIdentityType == 'student'
          ? 'admission_no'
          : 'employee_no';

      data = {'field': field, 'fallback': _systemFields[field]};
    } else if (source == 'custom_field') {
      final field = _availableCustomFields.firstOrNull;

      data = field == null
          ? {'text': 'CAMPUS-ID'}
          : {
              'field_uuid': field.uuid,
              'label': field.label,
              'fallback': field.label,
            };
    } else {
      data = {'text': 'CAMPUS-ID'};
    }

    if (source != 'multiple_fields') {
      if (prefix != null) {
        data['prefix'] = prefix;
      }

      if (suffix != null) {
        data['suffix'] = suffix;
      }
    }

    if (element.type == DesignElementType.barcode) {
      data['symbology'] = element.data['symbology'] ?? 'code128';
    }

    return data;
  }

  List<Map<String, dynamic>> _qrFields(DesignElement element) =>
      (element.data['fields'] as List? ?? const [])
          .whereType<Map>()
          .map((field) => Map<String, dynamic>.from(field))
          .toList();

  bool _hasQrField(DesignElement element, {String? field, String? fieldUuid}) =>
      _qrFields(element).any(
        (item) => item['field'] == field && item['field_uuid'] == fieldUuid,
      );

  Map<String, dynamic> _toggleQrField(
    DesignElement element, {
    String? field,
    String? fieldUuid,
    required String label,
    required bool selected,
  }) {
    final fields = _qrFields(element);

    bool matches(Map<String, dynamic> item) =>
        item['field'] == field && item['field_uuid'] == fieldUuid;

    if (selected) {
      if (fields.length < 20 && !fields.any(matches)) {
        fields.add({'field': ?field, 'field_uuid': ?fieldUuid, 'label': label});
      }
    } else {
      fields.removeWhere(matches);
    }

    return {...element.data, 'fields': fields};
  }

  List<DropdownMenuItem<String>> _qrCustomFieldItems(DesignElement element) {
    final selected = element.data['field_uuid'] as String?;

    final fields = _availableCustomFields.toList();

    return [
      if (selected != null && !fields.any((field) => field.uuid == selected))
        DropdownMenuItem(
          value: selected,
          enabled: false,
          child: const Text('Unavailable custom field'),
        ),
      for (final field in fields)
        DropdownMenuItem(value: field.uuid, child: Text(field.label)),
    ];
  }

  Widget _inspector() {
    final e = _selected;

    // Resolve by identity at event time; callbacks must not replace newer edits
    // with the element snapshot captured by the previous build.
    void update(DesignElement Function(DesignElement) change) {
      final live = _document.elements
          .where((element) => element.id == e?.id)
          .firstOrNull;

      if (live != null) {
        _replace(change(live));
      }
    }

    return Material(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent, width: 1.5),
            ),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      e == null
                          ? Icons.dashboard_customize_outlined
                          : Icons.tune_rounded,
                      size: 19,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e == null ? 'Canvas' : 'Properties',
                          key: Key(
                            e == null
                                ? 'canvas-properties'
                                : 'element-properties',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          e == null
                              ? 'Card layout and workspace'
                              : _elementLabel(e),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _propertyControl(
                    TextField(
                      key: const Key('template-name'),
                      controller: _name,
                      decoration: _propertyDecoration('Template name').copyWith(
                        prefixIcon: const Icon(
                          Icons.drive_file_rename_outline_rounded,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (e == null) ..._canvasProperties(),
                  if (e != null) ...[
                    _inspectorSectionHeader(
                      icon: Icons.open_with_rounded,
                      title: 'Position & size',
                      description: 'Placement, dimensions and rotation',
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 0,
                      children: [
                        _numberField(
                          'X',
                          e.x,
                          (value) => update(
                            (element) => element.copyWith(
                              x: value.clamp(
                                0.0,
                                math.max(
                                  0.0,
                                  _document.canvas.width - element.width,
                                ),
                              ),
                            ),
                          ),
                        ),
                        _numberField(
                          'Y',
                          e.y,
                          (value) => update(
                            (element) => element.copyWith(
                              y: value.clamp(
                                0.0,
                                math.max(
                                  0.0,
                                  _document.canvas.height - element.height,
                                ),
                              ),
                            ),
                          ),
                        ),
                        _numberField(
                          'Width',
                          e.width,
                          (value) => update(
                            (element) => element.copyWith(
                              width: value.clamp(
                                2.0,
                                math.max(
                                  2.0,
                                  _document.canvas.width - element.x,
                                ),
                              ),
                            ),
                          ),
                        ),
                        _numberField(
                          'Height',
                          e.height,
                          (value) => update(
                            (element) => element.copyWith(
                              height: value.clamp(
                                1.0,
                                math.max(
                                  1.0,
                                  _document.canvas.height - element.y,
                                ),
                              ),
                            ),
                          ),
                        ),
                        _numberField(
                          'Rotation',
                          e.rotation,
                          (value) => update(
                            (element) => element.copyWith(
                              rotation: value.clamp(-360, 360),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (e.type == DesignElementType.text ||
                        e.type == DesignElementType.boundText)
                      _inspectorSectionHeader(
                        icon: e.type == DesignElementType.text
                            ? Icons.text_fields_rounded
                            : Icons.badge_outlined,
                        title: e.type == DesignElementType.text
                            ? 'Content'
                            : 'Data binding',
                        description: e.type == DesignElementType.text
                            ? 'Text displayed on the card'
                            : 'Identity field displayed by this element',
                      ),
                    if (e.type == DesignElementType.text)
                      _textProperty(
                        'Text',
                        e.data['text'] as String? ?? '',
                        (value) => update(
                          (element) => element.copyWith(
                            data: {...element.data, 'text': value},
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Material(
                        color: AppColors.surfaceSoft,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              dense: true,
                              title: const Text(
                                'Locked',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              secondary: const Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                              ),
                              value: e.locked,
                              onChanged: (value) => update(
                                (element) => element.copyWith(locked: value),
                              ),
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              dense: true,
                              title: const Text(
                                'Visible',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              secondary: const Icon(
                                Icons.visibility_outlined,
                                size: 18,
                              ),
                              value: e.visible,
                              onChanged: (value) => update(
                                (element) => element.copyWith(visible: value),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (e.type == DesignElementType.boundText)
                      _dropdownProperty<String>(
                        key: ValueKey('student-field-${e.id}'),
                        label: 'Identity field',
                        value:
                            _availableSystemFields.containsKey(e.data['field'])
                            ? e.data['field'] as String
                            : 'full_name',
                        items: _availableSystemFields.entries
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            update(
                              (element) => element.copyWith(
                                data: {
                                  ...element.data,
                                  'field': value,
                                  'fallback': _systemFields[value],
                                },
                              ),
                            );
                          }
                        },
                      ),
                    if ({
                      DesignElementType.qrCode,
                      DesignElementType.barcode,
                    }.contains(e.type)) ...[
                      _inspectorSectionHeader(
                        icon: e.type == DesignElementType.qrCode
                            ? Icons.qr_code_2_rounded
                            : Icons.view_week_outlined,
                        title: e.type == DesignElementType.qrCode
                            ? 'QR code content'
                            : 'Barcode content',
                        description:
                            'Choose what information this code contains',
                      ),
                      if (e.type == DesignElementType.barcode)
                        _dropdownProperty<String>(
                          key: ValueKey('barcode-symbology-${e.id}'),
                          label: 'Barcode format',
                          value: e.data['symbology'] as String? ?? 'code128',
                          items: const [
                            DropdownMenuItem(
                              value: 'code128',
                              child: Text('Code 128'),
                            ),
                            DropdownMenuItem(
                              value: 'code39',
                              child: Text('Code 39'),
                            ),
                            DropdownMenuItem(
                              value: 'ean13',
                              child: Text('EAN-13'),
                            ),
                            DropdownMenuItem(
                              value: 'data_matrix',
                              child: Text('Data Matrix'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            final square = isDesignBarcodeSquare(value);

                            update(
                              (element) => element.copyWith(
                                width: square ? 20 : 35,
                                height: square ? 20 : 15,
                                style: {
                                  ...element.style,
                                  'show_text': square
                                      ? false
                                      : element.style['show_text'] != false,
                                },
                                data: {...element.data, 'symbology': value},
                              ),
                            );
                          },
                        ),
                      _dropdownProperty<String>(
                        key: ValueKey('qr-source-${e.id}'),
                        label: e.type == DesignElementType.qrCode
                            ? 'QR content source'
                            : 'Barcode content source',
                        value: _effectiveQrSource(e),
                        items: [
                          if (e.type == DesignElementType.qrCode &&
                              _previewIdentityType == 'student')
                            const DropdownMenuItem(
                              value: 'verification_link',
                              child: Text('Verification link (recommended)'),
                            ),
                          const DropdownMenuItem(
                            value: 'static',
                            child: Text('Static text'),
                          ),
                          const DropdownMenuItem(
                            value: 'system_field',
                            child: Text('Identity or school field'),
                          ),
                          const DropdownMenuItem(
                            value: 'multiple_fields',
                            child: Text('Multiple fields'),
                          ),
                          if (e.data['field_uuid'] is String ||
                              _availableCustomFields.isNotEmpty)
                            const DropdownMenuItem(
                              value: 'custom_field',
                              child: Text('Custom identity field'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            update(
                              (element) => element.copyWith(
                                data: _qrDataForSource(element, value),
                              ),
                            );
                          }
                        },
                      ),
                      if (_effectiveQrSource(e) == 'static')
                        _textProperty(
                          e.type == DesignElementType.qrCode
                              ? 'QR content'
                              : 'Barcode content',
                          e.data['text'] as String? ?? '',
                          (value) => update(
                            (element) => element.copyWith(
                              data: {...element.data, 'text': value},
                            ),
                          ),
                        ),
                      if (_effectiveQrSource(e) == 'system_field')
                        _dropdownProperty<String>(
                          key: ValueKey('qr-system-field-${e.id}'),
                          label: e.type == DesignElementType.qrCode
                              ? 'QR field'
                              : 'Barcode field',
                          value:
                              _availableSystemFields.containsKey(
                                e.data['field'],
                              )
                              ? e.data['field'] as String
                              : 'full_name',
                          items: _availableSystemFields.entries
                              .map(
                                (entry) => DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              update(
                                (element) => element.copyWith(
                                  data: {
                                    ...element.data,
                                    'field': value,
                                    'fallback': _systemFields[value],
                                  },
                                ),
                              );
                            }
                          },
                        ),
                      if (_effectiveQrSource(e) == 'custom_field')
                        _dropdownProperty<String>(
                          key: ValueKey('qr-custom-field-${e.id}'),
                          label: e.type == DesignElementType.qrCode
                              ? 'QR custom field'
                              : 'Barcode custom field',
                          value: e.data['field_uuid'] as String,
                          items: _qrCustomFieldItems(e),
                          onChanged: (value) {
                            final field = _availableCustomFields
                                .where((field) => field.uuid == value)
                                .firstOrNull;

                            if (field != null) {
                              update(
                                (element) => element.copyWith(
                                  data: {
                                    ...element.data,
                                    'field_uuid': field.uuid,
                                    'label': field.label,
                                    'fallback': field.label,
                                  },
                                ),
                              );
                            }
                          },
                        ),
                      if (_effectiveQrSource(e) == 'multiple_fields') ...[
                        _dropdownProperty<String>(
                          key: ValueKey('qr-format-${e.id}'),
                          label: 'Payload format',
                          value: e.data['format'] as String? ?? 'json',
                          items: const [
                            DropdownMenuItem(
                              value: 'json',
                              child: Text('Structured JSON'),
                            ),
                            DropdownMenuItem(
                              value: 'labeled_text',
                              child: Text('Labeled text'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              update(
                                (element) => element.copyWith(
                                  data: {
                                    ...element.data,
                                    'format': value,
                                    if (value == 'json') ...{
                                      'prefix': '',
                                      'suffix': '',
                                    },
                                  },
                                ),
                              );
                            }
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 4),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Fields',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${_qrFields(e).length}/20',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          e.data['format'] == 'labeled_text'
                              ? 'Each selected value is encoded as a labeled line.'
                              : 'System keys stay stable; custom keys use custom:<field UUID>.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        for (final group in _qrSystemFieldGroups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 14, bottom: 2),
                            child: Text(
                              group.key,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          for (final fieldKey in group.value.where(
                            _availableSystemFields.containsKey,
                          ))
                            CheckboxListTile(
                              key: Key('qr-field-$fieldKey'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                _systemFields[fieldKey]!,
                                style: const TextStyle(fontSize: 13),
                              ),
                              value: _hasQrField(e, field: fieldKey),
                              onChanged:
                                  (_hasQrField(e, field: fieldKey) &&
                                          _qrFields(e).length == 1) ||
                                      (!_hasQrField(e, field: fieldKey) &&
                                          _qrFields(e).length >= 20)
                                  ? null
                                  : (selected) => update(
                                      (element) => element.copyWith(
                                        data: _toggleQrField(
                                          element,
                                          field: fieldKey,
                                          label: _systemFields[fieldKey]!,
                                          selected: selected ?? false,
                                        ),
                                      ),
                                    ),
                            ),
                        ],
                        if (_availableCustomFields.isNotEmpty) ...[
                          const Divider(height: 24),
                          const Text(
                            'Custom identity fields',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          for (final field in _availableCustomFields)
                            CheckboxListTile(
                              key: Key('qr-custom-field-${field.uuid}'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                field.label,
                                style: const TextStyle(fontSize: 13),
                              ),
                              value: _hasQrField(e, fieldUuid: field.uuid),
                              onChanged:
                                  (_hasQrField(e, fieldUuid: field.uuid) &&
                                          _qrFields(e).length == 1) ||
                                      (!_hasQrField(e, fieldUuid: field.uuid) &&
                                          _qrFields(e).length >= 20)
                                  ? null
                                  : (selected) => update(
                                      (element) => element.copyWith(
                                        data: _toggleQrField(
                                          element,
                                          fieldUuid: field.uuid,
                                          label: field.label,
                                          selected: selected ?? false,
                                        ),
                                      ),
                                    ),
                            ),
                        ],
                      ],
                      if (_effectiveQrSource(e) != 'verification_link' &&
                          (_effectiveQrSource(e) != 'multiple_fields' ||
                              e.data['format'] == 'labeled_text')) ...[
                        _textProperty(
                          e.type == DesignElementType.qrCode
                              ? 'QR prefix'
                              : 'Barcode prefix',
                          e.data['prefix'] as String? ?? '',
                          (value) => update(
                            (element) => element.copyWith(
                              data: {...element.data, 'prefix': value},
                            ),
                          ),
                        ),
                        _textProperty(
                          e.type == DesignElementType.qrCode
                              ? 'QR suffix'
                              : 'Barcode suffix',
                          e.data['suffix'] as String? ?? '',
                          (value) => update(
                            (element) => element.copyWith(
                              data: {...element.data, 'suffix': value},
                            ),
                          ),
                        ),
                      ],
                      if (e.type == DesignElementType.qrCode)
                        _dropdownProperty<String>(
                          key: ValueKey('qr-correction-${e.id}'),
                          label: 'Error correction',
                          value:
                              e.style['error_correction'] as String? ??
                              'medium',
                          items: const [
                            DropdownMenuItem(
                              value: 'low',
                              child: Text('Low · 7%'),
                            ),
                            DropdownMenuItem(
                              value: 'medium',
                              child: Text('Medium · 15%'),
                            ),
                            DropdownMenuItem(
                              value: 'quartile',
                              child: Text('Quartile · 25%'),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text('High · 30%'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              update(
                                (element) => element.copyWith(
                                  style: {
                                    ...element.style,
                                    'error_correction': value,
                                  },
                                ),
                              );
                            }
                          },
                        ),
                      _colourProperty(
                        e.type == DesignElementType.qrCode
                            ? 'QR foreground'
                            : 'Barcode foreground',
                        e.style['color'] as String? ?? '#000000',
                        (value) {
                          if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
                            update(
                              (element) => element.copyWith(
                                style: {
                                  ...element.style,
                                  'color': value.toUpperCase(),
                                },
                              ),
                            );
                          }
                        },
                      ),
                      _colourProperty(
                        e.type == DesignElementType.qrCode
                            ? 'QR background'
                            : 'Barcode background',
                        e.style['background_color'] as String? ?? '#FFFFFF',
                        (value) {
                          if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
                            update(
                              (element) => element.copyWith(
                                style: {
                                  ...element.style,
                                  'background_color': value.toUpperCase(),
                                },
                              ),
                            );
                          }
                        },
                      ),
                      _numberField(
                        'Quiet zone (mm)',
                        (e.style['quiet_zone'] as num?)?.toDouble() ?? 1,
                        (value) => update(
                          (element) => element.copyWith(
                            style: {
                              ...element.style,
                              'quiet_zone': value.clamp(0, 5),
                            },
                          ),
                        ),
                        wide: true,
                      ),
                      if (e.type == DesignElementType.barcode &&
                          !isDesignBarcodeSquare(
                            e.data['symbology'] as String? ?? 'code128',
                          )) ...[
                        SwitchListTile(
                          key: const Key('barcode-show-text'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Show human-readable value',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          value: e.style['show_text'] != false,
                          onChanged: (value) => update(
                            (element) => element.copyWith(
                              style: {...element.style, 'show_text': value},
                            ),
                          ),
                        ),
                        if (e.style['show_text'] != false)
                          _numberField(
                            'Value text size (mm)',
                            (e.style['font_size'] as num?)?.toDouble() ?? 2.5,
                            (value) => update(
                              (element) => element.copyWith(
                                style: {
                                  ...element.style,
                                  'font_size': value.clamp(1, 6),
                                },
                              ),
                            ),
                            wide: true,
                          ),
                      ],
                    ],
                    if ({
                      DesignElementType.text,
                      DesignElementType.boundText,
                      DesignElementType.customFieldText,
                    }.contains(e.type)) ...[
                      _inspectorSectionHeader(
                        icon: Icons.format_size_rounded,
                        title: 'Typography',
                        description: 'Font size, weight, alignment and colour',
                      ),
                      _numberField(
                        'Font size (mm)',
                        (e.style['font_size'] as num?)?.toDouble() ?? 3,
                        (value) => update(
                          (element) => element.copyWith(
                            style: {
                              ...element.style,
                              'font_size': value.clamp(1, 20),
                            },
                          ),
                        ),
                        wide: true,
                      ),
                      _dropdownProperty<int>(
                        key: ValueKey('font-weight-${e.id}'),
                        label: 'Weight',
                        value: (e.style['font_weight'] as num?)?.toInt() ?? 400,
                        items: const [
                          DropdownMenuItem(value: 400, child: Text('Regular')),
                          DropdownMenuItem(
                            value: 600,
                            child: Text('Semi-bold'),
                          ),
                          DropdownMenuItem(value: 700, child: Text('Bold')),
                          DropdownMenuItem(value: 900, child: Text('Black')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            update(
                              (element) => element.copyWith(
                                style: {...element.style, 'font_weight': value},
                              ),
                            );
                          }
                        },
                      ),
                      _dropdownProperty<String>(
                        key: ValueKey('alignment-${e.id}'),
                        label: 'Alignment',
                        value: e.style['alignment'] as String? ?? 'left',
                        items: const [
                          DropdownMenuItem(value: 'left', child: Text('Left')),
                          DropdownMenuItem(
                            value: 'center',
                            child: Text('Center'),
                          ),
                          DropdownMenuItem(
                            value: 'right',
                            child: Text('Right'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            update(
                              (element) => element.copyWith(
                                style: {...element.style, 'alignment': value},
                              ),
                            );
                          }
                        },
                      ),
                      _colourProperty(
                        'Text colour (hex)',
                        e.style['color'] as String? ?? '#111111',
                        (value) {
                          if (isDesignerHex(value)) {
                            update(
                              (element) => element.copyWith(
                                style: {
                                  ...element.style,
                                  'color': value.toUpperCase(),
                                },
                              ),
                            );
                          }
                        },
                      ),
                    ],
                    if (e.type == DesignElementType.studentPhoto ||
                        e.type == DesignElementType.schoolLogo ||
                        e.type == DesignElementType.principalSignature) ...[
                      _inspectorSectionHeader(
                        icon: e.type == DesignElementType.studentPhoto
                            ? Icons.person_outline_rounded
                            : Icons.school_outlined,
                        title: e.type == DesignElementType.studentPhoto
                            ? 'Photo'
                            : e.type == DesignElementType.principalSignature
                            ? 'Principal signature'
                            : 'School logo',
                        description: 'Image scaling and presentation',
                      ),
                      _dropdownProperty<String>(
                        key: ValueKey('image-fit-${e.id}'),
                        label: 'Image fit',
                        value:
                            e.style['fit'] as String? ??
                            (e.type == DesignElementType.studentPhoto
                                ? 'cover'
                                : 'contain'),
                        items: const [
                          DropdownMenuItem(
                            value: 'cover',
                            child: Text('Cover'),
                          ),
                          DropdownMenuItem(
                            value: 'contain',
                            child: Text('Contain'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            update(
                              (element) => element.copyWith(
                                style: {...element.style, 'fit': value},
                              ),
                            );
                          }
                        },
                      ),
                    ],
                    if ({
                      DesignElementType.studentPhoto,
                      DesignElementType.schoolLogo,
                      DesignElementType.principalSignature,
                      DesignElementType.rectangle,
                      DesignElementType.roundedRectangle,
                      DesignElementType.ellipse,
                      DesignElementType.circle,
                      DesignElementType.triangle,
                      DesignElementType.bloodDrop,
                    }.contains(e.type)) ...[
                      _inspectorSectionHeader(
                        icon: Icons.palette_outlined,
                        title: 'Appearance',
                        description: 'Border, radius and visual styling',
                      ),
                      if (e.type == DesignElementType.studentPhoto ||
                          e.type == DesignElementType.schoolLogo ||
                          e.type == DesignElementType.principalSignature)
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'image-shape-field-${e.id}-${e.style['image_shape']}',
                          ),
                          initialValue:
                              e.style['image_shape'] as String? ??
                              ((e.style['corner_radius'] as num? ?? 0) > 0
                                  ? 'rounded'
                                  : 'rectangle'),
                          decoration: const InputDecoration(
                            labelText: 'Image shape',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'rectangle',
                              child: Text('Rectangle'),
                            ),
                            DropdownMenuItem(
                              value: 'rounded',
                              child: Text('Rounded'),
                            ),
                            DropdownMenuItem(
                              value: 'oval',
                              child: Text('Oval'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null)
                              update(
                                (element) => element.copyWith(
                                  style: {
                                    ...element.style,
                                    'image_shape': value,
                                    if (value == 'rounded' &&
                                        ((element.style['corner_radius']
                                                        as num?)
                                                    ?.toDouble() ??
                                                0) ==
                                            0)
                                      'corner_radius': 3.0,
                                  },
                                ),
                              );
                          },
                        ),
                      _colourProperty(
                        'Border colour (hex)',
                        e.style['border_color'] as String? ?? '#000000',
                        (value) {
                          if (isDesignerHex(value)) {
                            update(
                              (element) => element.copyWith(
                                style: {
                                  ...element.style,
                                  'border_color': value.toUpperCase(),
                                  if (((element.style['border_width'] as num?)
                                              ?.toDouble() ??
                                          0) <=
                                      0)
                                    'border_width':
                                        _previousBorderWidths[_borderWidthKey(
                                          element.id,
                                        )] ??
                                        .5,
                                },
                              ),
                            );
                          }
                        },
                        allowNone: true,
                        noneSelected:
                            ((e.style['border_width'] as num?)?.toDouble() ??
                                0) ==
                            0,
                        onNone: () => update((element) {
                          final width =
                              (element.style['border_width'] as num?)
                                  ?.toDouble() ??
                              0;
                          if (width > 0)
                            _previousBorderWidths[_borderWidthKey(element.id)] =
                                width;
                          return element.copyWith(
                            style: {...element.style, 'border_width': 0.0},
                          );
                        }),
                      ),
                      _numberField(
                        'Border width',
                        (e.style['border_width'] as num?)?.toDouble() ?? 0,
                        (value) => update((element) {
                          final width = value.clamp(0, 10).toDouble();
                          if (width > 0)
                            _previousBorderWidths[_borderWidthKey(element.id)] =
                                width;
                          return element.copyWith(
                            style: {...element.style, 'border_width': width},
                          );
                        }),
                        wide: true,
                      ),
                      _numberField(
                        'Corner radius',
                        (e.style['corner_radius'] as num?)?.toDouble() ?? 0,
                        (value) => update(
                          (element) => element.copyWith(
                            style: {
                              ...element.style,
                              'corner_radius': value.clamp(0, 30),
                            },
                          ),
                        ),
                        wide: true,
                      ),
                    ],
                    if ({
                      DesignElementType.rectangle,
                      DesignElementType.roundedRectangle,
                      DesignElementType.ellipse,
                      DesignElementType.circle,
                      DesignElementType.triangle,
                      DesignElementType.bloodDrop,
                    }.contains(e.type))
                      _colourProperty(
                        'Fill colour (hex)',
                        e.style['fill_color'] as String? ?? '#FFFFFF',
                        (value) {
                          if (isDesignerHex(value)) {
                            update(
                              (element) => element.copyWith(
                                style: {
                                  ...element.style,
                                  'fill_color': value.toUpperCase(),
                                },
                              ),
                            );
                          }
                        },
                      ),
                    if (e.type == DesignElementType.line) ...[
                      _inspectorSectionHeader(
                        icon: Icons.horizontal_rule_rounded,
                        title: 'Line appearance',
                        description: 'Colour and stroke width',
                      ),
                      _colourProperty(
                        'Line colour (hex)',
                        e.style['color'] as String? ?? '#000000',
                        (value) {
                          if (isDesignerHex(value)) {
                            update(
                              (element) => element.copyWith(
                                style: {
                                  ...element.style,
                                  'color': value.toUpperCase(),
                                },
                              ),
                            );
                          }
                        },
                      ),
                      _numberField(
                        'Line width',
                        (e.style['border_width'] as num?)?.toDouble() ?? .5,
                        (value) => update(
                          (element) => element.copyWith(
                            style: {
                              ...element.style,
                              'border_width': value.clamp(.1, 10),
                            },
                          ),
                        ),
                        wide: true,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inspectorSectionHeader({
    required IconData icon,
    required String title,
    String? description,
  }) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.accent),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 1),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.3,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: AppColors.border, height: 1)),
      ],
    ),
  );

  List<Widget> _canvasProperties() => [
    _dropdownProperty<String>(
      key: const ValueKey('canvas-preset'),
      label: 'Preset',
      value: _isCr80 ? 'cr80' : 'custom',
      items: const [
        DropdownMenuItem(
          value: 'cr80',
          child: Text('CR80 / ID-1 — 85.60 × 53.98 mm'),
        ),
        DropdownMenuItem(value: 'custom', child: Text('Custom')),
      ],
      onChanged: (value) {
        if (value == 'cr80') {
          _setCr80Preset();
        }
      },
    ),

    Row(
      children: [
        Expanded(
          child: _canvasDimensionField(
            key: const Key('canvas-width'),
            label: 'Width (mm)',
            controller: _canvasWidth,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _canvasDimensionField(
            key: const Key('canvas-height'),
            label: 'Height (mm)',
            controller: _canvasHeight,
          ),
        ),
      ],
    ),

    _dropdownProperty<String>(
      key: ValueKey('canvas-orientation-${_document.canvas.orientation}'),
      label: 'Orientation',
      value: _document.canvas.orientation,
      items: const [
        DropdownMenuItem(
          value: 'landscape',
          child: Row(
            children: [
              Icon(Icons.crop_landscape_outlined, size: 18),
              SizedBox(width: 8),
              Text('Landscape'),
            ],
          ),
        ),
        DropdownMenuItem(
          value: 'portrait',
          child: Row(
            children: [
              Icon(Icons.crop_portrait_outlined, size: 18),
              SizedBox(width: 8),
              Text('Portrait'),
            ],
          ),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          _setCanvasOrientation(value);
        }
      },
    ),

    _propertyControl(
      DesignerColourField(
        fieldKey: const Key('canvas-background-color'),
        ownerId: null,
        value: _document.canvas.backgroundColor,
        recentColours: _recentColours,
        decoration: _propertyDecoration('Background colour'),
        onChanged: (value) {
          if (isDesignerHex(value)) {
            _rememberColour(value);

            _updateUi(() {
              _canvasError = null;
            });

            _commit(
              _document.copyWith(
                canvas: _document.canvas.copyWith(
                  backgroundColor: value.toUpperCase(),
                ),
              ),
            );
          }
        },
      ),
    ),

    if (_canvasError != null)
      Container(
        key: const Key('canvas-validation-error'),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withValues(alpha: .25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: AppColors.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _canvasError!,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      ),

    Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppColors.surfaceSoft,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              dense: true,
              title: const Text(
                'Grid enabled',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              secondary: const Icon(Icons.grid_4x4_rounded, size: 18),
              value: _document.settings['grid_enabled'] != false,
              onChanged: (value) => _commit(
                _document.copyWith(
                  settings: {..._document.settings, 'grid_enabled': value},
                ),
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              dense: true,
              title: const Text(
                'Snap enabled',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              secondary: const Icon(Icons.control_camera_outlined, size: 18),
              value: _document.settings['snap_enabled'] != false,
              onChanged: (value) => _commit(
                _document.copyWith(
                  settings: {..._document.settings, 'snap_enabled': value},
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    _numberField(
      'Grid size (mm)',
      (_document.settings['grid_size'] as num?)?.toDouble() ?? 2,
      (value) {
        if (!value.isFinite || value <= 0 || value > 200) {
          _updateUi(() {
            _canvasError = 'Grid size must be between 0 and 200 mm.';
          });

          return;
        }

        _updateUi(() {
          _canvasError = null;
        });

        _commit(
          _document.copyWith(
            settings: {..._document.settings, 'grid_size': value},
          ),
        );
      },
      wide: true,
    ),

    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.info.withValues(alpha: .18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 17, color: AppColors.info),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'When the canvas size changes, choose whether to keep, scale, or fit existing elements.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    ),
  ];

  Widget _canvasDimensionField({
    required Key key,
    required String label,
    required TextEditingController controller,
  }) => _propertyControl(
    DesignerNumericField(
      fieldKey: key,
      ownerId: null,
      value: key == const Key('canvas-width')
          ? _document.canvas.width
          : _document.canvas.height,
      decoration: _propertyDecoration(label),
      onChanged: (value) {
        controller.text = value.toString();

        _applyCanvasDimensions();
      },
    ),
  );

  InputDecoration _propertyDecoration(String label) => InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
    ),
  );

  Widget _propertyControl(Widget child) =>
      Padding(padding: const EdgeInsets.only(bottom: 16), child: child);

  Widget _dropdownProperty<T>({
    required Key key,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) => _propertyControl(
    KeyedSubtree(
      key: key,
      child: DropdownButtonFormField<T>(
        key: ValueKey(value),
        initialValue: value,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        decoration: _propertyDecoration(label),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );

  Widget _numberField(
    String label,
    double value,
    ValueChanged<double> apply, {
    bool wide = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: SizedBox(
      width: wide ? double.infinity : 118,
      child: DesignerNumericField(
        fieldKey: Key('property-${label.toLowerCase().replaceAll(' ', '-')}'),
        ownerId: _selectedId,
        value: value,
        decoration: _propertyDecoration(label),
        onChanged: apply,
        normalStep: label == 'Rotation' ? 1 : .1,
        largeStep: label == 'Rotation' ? 10 : 1,
      ),
    ),
  );

  void _rememberColour(String value) {
    _recentColours.remove(value);

    _recentColours.insert(0, value);

    if (_recentColours.length > 12) {
      _recentColours.removeLast();
    }
  }

  Widget _colourProperty(
    String label,
    String value,
    ValueChanged<String> apply, {
    bool allowNone = false,
    bool noneSelected = false,
    VoidCallback? onNone,
  }) => _propertyControl(
    DesignerColourField(
      fieldKey: Key('property-${label.toLowerCase().replaceAll(' ', '-')}'),
      ownerId: _selectedId,
      value: value,
      decoration: _propertyDecoration(label),
      recentColours: _recentColours,
      allowNone: allowNone,
      noneSelected: noneSelected,
      onNone: onNone,
      onChanged: (colour) {
        _rememberColour(colour);

        apply(colour);
      },
    ),
  );

  Widget _textProperty(
    String label,
    String value,
    ValueChanged<String> apply,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: _ModelTextProperty(
      fieldKey: Key('property-${label.toLowerCase().replaceAll(' ', '-')}'),
      ownerId: _selectedId,
      value: value,
      decoration: _propertyDecoration(label),
      onChanged: apply,
    ),
  );
}

// Controllers hold editing drafts only.
// Committed values always come from the document,
// including selection changes, gestures, and undo/redo.
class _ModelTextProperty extends StatefulWidget {
  const _ModelTextProperty({
    required this.fieldKey,
    required this.ownerId,
    required this.value,
    required this.decoration,
    this.onChanged,
  });

  final Key fieldKey;
  final String? ownerId;
  final String value;
  final InputDecoration decoration;
  final ValueChanged<String>? onChanged;

  @override
  State<_ModelTextProperty> createState() => _ModelTextPropertyState();
}

class _ModelTextPropertyState extends State<_ModelTextProperty> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.value);
  }

  void _sync() {
    if (_controller.text == widget.value) {
      return;
    }

    _controller.value = TextEditingValue(
      text: widget.value,
      selection: TextSelection.collapsed(offset: widget.value.length),
    );
  }

  @override
  void didUpdateWidget(covariant _ModelTextProperty oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.ownerId != widget.ownerId ||
        oldWidget.fieldKey != widget.fieldKey ||
        oldWidget.value != widget.value) {
      _sync();
    }
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    key: widget.fieldKey,
    controller: _controller,
    decoration: widget.decoration,
    onChanged: widget.onChanged,
  );
}

const _systemFields = <String, String>{
  'full_name': 'Full name',
  'id_number': 'ID / employee number',
  'employee_number': 'Employee number',
  'employee_no': 'Employee number (legacy API key)',
  'designation': 'Designation',
  'department': 'Department',
  'email': 'Email',
  'personnel_type': 'Personnel type',
  'admission_no': 'Admission number',
  'roll_no': 'Roll number',
  'stream': 'Stream',
  'father_name': "Father's name",
  'mother_name': "Mother's name",
  'dob': 'Date of birth',
  'gender': 'Gender',
  'blood_group': 'Blood group',
  'mobile': 'Mobile',
  'aadhaar': 'Aadhaar',
  'address': 'Address',
  'session': 'Session',
  'class': 'Class',
  'section': 'Section',
  'school_name': 'School name',
  'school_address': 'School address',
  'school_code': 'School code',
  'school_phone': 'School phone',
  'school_email': 'School email',
  'school_website': 'School website',
  'school_city': 'School city',
  'school_district': 'School district',
  'school_state': 'School state',
  'school_country': 'School country',
  'school_postal_code': 'School postal code',
  'principal_name': 'Principal name',
};

const _qrSystemFieldGroups = <String, List<String>>{
  'Identity fields': [
    'full_name',
    'id_number',
    'designation',
    'department',
    'personnel_type',
    'email',
  ],
  'Student fields': [
    'admission_no',
    'roll_no',
    'stream',
    'father_name',
    'mother_name',
    'dob',
    'gender',
    'blood_group',
    'mobile',
    'aadhaar',
    'address',
  ],
  'Academic fields': ['session', 'class', 'section'],
  'School fields': [
    'school_name',
    'school_address',
    'school_code',
    'school_phone',
    'school_email',
    'school_website',
    'school_city',
    'school_district',
    'school_state',
    'school_country',
    'school_postal_code',
    'principal_name',
  ],
};

class _GridPainter extends CustomPainter {
  const _GridPainter(this.gridMm, this.canvasWidthMm);

  final double gridMm;
  final double canvasWidthMm;

  @override
  void paint(Canvas canvas, Size size) {
    final step = gridMm * size.width / canvasWidthMm;

    if (step < 4) {
      return;
    }

    final paint = Paint()
      ..color = const Color(0x18000000)
      ..strokeWidth = .5;

    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.gridMm != gridMm ||
      oldDelegate.canvasWidthMm != canvasWidthMm;
}

// Cache each section by the state it actually displays.
// Geometry updates do not rebuild app chrome, toolbar, or layers;
// no element model is cached here.
class _DesignerSection extends StatefulWidget {
  const _DesignerSection({
    required this.revision,
    required this.select,
    required this.builder,
  });

  final ValueListenable<int> revision;
  final Object? Function() select;
  final Widget Function() builder;

  @override
  State<_DesignerSection> createState() => _DesignerSectionState();
}

class _DesignerSectionState extends State<_DesignerSection> {
  Object? _signature;

  @override
  void initState() {
    super.initState();

    _signature = widget.select();

    widget.revision.addListener(_changed);
  }

  void _changed() {
    final next = widget.select();

    final unchanged = next is List && _signature is List
        ? listEquals(next, _signature as List)
        : next == _signature;

    if (!unchanged) {
      setState(() {
        _signature = next;
      });
    }
  }

  @override
  void didUpdateWidget(covariant _DesignerSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.revision != widget.revision) {
      oldWidget.revision.removeListener(_changed);

      widget.revision.addListener(_changed);
    }

    _signature = widget.select();
  }

  @override
  void dispose() {
    widget.revision.removeListener(_changed);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: widget.builder());
}

class _DesignerSnapshot {
  const _DesignerSnapshot(this.template, this.selectedId, this.localDuplicate);

  final CardTemplate template;
  final String? selectedId;
  final bool localDuplicate;
}

enum _TemplateAction { duplicate, revert, reset, removeBack }

enum _LeaveAction { cancel, discard, save }
