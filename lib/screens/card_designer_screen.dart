// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../widgets/designer_numeric_field.dart';
import '../widgets/designer_shortcuts.dart';
import '../widgets/designer_guides.dart';
import '../widgets/designer_colour_field.dart';

import '../models/api_student.dart';
import '../models/card_template.dart';
import '../models/school_profile.dart';
import '../models/student_field.dart';
import '../services/api_service.dart';
import '../widgets/authenticated_app_bar.dart';
import '../widgets/design_document_view.dart';

class CardDesignerScreen extends StatefulWidget {
  const CardDesignerScreen({
    super.key,
    required this.schoolUuid,
    required this.api,
    required this.initialTemplate,
  });
  // Logical pixels; shared by the entry warning and editor layout.
  static const minimumEditorWidth = 600.0;
  static const recommendedEditorWidth = 1050.0;
  static const recommendedEditorHeight = 600.0;
  static const smallScreenMessage =
      'Card Designer works best on a larger screen. Please open this page on a desktop or larger display for easier editing.';

  final String schoolUuid;
  final ApiService api;
  final CardTemplate initialTemplate;
  @override
  State<CardDesignerScreen> createState() => _CardDesignerScreenState();
}

class _CardDesignerScreenState extends State<CardDesignerScreen> {
  late CardTemplate _template;
  late final TextEditingController _name;
  late final TextEditingController _canvasWidth;
  late final TextEditingController _canvasHeight;
  late final TextEditingController _canvasBackground;
  final TransformationController _viewTransform = TransformationController();
  final FocusNode _canvasFocus = FocusNode(debugLabel: 'designer canvas');
  final List<_DesignerSnapshot> _history = [];
  final _canvasCoordinates = GlobalKey();
  final _guides = ValueNotifier<List<DesignerGuide>>([]);
  final List<String> _recentColours = [];
  final ValueNotifier<int> _revision = ValueNotifier(0);
  CardTemplate? _gestureStart;
  String? _gestureId;
  Offset _gestureRemainder = Offset.zero;
  bool _syncingName = false;
  bool _smallScreenAccepted = false;
  bool _dirtyValue = false;
  late CardTemplate _savedTemplate;
  int _historyIndex = 0;
  String? _selectedId, _logoUrl;
  SchoolProfile? _schoolProfile;
  List<StudentFieldDefinition> _customFields = const [];
  double _zoom = 1;
  bool _saving = false;
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
    isActive: true,
  );

  DesignDocument get _document => _template.document;
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
    _template = widget.initialTemplate;
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
    _history.add(_DesignerSnapshot(_template, _selectedId));
    _savedTemplate = _template;
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
      ]);
      if (!mounted) return;
      _updateUi(() {
        _customFields = results[0] as List<StudentFieldDefinition>;
        _schoolProfile = results[1] as SchoolProfile?;
        _logoUrl = _schoolProfile?.logoUrl;
      });
    } catch (_) {
      /* The editor remains usable when optional metadata is unavailable. */
    }
  }

  @override
  void dispose() {
    _name.removeListener(_rename);
    _name.dispose();
    _canvasWidth.dispose();
    _canvasHeight.dispose();
    _canvasBackground.dispose();
    _canvasFocus.dispose();
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
    if (!_syncingName) _commitTemplate(_template.copyWith(name: _name.text));
  }

  void _select(String? id) {
    _canvasFocus.requestFocus();
    if (_selectedId == id) return;
    _endGesture();
    _updateUi(() {
      _selectedId = id;
      _history[_historyIndex] = _DesignerSnapshot(_template, id);
    });
  }

  void _applyCanvasDimensions() {
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
        _canvasError = 'Width and height must be between 10 and 2000 mm.';
      });
      return;
    }
    _updateUi(() => _canvasError = null);
    _commit(
      _document.copyWith(
        canvas: _document.canvas.copyWith(width: width, height: height),
      ),
    );
  }

  void _setCanvasOrientation(String orientation) {
    final canvas = _document.canvas;
    if (orientation == canvas.orientation) return;
    final next = canvas.copyWith(width: canvas.height, height: canvas.width);
    _canvasWidth.text = next.width.toStringAsFixed(2);
    _canvasHeight.text = next.height.toStringAsFixed(2);
    _updateUi(() => _canvasError = null);
    _commit(_document.copyWith(canvas: next));
  }

  void _setCr80Preset() {
    _canvasWidth.text = '85.60';
    _canvasHeight.text = '53.98';
    _updateUi(() => _canvasError = null);
    _commit(
      _document.copyWith(
        canvas: _document.canvas.copyWith(width: 85.6, height: 53.98),
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

  bool _sameTemplate(CardTemplate a, CardTemplate b) =>
      identical(a, b) ||
      (a.name == b.name && _sameDocument(a.document, b.document));

  bool _sameDocument(DesignDocument a, DesignDocument b) =>
      identical(a, b) ||
      (mapEquals(a.canvas.toJson(), b.canvas.toJson()) &&
          mapEquals(a.settings, b.settings) &&
          a.elements.length == b.elements.length &&
          Iterable<int>.generate(a.elements.length).every(
            (i) =>
                identical(a.elements[i], b.elements[i]) ||
                _sameElement(a.elements[i], b.elements[i]),
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
      mapEquals(a.style, b.style) &&
      mapEquals(a.data, b.data);

  void _record(CardTemplate next) {
    _history.removeRange(_historyIndex + 1, _history.length);
    _history.add(_DesignerSnapshot(next, _selectedId));
    if (_history.length > 80) _history.removeAt(0);
    _historyIndex = _history.length - 1;
  }

  void _commit(
    DesignDocument next, {
    String? selectedId,
    bool gestureUpdate = false,
  }) => _commitTemplate(
    _template.copyWith(document: next),
    selectedId: selectedId,
    gestureUpdate: gestureUpdate,
  );

  void _commitTemplate(
    CardTemplate next, {
    String? selectedId,
    bool gestureUpdate = false,
  }) {
    if (!gestureUpdate) _endGesture();
    if (_sameTemplate(next, _template)) return;
    _updateUi(() {
      _template = next;
      if (selectedId != null) _selectedId = selectedId;
      if (_selected == null) _selectedId = null;
      if (_gestureStart == null) _record(next);
      // Avoid full-document serialization/comparison for every pointer event.
      _dirtyValue =
          _gestureStart != null || !_sameTemplate(next, _savedTemplate);
      _saveState = _dirty ? 'Unsaved changes' : 'Saved';
    });
  }

  void _beginGesture(String id) {
    _endGesture();
    _gestureStart = _template;
    _gestureId = id;
    _gestureRemainder = Offset.zero;
  }

  void _endGesture() {
    if (_guides.value.isNotEmpty) _guides.value = [];
    final start = _gestureStart;
    if (start == null) return;
    _updateUi(() {
      _gestureStart = null;
      _gestureId = null;
      _gestureRemainder = Offset.zero;
      if (!_sameTemplate(start, _template)) _record(_template);
      _dirtyValue = !_sameTemplate(_template, _savedTemplate);
      _saveState = _dirty ? 'Unsaved changes' : 'Saved';
    });
  }

  void _restore(int index) {
    _updateUi(() {
      _historyIndex = index;
      _template = _history[index].template;
      _selectedId = _history[index].selectedId;
      _syncingName = true;
      _name.text = _template.name;
      _syncingName = false;
      _syncCanvasControllers();
      _canvasError = null;
      _dirtyValue = !_sameTemplate(_template, _savedTemplate);
      _saveState = _dirty ? 'Unsaved changes' : 'Saved';
    });
  }

  void _undo() {
    _endGesture();
    if (_canUndo) _restore(_historyIndex - 1);
  }

  void _redo() {
    _endGesture();
    if (_canRedo) _restore(_historyIndex + 1);
  }

  void _updateElement(
    String id,
    DesignElement Function(DesignElement) change, {
    bool gestureUpdate = false,
  }) {
    final live = _document.elements.where((e) => e.id == id).firstOrNull;
    if (live != null) _replace(change(live), gestureUpdate: gestureUpdate);
  }

  void _replace(DesignElement replacement, {bool gestureUpdate = false}) =>
      _commit(
        _document.copyWith(
          elements: [
            for (final element in _document.elements)
              if (element.id == replacement.id) replacement else element,
          ],
        ),
        gestureUpdate: gestureUpdate,
      );

  void _add(DesignElementType type, {StudentFieldDefinition? customField}) {
    final id =
        '${type.wire}-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
    final z = _document.elements.fold<int>(
      0,
      (value, element) => math.max(value, element.zIndex + 1),
    );
    final isImage =
        type == DesignElementType.studentPhoto ||
        type == DesignElementType.schoolLogo;
    final element = DesignElement(
      id: id,
      type: type,
      x: (_document.canvas.width - (isImage ? 20 : 30)) / 2,
      y: (_document.canvas.height - (isImage ? 22 : 6)) / 2,
      width: isImage ? 20 : 30,
      height: isImage
          ? 22
          : type == DesignElementType.line
          ? 1
          : 6,
      zIndex: z,
      style: switch (type) {
        DesignElementType.rectangle => {
          'fill_color': '#E8EEF8',
          'border_color': '#242C61',
          'border_width': 0.5,
          'corner_radius': 1.0,
        },
        DesignElementType.line => {'color': '#242C61', 'border_width': 0.5},
        DesignElementType.studentPhoto || DesignElementType.schoolLogo => {
          'fit': type == DesignElementType.schoolLogo ? 'contain' : 'cover',
          'border_color': '#242C61',
          'border_width': 0.5,
          'corner_radius': 1.0,
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
          'fallback': 'Student name',
        },
        DesignElementType.customFieldText => {
          'field_uuid': customField!.uuid,
          'label': customField.label,
          'fallback': customField.label,
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
    if (!dx.isFinite || !dy.isFinite) return;
    _updateElement(id, (element) {
      if (element.locked) return element;
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
      if (_gestureId == id) _gestureRemainder = Offset(rawX - x, rawY - y);
      final next = element.copyWith(x: x, y: y);
      _updateGuides(next);
      return next;
    }, gestureUpdate: true);
  }

  void _resize(String id, double dw, double dh) {
    if (!dw.isFinite || !dh.isFinite) return;
    _updateElement(id, (element) {
      if (element.locked) return element;
      final maxW = math.max(2.0, _document.canvas.width - element.x);
      final maxH = math.max(1.0, _document.canvas.height - element.y);
      var width = (element.width + dw).clamp(2.0, maxW);
      var height = (element.height + dh).clamp(1.0, maxH);
      if (element.type == DesignElementType.studentPhoto ||
          element.type == DesignElementType.schoolLogo) {
        final ratio = element.width / element.height;
        height = (width / ratio).clamp(1.0, maxH);
        width = (height * ratio).clamp(2.0, maxW);
      }
      final next = element.copyWith(width: width, height: height);
      _updateGuides(next);
      return next;
    }, gestureUpdate: true);
  }

  void _remove() {
    final selected = _selected;
    if (selected == null || selected.locked) return;
    _commit(
      _document.copyWith(
        elements: _document.elements.where((e) => e.id != selected.id).toList(),
      ),
    );
  }

  void _duplicate() {
    final selected = _selected;
    if (selected == null) return;
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

  int _topZ() =>
      _document.elements.fold<int>(0, (v, e) => math.max(v, e.zIndex + 1));

  void _layer(String operation) {
    final selected = _selected;
    if (selected == null) return;
    final ordered = [..._document.elements]
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    var index = ordered.indexWhere((e) => e.id == selected.id);
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
    final e = _selected;
    if (e == null || e.locked) return;
    _replace(
      e.copyWith(
        x: switch (where) {
          'left' => 0,
          'hcenter' => (_document.canvas.width - e.width) / 2,
          'right' => _document.canvas.width - e.width,
          _ => e.x,
        },
        y: switch (where) {
          'top' => 0,
          'vcenter' => (_document.canvas.height - e.height) / 2,
          'bottom' => _document.canvas.height - e.height,
          _ => e.y,
        },
      ),
    );
  }

  void _updateGuides(DesignElement next) {
    if (_gestureId != next.id) return;
    final box = _canvasCoordinates.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
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
        if (id == null) return;
        // Keyboard nudges are precise even when pointer grid snapping is on.
        _updateElement(
          id,
          (e) => e.locked
              ? e
              : e.copyWith(
                  x: (e.x + delta.dx).clamp(
                    0.0,
                    math.max(0.0, _document.canvas.width - e.width),
                  ),
                  y: (e.y + delta.dy).clamp(
                    0.0,
                    math.max(0.0, _document.canvas.height - e.height),
                  ),
                ),
        );
    }
  }

  Future<void> _save() async {
    if (!_dirty || _saving || _name.text.trim().isEmpty) return;
    _endGesture();
    _commitTemplate(_template.copyWith(name: _name.text.trim()));
    final submitted = _template;
    _updateUi(() {
      _saving = true;
      _saveState = 'Saving…';
    });
    try {
      final saved = await widget.api.saveCardTemplate(
        widget.schoolUuid,
        submitted,
      );
      if (!mounted) return;
      _updateUi(() {
        _savedTemplate = saved;
        _dirtyValue = !_sameTemplate(_template, saved);
        _saving = false;
        _saveState = _dirty ? 'Unsaved changes' : 'Saved';
      });
    } catch (error) {
      if (!mounted) return;
      _updateUi(() {
        _saving = false;
        _saveState = 'Save failed';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save template: $error')),
      );
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset card design?'),
        content: const Text(
          'This replaces the current canvas with the default template. You can still use Undo before saving.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _endGesture();
      _selectedId = null;
      _commit(CardTemplate.uploadedDesign.document);
      _syncCanvasControllers();
    }
  }

  Widget _section(Object? Function() select, Widget Function() builder) =>
      _DesignerSection(revision: _revision, select: select, builder: builder);

  Object _layerSignature() => <Object?>[
    _selectedId,
    for (final e in _document.elements)
      (e.id, e.zIndex, e.visible, e.locked, _elementLabel(e)),
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
        // A viewport change may remove a pointer target before it receives up.
        if (_gestureStart != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _endGesture();
          });
        }
        return _guardNavigation(
          Scaffold(
            appBar: const AuthenticatedAppBar(title: Text('Card designer')),
            body: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.desktop_windows_outlined, size: 42),
                      const SizedBox(height: 16),
                      const Text(
                        CardDesignerScreen.smallScreenMessage,
                        key: Key('designer-screen-warning'),
                        textAlign: TextAlign.center,
                      ),
                      if (!mobile) ...[
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () =>
                              setState(() => _smallScreenAccepted = true),
                          child: const Text('Continue anyway'),
                        ),
                      ],
                    ],
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

  Widget _guardNavigation(Widget child) => ValueListenableBuilder<int>(
    valueListenable: _revision,
    builder: (context, _, child) => PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _dirty)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Save or undo your changes before leaving.'),
            ),
          );
      },
      child: child!,
    ),
    child: child,
  );

  Widget _editor() => _guardNavigation(
    Scaffold(
      backgroundColor: const Color(0xfff3f5f9),
      appBar: AuthenticatedAppBar(
        title: const Text('Card designer'),
        actions: [
          _section(
            () => (_saveState, _saving, _dirty),
            () => Center(
              child: Text(
                _saveState,
                key: const Key('designer-save-state'),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _section(
            () => (_saveState, _saving, _dirty),
            () => TextButton.icon(
              key: const Key('designer-save'),
              onPressed: _dirty && !_saving ? _save : null,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
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
            ),
            _toolbar,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >=
                      CardDesignerScreen.recommendedEditorWidth
                  ? Row(
                      children: [
                        SizedBox(
                          width: 250,
                          child: _section(_layerSignature, _layers),
                        ),
                        Expanded(
                          child: _section(
                            () => (
                              _document,
                              _selectedId,
                              _zoom,
                              _logoUrl,
                              _schoolProfile,
                            ),
                            _workspace,
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _section(
                            () => (_template, _selectedId, _canvasError),
                            _inspector,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _section(
                            () => (
                              _document,
                              _selectedId,
                              _zoom,
                              _logoUrl,
                              _schoolProfile,
                            ),
                            _workspace,
                          ),
                        ),
                        SizedBox(
                          width: 300,
                          child: _section(
                            () => (_template, _selectedId, _canvasError),
                            _inspector,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _toolbar() => Material(
    elevation: 1,
    child: SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _tool(
            Icons.text_fields,
            'Text',
            () => _add(DesignElementType.text),
            key: 'add-text',
          ),
          _tool(
            Icons.badge_outlined,
            'Student field',
            () => _add(DesignElementType.boundText),
            key: 'add-student-field',
          ),
          PopupMenuButton<StudentFieldDefinition>(
            tooltip: 'Custom field',
            enabled: _customFields.isNotEmpty,
            onSelected: (field) =>
                _add(DesignElementType.customFieldText, customField: field),
            itemBuilder: (_) => [
              for (final field in _customFields.where((f) => f.isActive))
                PopupMenuItem(value: field, child: Text(field.label)),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.dynamic_form_outlined),
                  SizedBox(width: 6),
                  Text('Custom field'),
                ],
              ),
            ),
          ),
          _tool(
            Icons.person_outline,
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
            Icons.rectangle_outlined,
            'Rectangle',
            () => _add(DesignElementType.rectangle),
            key: 'add-rectangle',
          ),
          _tool(
            Icons.horizontal_rule,
            'Line',
            () => _add(DesignElementType.line),
            key: 'add-line',
          ),
          const VerticalDivider(),
          IconButton(
            onPressed: _canUndo ? _undo : null,
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
          ),
          IconButton(
            onPressed: _canRedo ? _redo : null,
            icon: const Icon(Icons.redo),
            tooltip: 'Redo',
          ),
          IconButton(
            onPressed: _selected == null ? null : _duplicate,
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Duplicate',
          ),
          IconButton(
            onPressed: _selected == null ? null : _remove,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
          ),
          IconButton(
            key: const Key('reset-design'),
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset to default',
          ),
          const VerticalDivider(),
          ...['left', 'hcenter', 'right', 'top', 'vcenter', 'bottom'].map(
            (value) => IconButton(
              onPressed: _selected == null ? null : () => _align(value),
              icon: Icon(switch (value) {
                'left' => Icons.align_horizontal_left,
                'hcenter' => Icons.align_horizontal_center,
                'right' => Icons.align_horizontal_right,
                'top' => Icons.align_vertical_top,
                'vcenter' => Icons.align_vertical_center,
                _ => Icons.align_vertical_bottom,
              }),
              tooltip: 'Align $value',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _tool(
    IconData icon,
    String label,
    VoidCallback onTap, {
    required String key,
  }) => TextButton.icon(
    key: Key(key),
    onPressed: onTap,
    icon: Icon(icon),
    label: Text(label),
  );

  Widget _workspace() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.zoom_out),
            Expanded(
              child: Slider(
                value: _zoom,
                min: .5,
                max: 2,
                divisions: 15,
                label: '${(_zoom * 100).round()}%',
                onChanged: (v) => _updateUi(() => _zoom = v),
              ),
            ),
            const Icon(Icons.zoom_in),
            TextButton(
              onPressed: () => _updateUi(() {
                _zoom = 1;
                _viewTransform.value = Matrix4.identity();
              }),
              child: const Text('Fit'),
            ),
          ],
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const pixelsPerMillimetre = 10.0;
            final naturalWidth = _document.canvas.width * pixelsPerMillimetre;
            final naturalHeight = _document.canvas.height * pixelsPerMillimetre;
            final fitScale = math.min(
              (constraints.maxWidth - 32).clamp(1, double.infinity) /
                  naturalWidth,
              (constraints.maxHeight - 32).clamp(1, double.infinity) /
                  naturalHeight,
            );
            final displayWidth = naturalWidth * fitScale * _zoom;
            return Focus(
              focusNode: _canvasFocus,
              child: InteractiveViewer(
                transformationController: _viewTransform,
                panEnabled: _selectedId == null,
                minScale: .5,
                maxScale: 3,
                child: Center(
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
                            student: _sampleStudent,
                            sessionName: '2026-2028',
                            className: 'XII',
                            sectionName: 'A',
                            logoUrl: _logoUrl,
                            schoolProfile: _schoolProfile,
                            assetBaseUrl: widget.api.baseUrl,
                            selectedId: _selectedId,
                            interactive: true,
                            onSelect: _select,
                            onGestureStart: _beginGesture,
                            onGestureEnd: _endGesture,
                            isGestureActive: (id) => _gestureId == id,
                            onMove: _move,
                            onResize: _resize,
                          ),
                        ),
                        Positioned.fill(
                          child: ValueListenableBuilder<List<DesignerGuide>>(
                            valueListenable: _guides,
                            builder: (context, guides, _) => guides.isEmpty
                                ? const SizedBox.shrink()
                                : DesignerGuideOverlay(
                                    key: const Key('designer-smart-guides'),
                                    guides: guides,
                                    canvasWidth: _document.canvas.width,
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
                                  (_document.settings['grid_size'] as num?)
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
            );
          },
        ),
      ),
    ],
  );

  Widget _layers() {
    final elements = [..._document.elements]
      ..sort((a, b) => b.zIndex.compareTo(a.zIndex));
    return Material(
      color: Colors.white,
      child: Column(
        children: [
          const ListTile(
            title: Text(
              'Layers',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final e in elements)
                  ListTile(
                    key: Key('layer-${e.id}'),
                    selected: e.id == _selectedId,
                    dense: true,
                    onTap: () => _select(e.id),
                    leading: IconButton(
                      tooltip: e.visible ? 'Hide' : 'Show',
                      icon: Icon(
                        e.visible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                      onPressed: () => _updateElement(
                        e.id,
                        (live) => live.copyWith(visible: !live.visible),
                      ),
                    ),
                    title: Text(
                      _elementLabel(e),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        e.locked ? Icons.lock : Icons.lock_open,
                        size: 18,
                      ),
                      onPressed: () => _updateElement(
                        e.id,
                        (live) => live.copyWith(locked: !live.locked),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Wrap(
            children: [
              IconButton(
                onPressed: _selected == null ? null : () => _layer('front'),
                icon: const Icon(Icons.vertical_align_top),
                tooltip: 'Bring to front',
              ),
              IconButton(
                onPressed: _selected == null ? null : () => _layer('forward'),
                icon: const Icon(Icons.arrow_upward),
                tooltip: 'Bring forward',
              ),
              IconButton(
                onPressed: _selected == null ? null : () => _layer('backward'),
                icon: const Icon(Icons.arrow_downward),
                tooltip: 'Send backward',
              ),
              IconButton(
                onPressed: _selected == null ? null : () => _layer('back'),
                icon: const Icon(Icons.vertical_align_bottom),
                tooltip: 'Send to back',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _elementLabel(DesignElement e) => e.type == DesignElementType.text
      ? (e.data['text'] as String? ?? 'Text')
      : e.type.wire.replaceAll('_', ' ');

  Widget _inspector() {
    final e = _selected;
    // Resolve by identity at event time; callbacks must not replace newer edits
    // with the element snapshot captured by the previous build.
    void update(DesignElement Function(DesignElement) change) {
      final live = _document.elements
          .where((element) => element.id == e?.id)
          .firstOrNull;
      if (live != null) _replace(change(live));
    }

    return Material(
      color: Colors.white,
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _propertyControl(
              TextField(
                key: const Key('template-name'),
                controller: _name,
                decoration: _propertyDecoration('Template name'),
              ),
            ),
            Text(
              e == null
                  ? 'Canvas properties'
                  : 'Properties · ${_elementLabel(e)}',
              key: Key(e == null ? 'canvas-properties' : 'element-properties'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (e == null) ..._canvasProperties(),
            if (e != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _numberField(
                    'X',
                    e.x,
                    (v) => update(
                      (e) => e.copyWith(
                        x: v.clamp(
                          0.0,
                          math.max(0.0, _document.canvas.width - e.width),
                        ),
                      ),
                    ),
                  ),
                  _numberField(
                    'Y',
                    e.y,
                    (v) => update(
                      (e) => e.copyWith(
                        y: v.clamp(
                          0.0,
                          math.max(0.0, _document.canvas.height - e.height),
                        ),
                      ),
                    ),
                  ),
                  _numberField(
                    'Width',
                    e.width,
                    (v) => update(
                      (e) => e.copyWith(
                        width: v.clamp(
                          2.0,
                          math.max(2.0, _document.canvas.width - e.x),
                        ),
                      ),
                    ),
                  ),
                  _numberField(
                    'Height',
                    e.height,
                    (v) => update(
                      (e) => e.copyWith(
                        height: v.clamp(
                          1.0,
                          math.max(1.0, _document.canvas.height - e.y),
                        ),
                      ),
                    ),
                  ),
                  _numberField(
                    'Rotation',
                    e.rotation,
                    (v) =>
                        update((e) => e.copyWith(rotation: v.clamp(-360, 360))),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Locked'),
                value: e.locked,
                onChanged: (v) => update((e) => e.copyWith(locked: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Visible'),
                value: e.visible,
                onChanged: (v) => update((e) => e.copyWith(visible: v)),
              ),
              if (e.type == DesignElementType.text)
                _textProperty(
                  'Text',
                  e.data['text'] as String? ?? '',
                  (v) =>
                      update((e) => e.copyWith(data: {...e.data, 'text': v})),
                ),
              if (e.type == DesignElementType.boundText)
                _dropdownProperty<String>(
                  key: ValueKey('student-field-${e.id}'),
                  label: 'Student field',
                  value: e.data['field'] as String? ?? 'full_name',
                  items: _systemFields.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null)
                      update(
                        (e) => e.copyWith(
                          data: {
                            ...e.data,
                            'field': v,
                            'fallback': _systemFields[v],
                          },
                        ),
                      );
                  },
                ),
              if ({
                DesignElementType.text,
                DesignElementType.boundText,
                DesignElementType.customFieldText,
              }.contains(e.type)) ...[
                _numberField(
                  'Font size (mm)',
                  (e.style['font_size'] as num?)?.toDouble() ?? 3,
                  (v) => update(
                    (e) => e.copyWith(
                      style: {...e.style, 'font_size': v.clamp(1, 20)},
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
                    DropdownMenuItem(value: 600, child: Text('Semi-bold')),
                    DropdownMenuItem(value: 700, child: Text('Bold')),
                    DropdownMenuItem(value: 900, child: Text('Black')),
                  ],
                  onChanged: (v) {
                    if (v != null)
                      update(
                        (e) =>
                            e.copyWith(style: {...e.style, 'font_weight': v}),
                      );
                  },
                ),
                _dropdownProperty<String>(
                  key: ValueKey('alignment-${e.id}'),
                  label: 'Alignment',
                  value: e.style['alignment'] as String? ?? 'left',
                  items: const [
                    DropdownMenuItem(value: 'left', child: Text('Left')),
                    DropdownMenuItem(value: 'center', child: Text('Center')),
                    DropdownMenuItem(value: 'right', child: Text('Right')),
                  ],
                  onChanged: (v) {
                    if (v != null)
                      update(
                        (e) => e.copyWith(style: {...e.style, 'alignment': v}),
                      );
                  },
                ),
                _colourProperty(
                  'Text colour (hex)',
                  e.style['color'] as String? ?? '#111111',
                  (v) {
                    if (isDesignerHex(v))
                      update(
                        (e) => e.copyWith(
                          style: {...e.style, 'color': v.toUpperCase()},
                        ),
                      );
                  },
                ),
              ],
              if (e.type == DesignElementType.studentPhoto ||
                  e.type == DesignElementType.schoolLogo)
                _dropdownProperty<String>(
                  key: ValueKey('image-fit-${e.id}'),
                  label: 'Image fit',
                  value: e.style['fit'] as String? ?? 'cover',
                  items: const [
                    DropdownMenuItem(value: 'cover', child: Text('Cover')),
                    DropdownMenuItem(value: 'contain', child: Text('Contain')),
                  ],
                  onChanged: (v) {
                    if (v != null)
                      update((e) => e.copyWith(style: {...e.style, 'fit': v}));
                  },
                ),
              if ({
                DesignElementType.studentPhoto,
                DesignElementType.schoolLogo,
                DesignElementType.rectangle,
              }.contains(e.type)) ...[
                _colourProperty(
                  'Border colour (hex)',
                  e.style['border_color'] as String? ?? '#000000',
                  (value) {
                    if (isDesignerHex(value)) {
                      update(
                        (e) => e.copyWith(
                          style: {
                            ...e.style,
                            'border_color': value.toUpperCase(),
                          },
                        ),
                      );
                    }
                  },
                ),
                _numberField(
                  'Border width',
                  (e.style['border_width'] as num?)?.toDouble() ?? 0,
                  (value) => update(
                    (e) => e.copyWith(
                      style: {...e.style, 'border_width': value.clamp(0, 10)},
                    ),
                  ),
                  wide: true,
                ),
                _numberField(
                  'Corner radius',
                  (e.style['corner_radius'] as num?)?.toDouble() ?? 0,
                  (value) => update(
                    (e) => e.copyWith(
                      style: {...e.style, 'corner_radius': value.clamp(0, 30)},
                    ),
                  ),
                  wide: true,
                ),
              ],
              if (e.type == DesignElementType.rectangle) ...[
                _colourProperty(
                  'Fill colour (hex)',
                  e.style['fill_color'] as String? ?? '#FFFFFF',
                  (v) {
                    if (isDesignerHex(v))
                      update(
                        (e) => e.copyWith(
                          style: {...e.style, 'fill_color': v.toUpperCase()},
                        ),
                      );
                  },
                ),
              ],
              if (e.type == DesignElementType.line) ...[
                _colourProperty(
                  'Line colour (hex)',
                  e.style['color'] as String? ?? '#000000',
                  (value) {
                    if (isDesignerHex(value)) {
                      update(
                        (e) => e.copyWith(
                          style: {...e.style, 'color': value.toUpperCase()},
                        ),
                      );
                    }
                  },
                ),
                _numberField(
                  'Line width',
                  (e.style['border_width'] as num?)?.toDouble() ?? .5,
                  (value) => update(
                    (e) => e.copyWith(
                      style: {...e.style, 'border_width': value.clamp(.1, 10)},
                    ),
                  ),
                  wide: true,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

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
        if (value == 'cr80') _setCr80Preset();
      },
    ),
    _canvasDimensionField(
      key: const Key('canvas-width'),
      label: 'Width (mm)',
      controller: _canvasWidth,
    ),
    _canvasDimensionField(
      key: const Key('canvas-height'),
      label: 'Height (mm)',
      controller: _canvasHeight,
    ),
    _dropdownProperty<String>(
      key: ValueKey('canvas-orientation-${_document.canvas.orientation}'),
      label: 'Orientation',
      value: _document.canvas.orientation,
      items: const [
        DropdownMenuItem(value: 'landscape', child: Text('Landscape')),
        DropdownMenuItem(value: 'portrait', child: Text('Portrait')),
      ],
      onChanged: (value) {
        if (value != null) _setCanvasOrientation(value);
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
            _updateUi(() => _canvasError = null);
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
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          _canvasError!,
          key: const Key('canvas-validation-error'),
          style: const TextStyle(color: Colors.red, fontSize: 12),
        ),
      ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Grid enabled'),
      value: _document.settings['grid_enabled'] != false,
      onChanged: (value) => _commit(
        _document.copyWith(
          settings: {..._document.settings, 'grid_enabled': value},
        ),
      ),
    ),
    _numberField(
      'Grid size (mm)',
      (_document.settings['grid_size'] as num?)?.toDouble() ?? 2,
      (value) {
        if (!value.isFinite || value <= 0 || value > 200) {
          _updateUi(
            () => _canvasError = 'Grid size must be between 0 and 200 mm.',
          );
          return;
        }
        _updateUi(() => _canvasError = null);
        _commit(
          _document.copyWith(
            settings: {..._document.settings, 'grid_size': value},
          ),
        );
      },
      wide: true,
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Snap enabled'),
      value: _document.settings['snap_enabled'] != false,
      onChanged: (value) => _commit(
        _document.copyWith(
          settings: {..._document.settings, 'snap_enabled': value},
        ),
      ),
    ),
    const Text(
      'Canvas resizing keeps every element at its existing millimetre position and size. Content outside the new bounds is clipped.',
      style: TextStyle(color: Colors.black54, fontSize: 12),
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
      liveEntry: true,
      onChanged: (value) {
        controller.text = value.clamp(10.1, 2000.0).toStringAsFixed(2);
        _applyCanvasDimensions();
      },
    ),
  );

  InputDecoration _propertyDecoration(String label) => InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    border: const OutlineInputBorder(),
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
    if (_recentColours.length > 12) _recentColours.removeLast();
  }

  Widget _colourProperty(
    String label,
    String value,
    ValueChanged<String> apply,
  ) => _propertyControl(
    DesignerColourField(
      fieldKey: Key('property-${label.toLowerCase().replaceAll(' ', '-')}'),
      ownerId: _selectedId,
      value: value,
      decoration: _propertyDecoration(label),
      recentColours: _recentColours,
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

// Controllers hold editing drafts only. Committed values always come from the
// document, including selection changes, gestures, and undo/redo.
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
    if (_controller.text == widget.value) return;
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

class _GridPainter extends CustomPainter {
  const _GridPainter(this.gridMm, this.canvasWidthMm);
  final double gridMm, canvasWidthMm;
  @override
  void paint(Canvas canvas, Size size) {
    final step = gridMm * size.width / canvasWidthMm;
    if (step < 4) return;
    final p = Paint()
      ..color = const Color(0x18000000)
      ..strokeWidth = .5;
    for (double x = step; x < size.width; x += step)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = step; y < size.height; y += step)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.gridMm != gridMm ||
      oldDelegate.canvasWidthMm != canvasWidthMm;
}

// Cache each section by the state it actually displays. Geometry updates do not
// rebuild app chrome, toolbar or layers; no element model is cached here.
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
    if (!unchanged) setState(() => _signature = next);
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
  const _DesignerSnapshot(this.template, this.selectedId);
  final CardTemplate template;
  final String? selectedId;
}
