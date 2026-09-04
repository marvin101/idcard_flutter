// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final FocusNode _canvasFocus = FocusNode(debugLabel: 'designer canvas');
  final List<DesignDocument> _history = [];
  int _historyIndex = 0;
  String? _selectedId, _logoUrl;
  SchoolProfile? _schoolProfile;
  List<StudentFieldDefinition> _customFields = const [];
  late String _savedDocument;
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
  bool get _dirty => jsonEncode(_template.toApi()) != _savedDocument;
  bool get _canUndo => _historyIndex > 0;
  bool get _canRedo => _historyIndex + 1 < _history.length;

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
    _history.add(_document);
    _savedDocument = jsonEncode(_template.toApi());
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
      setState(() {
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
    super.dispose();
  }

  void _rename() => setState(() {
    _template = _template.copyWith(name: _name.text);
    _saveState = 'Unsaved changes';
  });

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
      setState(() {
        _canvasError = 'Width and height must be between 10 and 2000 mm.';
      });
      return;
    }
    setState(() => _canvasError = null);
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
    setState(() => _canvasError = null);
    _commit(_document.copyWith(canvas: next));
  }

  void _setCr80Preset() {
    _canvasWidth.text = '85.60';
    _canvasHeight.text = '53.98';
    setState(() => _canvasError = null);
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

  void _commit(DesignDocument next, {String? selectedId}) {
    if (jsonEncode(next.toJson()) == jsonEncode(_document.toJson())) return;
    if (_historyIndex + 1 < _history.length)
      _history.removeRange(_historyIndex + 1, _history.length);
    _history.add(next);
    if (_history.length > 80)
      _history.removeAt(0);
    else
      _historyIndex++;
    setState(() {
      _template = _template.copyWith(document: next);
      if (selectedId != null) _selectedId = selectedId;
      _saveState = 'Unsaved changes';
    });
  }

  void _undo() {
    if (!_canUndo) return;
    setState(() {
      _historyIndex--;
      _template = _template.copyWith(document: _history[_historyIndex]);
      _syncCanvasControllers();
      _saveState = _dirty ? 'Unsaved changes' : 'Saved';
    });
  }

  void _redo() {
    if (!_canRedo) return;
    setState(() {
      _historyIndex++;
      _template = _template.copyWith(document: _history[_historyIndex]);
      _syncCanvasControllers();
      _saveState = 'Unsaved changes';
    });
  }

  void _replace(DesignElement replacement) => _commit(
    _document.copyWith(
      elements: [
        for (final element in _document.elements)
          if (element.id == replacement.id) replacement else element,
      ],
    ),
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
    final element = _document.elements.firstWhere((item) => item.id == id);
    if (element.locked) return;
    var x = (element.x + dx)
        .clamp(0.0, math.max(0, _document.canvas.width - element.width))
        .toDouble();
    var y = (element.y + dy)
        .clamp(0.0, math.max(0, _document.canvas.height - element.height))
        .toDouble();
    if (_document.settings['snap_enabled'] != false) {
      const tolerance = 0.8;
      final centerX = (_document.canvas.width - element.width) / 2;
      final centerY = (_document.canvas.height - element.height) / 2;
      if ((x - centerX).abs() < tolerance) x = centerX;
      if ((y - centerY).abs() < tolerance) y = centerY;
      final grid = (_document.settings['grid_size'] as num?)?.toDouble() ?? 2;
      if (grid > 0) {
        x = ((x / grid).round() * grid).toDouble();
        y = ((y / grid).round() * grid).toDouble();
      }
    }
    _replace(element.copyWith(x: x, y: y));
  }

  void _resize(String id, double dw, double dh) {
    final element = _document.elements.firstWhere((item) => item.id == id);
    if (element.locked) return;
    final ratio = element.width / element.height;
    var width = (element.width + dw).clamp(
      2.0,
      _document.canvas.width - element.x,
    );
    var height = (element.height + dh).clamp(
      1.0,
      _document.canvas.height - element.y,
    );
    if (element.type == DesignElementType.studentPhoto ||
        element.type == DesignElementType.schoolLogo)
      height = (width / ratio).clamp(1.0, _document.canvas.height - element.y);
    _replace(element.copyWith(width: width, height: height));
  }

  void _remove() {
    final selected = _selected;
    if (selected == null || selected.locked) return;
    _commit(
      _document.copyWith(
        elements: _document.elements.where((e) => e.id != selected.id).toList(),
      ),
    );
    setState(() => _selectedId = null);
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

  void _key(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final control =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (control && event.logicalKey == LogicalKeyboardKey.keyZ) {
      shift ? _redo() : _undo();
      return;
    }
    if (control && event.logicalKey == LogicalKeyboardKey.keyY) {
      _redo();
      return;
    }
    if (control && event.logicalKey == LogicalKeyboardKey.keyD) {
      _duplicate();
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _selectedId = null);
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      _remove();
      return;
    }
    final step = shift ? 5.0 : 0.5;
    final selectedId = _selectedId;
    if (selectedId == null) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft)
      _move(selectedId, -step, 0);
    if (event.logicalKey == LogicalKeyboardKey.arrowRight)
      _move(selectedId, step, 0);
    if (event.logicalKey == LogicalKeyboardKey.arrowUp)
      _move(selectedId, 0, -step);
    if (event.logicalKey == LogicalKeyboardKey.arrowDown)
      _move(selectedId, 0, step);
  }

  Future<void> _save() async {
    if (!_dirty || _saving || _name.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _saveState = 'Saving…';
      _template = _template.copyWith(name: _name.text.trim());
    });
    try {
      final saved = await widget.api.saveCardTemplate(
        widget.schoolUuid,
        _template,
      );
      if (!mounted) return;
      setState(() {
        _template = saved;
        _savedDocument = jsonEncode(saved.toApi());
        _name.text = saved.name;
        _saving = false;
        _saveState = 'Saved';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
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
      _commit(CardTemplate.uploadedDesign.document);
      _syncCanvasControllers();
      setState(() => _selectedId = null);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _dirty)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Save or undo your changes before leaving.'),
          ),
        );
    },
    child: Scaffold(
      backgroundColor: const Color(0xfff3f5f9),
      appBar: AuthenticatedAppBar(
        title: const Text('Card designer'),
        actions: [
          Center(
            child: Text(
              _saveState,
              key: const Key('designer-save-state'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
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
        ],
      ),
      body: Column(
        children: [
          _toolbar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth >= 1050
                  ? Row(
                      children: [
                        SizedBox(width: 250, child: _layers()),
                        Expanded(child: _workspace()),
                        SizedBox(width: 300, child: _inspector()),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _workspace()),
                        SizedBox(width: 300, child: _inspector()),
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
                onChanged: (v) => setState(() => _zoom = v),
              ),
            ),
            const Icon(Icons.zoom_in),
            TextButton(
              onPressed: () => setState(() => _zoom = 1),
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
            return KeyboardListener(
              focusNode: _canvasFocus,
              onKeyEvent: _key,
              child: GestureDetector(
                onTap: () => _canvasFocus.requestFocus(),
                child: InteractiveViewer(
                  minScale: .5,
                  maxScale: 3,
                  child: Center(
                    child: SizedBox(
                      key: const Key('designer-canvas-frame'),
                      width: displayWidth,
                      child: Stack(
                        children: [
                          DesignDocumentView(
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
                            onSelect: (id) => setState(() => _selectedId = id),
                            onMove: _move,
                            onResize: _resize,
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
                    onTap: () => setState(() => _selectedId = e.id),
                    leading: IconButton(
                      tooltip: e.visible ? 'Hide' : 'Show',
                      icon: Icon(
                        e.visible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                      onPressed: () =>
                          _replace(e.copyWith(visible: !e.visible)),
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
                      onPressed: () => _replace(e.copyWith(locked: !e.locked)),
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
                        x: v.clamp(0, _document.canvas.width - e.width),
                      ),
                    ),
                  ),
                  _numberField(
                    'Y',
                    e.y,
                    (v) => update(
                      (e) => e.copyWith(
                        y: v.clamp(0, _document.canvas.height - e.height),
                      ),
                    ),
                  ),
                  _numberField(
                    'Width',
                    e.width,
                    (v) => update(
                      (e) => e.copyWith(
                        width: v.clamp(2, _document.canvas.width - e.x),
                      ),
                    ),
                  ),
                  _numberField(
                    'Height',
                    e.height,
                    (v) => update(
                      (e) => e.copyWith(
                        height: v.clamp(1, _document.canvas.height - e.y),
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
                _textProperty(
                  'Text colour (hex)',
                  e.style['color'] as String? ?? '#111111',
                  (v) {
                    if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v))
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
                _textProperty(
                  'Border colour (hex)',
                  e.style['border_color'] as String? ?? '#000000',
                  (value) {
                    if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
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
                _textProperty(
                  'Fill colour (hex)',
                  e.style['fill_color'] as String? ?? '#FFFFFF',
                  (v) {
                    if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v))
                      update(
                        (e) => e.copyWith(
                          style: {...e.style, 'fill_color': v.toUpperCase()},
                        ),
                      );
                  },
                ),
              ],
              if (e.type == DesignElementType.line) ...[
                _textProperty(
                  'Line colour (hex)',
                  e.style['color'] as String? ?? '#000000',
                  (value) {
                    if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
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
      TextField(
        key: const Key('canvas-background-color'),
        controller: _canvasBackground,
        decoration: _propertyDecoration('Background colour'),
        onChanged: (value) {
          if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
            setState(() => _canvasError = null);
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
          setState(
            () => _canvasError = 'Grid size must be between 0 and 200 mm.',
          );
          return;
        }
        setState(() => _canvasError = null);
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
    TextField(
      key: key,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _propertyDecoration(label),
      onChanged: (_) => _applyCanvasDimensions(),
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
      child: _ModelTextProperty(
        fieldKey: Key('property-${label.toLowerCase().replaceAll(' ', '-')}'),
        ownerId: _selectedId,
        value: value.toStringAsFixed(2),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: _propertyDecoration(label),
        onFieldSubmitted: (text) {
          final next = double.tryParse(text);
          if (next != null && next.isFinite) apply(next);
        },
      ),
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
    this.keyboardType,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final Key fieldKey;
  final String? ownerId;
  final String value;
  final InputDecoration decoration;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged, onFieldSubmitted;

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
    keyboardType: widget.keyboardType,
    decoration: widget.decoration,
    onChanged: widget.onChanged,
    onFieldSubmitted: widget.onFieldSubmitted == null
        ? null
        : (text) {
            widget.onFieldSubmitted!(text);
            // A no-op or rejected submission may not rebuild the parent.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _sync();
            });
            setState(() {});
          },
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
