import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/display_scale_provider.dart';

class AppScaleViewport extends StatefulWidget {
  const AppScaleViewport({required this.child, super.key});

  final Widget child;

  @override
  State<AppScaleViewport> createState() => _AppScaleViewportState();
}

class _AppScaleViewportState extends State<AppScaleViewport> {
  double _gestureStartScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final displayScale = context.watch<DisplayScaleProvider>();
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.equal, control: true):
          displayScale.zoomIn,
      const SingleActivator(
        LogicalKeyboardKey.equal,
        control: true,
        shift: true,
      ): displayScale.zoomIn,
      const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true):
          displayScale.zoomIn,
      const SingleActivator(LogicalKeyboardKey.minus, control: true):
          displayScale.zoomOut,
      const SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true):
          displayScale.zoomOut,
      const SingleActivator(LogicalKeyboardKey.digit0, control: true):
          displayScale.reset,
      const SingleActivator(LogicalKeyboardKey.equal, meta: true):
          displayScale.zoomIn,
      const SingleActivator(LogicalKeyboardKey.minus, meta: true):
          displayScale.zoomOut,
      const SingleActivator(LogicalKeyboardKey.digit0, meta: true):
          displayScale.reset,
    };

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerPanZoomStart: (_) {
        _gestureStartScale = context.read<DisplayScaleProvider>().scale;
      },
      onPointerPanZoomUpdate: (event) {
        context.read<DisplayScaleProvider>().setScale(
          _gestureStartScale * event.scale,
        );
      },
      child: CallbackShortcuts(
        bindings: shortcuts,
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = displayScale.scale;
              final logicalSize = Size(
                constraints.maxWidth / scale,
                constraints.maxHeight / scale,
              );
              final mediaQuery = MediaQuery.of(context);
              return ClipRect(
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topLeft,
                  child: SizedBox.fromSize(
                    size: logicalSize,
                    child: MediaQuery(
                      data: mediaQuery.copyWith(size: logicalSize),
                      child: widget.child,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

