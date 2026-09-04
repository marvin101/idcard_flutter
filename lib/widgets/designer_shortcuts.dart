import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum DesignerCommand { undo, redo, save, delete, duplicate, deselect, nudge }

class _CommandIntent extends Intent {
  const _CommandIntent(this.command, [this.delta = Offset.zero]);
  final DesignerCommand command;
  final Offset delta;
}

class DesignerShortcuts extends StatelessWidget {
  const DesignerShortcuts({
    super.key,
    required this.child,
    required this.onCommand,
  });
  final Widget child;
  final void Function(DesignerCommand, Offset) onCommand;

  static bool get editingText {
    final context = FocusManager.instance.primaryFocus?.context;
    return context?.widget is EditableText ||
        context?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    final bindings = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.keyY, control: true):
          const _CommandIntent(DesignerCommand.redo),
      const SingleActivator(LogicalKeyboardKey.delete): const _CommandIntent(
        DesignerCommand.delete,
      ),
      const SingleActivator(LogicalKeyboardKey.backspace): const _CommandIntent(
        DesignerCommand.delete,
      ),
      const SingleActivator(LogicalKeyboardKey.escape): const _CommandIntent(
        DesignerCommand.deselect,
      ),
    };
    for (final meta in [false, true]) {
      bindings[SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: !meta,
        meta: meta,
      )] = const _CommandIntent(
        DesignerCommand.undo,
      );
      bindings[SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: !meta,
        meta: meta,
        shift: true,
      )] = const _CommandIntent(
        DesignerCommand.redo,
      );
      bindings[SingleActivator(
        LogicalKeyboardKey.keyS,
        control: !meta,
        meta: meta,
      )] = const _CommandIntent(
        DesignerCommand.save,
      );
      bindings[SingleActivator(
        LogicalKeyboardKey.keyD,
        control: !meta,
        meta: meta,
      )] = const _CommandIntent(
        DesignerCommand.duplicate,
      );
    }
    for (final shift in [false, true]) {
      final step = shift ? 1.0 : .1;
      for (final entry in {
        LogicalKeyboardKey.arrowLeft: Offset(-step, 0),
        LogicalKeyboardKey.arrowRight: Offset(step, 0),
        LogicalKeyboardKey.arrowUp: Offset(0, -step),
        LogicalKeyboardKey.arrowDown: Offset(0, step),
      }.entries) {
        bindings[SingleActivator(entry.key, shift: shift)] = _CommandIntent(
          DesignerCommand.nudge,
          entry.value,
        );
      }
    }
    return Shortcuts(
      shortcuts: bindings,
      child: Actions(
        actions: {_CommandIntent: _CommandAction(onCommand)},
        child: child,
      ),
    );
  }
}

class _CommandAction extends Action<_CommandIntent> {
  _CommandAction(this.onCommand);
  final void Function(DesignerCommand, Offset) onCommand;
  @override
  bool isEnabled(_CommandIntent intent) =>
      [
        DesignerCommand.undo,
        DesignerCommand.redo,
        DesignerCommand.save,
      ].contains(intent.command) ||
      !DesignerShortcuts.editingText;
  @override
  Object? invoke(_CommandIntent intent) {
    onCommand(intent.command, intent.delta);
    return null;
  }
}
