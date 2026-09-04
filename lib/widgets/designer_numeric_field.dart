import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A document-backed number with a local text draft, never a geometry model.
class DesignerNumericField extends StatefulWidget {
  const DesignerNumericField({
    super.key,
    required this.fieldKey,
    required this.ownerId,
    required this.value,
    required this.decoration,
    required this.onChanged,
    this.liveEntry = false,
    this.normalStep = .1,
    this.largeStep = 1,
  });
  final Key fieldKey;
  final String? ownerId;
  final double value;
  final InputDecoration decoration;
  final ValueChanged<double> onChanged;
  final bool liveEntry;
  final double normalStep, largeStep;
  @override
  State<DesignerNumericField> createState() => _DesignerNumericFieldState();
}

class _StepNumberIntent extends Intent {
  const _StepNumberIntent(this.direction);
  final int direction;
}

class _DesignerNumericFieldState extends State<DesignerNumericField> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toStringAsFixed(2));
  }

  void _write(double value) {
    final text = value.toStringAsFixed(2);
    if (_controller.text == text) return;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _submit(String text) {
    final value = double.tryParse(text.trim());
    if (value != null && value.isFinite) widget.onChanged(value);
    // Canonicalize clamped, rejected, and no-op submissions after the parent
    // has delivered the current document value.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _write(widget.value);
    });
    setState(() {});
  }

  void _step(int direction) {
    final draft = double.tryParse(_controller.text);
    final current = draft != null && draft.isFinite ? draft : widget.value;
    final step = HardwareKeyboard.instance.isShiftPressed
        ? widget.largeStep
        : widget.normalStep;
    final next = double.parse((current + direction * step).toStringAsFixed(2));
    _write(next);
    _submit(_controller.text);
  }

  @override
  void didUpdateWidget(covariant DesignerNumericField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId ||
        oldWidget.fieldKey != widget.fieldKey ||
        oldWidget.value != widget.value) {
      _write(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerSignal: (event) {
      if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
        // Claim this signal before the surrounding Scrollable can consume it.
        GestureBinding.instance.pointerSignalResolver.register(event, (_) {
          _step(event.scrollDelta.dy < 0 ? 1 : -1);
        });
      }
    },
    child: Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowUp): _StepNumberIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowDown): _StepNumberIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
            _StepNumberIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
            _StepNumberIntent(-1),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _StepNumberIntent: CallbackAction<_StepNumberIntent>(
            onInvoke: (intent) {
              _step(intent.direction);
              return null;
            },
          ),
        },
        child: TextFormField(
          key: widget.fieldKey,
          controller: _controller,
          focusNode: _focus,
          decoration: widget.decoration,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          onChanged: widget.liveEntry
              ? (text) {
                  final value = double.tryParse(text);
                  if (value != null && value.isFinite) widget.onChanged(value);
                }
              : null,
          onFieldSubmitted: _submit,
        ),
      ),
    ),
  );
}
