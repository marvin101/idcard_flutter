import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  final Map<int, Offset> _touchPositions = {};
  final Map<int, Offset> _pointerDownPositions = {};
  final Set<int> _tapCandidates = {};
  final Set<int> _locallyOwnedPointers = {};
  List<int>? _touchPair;
  double _panZoomStartScale = DisplayScaleProvider.normalScale;
  double _touchStartScale = DisplayScaleProvider.normalScale;
  double _touchStartDistance = 1;
  bool _panZoomOwnedLocally = false;
  bool _touchOwnedLocally = false;
  Duration? _lastTapTime;
  Offset? _lastTapPosition;

  HitTestResult _hitTest(Offset position, int viewId) {
    final result = HitTestResult();
    RendererBinding.instance.hitTestInView(result, position, viewId);
    return result;
  }

  bool _localZoomOwns(Offset position, int viewId) => _hitTest(
    position,
    viewId,
  ).path.any((entry) => entry.target is _RenderAppScaleGestureBoundary);

  bool _interactiveControlOwnsTap(Offset position, int viewId) {
    for (final entry in _hitTest(position, viewId).path) {
      final target = entry.target;
      if (target is RenderEditable || target is RenderSemanticsGestureHandler) {
        return true;
      }
      if (target is SemanticsAnnotationsMixin) {
        final properties = target.properties;
        if (properties.onTap != null ||
            properties.onLongPress != null ||
            properties.textField == true ||
            properties.button == true ||
            properties.link == true ||
            properties.slider == true) {
          return true;
        }
      }
    }
    return false;
  }

  void _panZoomStart(PointerPanZoomStartEvent event) {
    _panZoomOwnedLocally = _localZoomOwns(event.position, event.viewId);
    _panZoomStartScale = context.read<DisplayScaleProvider>().scale;
  }

  void _panZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (_panZoomOwnedLocally) return;
    context.read<DisplayScaleProvider>().setScale(
      _panZoomStartScale * event.scale,
    );
  }

  void _panZoomEnd(PointerPanZoomEndEvent _) {
    _panZoomOwnedLocally = false;
  }

  void _pointerSignal(PointerSignalEvent event) {
    if (event is! PointerScaleEvent ||
        _localZoomOwns(event.position, event.viewId)) {
      return;
    }
    final displayScale = context.read<DisplayScaleProvider>();
    displayScale.setScale(displayScale.scale * event.scale);
  }

  void _pointerDown(PointerDownEvent event) {
    _pointerDownPositions[event.pointer] = event.position;
    final localZoomOwns = _localZoomOwns(event.position, event.viewId);
    if (localZoomOwns) {
      _locallyOwnedPointers.add(event.pointer);
    }
    if (!localZoomOwns &&
        !_interactiveControlOwnsTap(event.position, event.viewId)) {
      _tapCandidates.add(event.pointer);
    } else {
      _lastTapTime = null;
      _lastTapPosition = null;
    }

    if (event.kind == PointerDeviceKind.touch) {
      _touchPositions[event.pointer] = event.position;
      if (_touchPair != null || _touchPositions.length != 2) return;
      final pair = _touchPositions.keys.toList(growable: false)..sort();
      _touchPair = pair;
      final first = _touchPositions[pair[0]]!;
      final second = _touchPositions[pair[1]]!;
      _touchStartDistance = math.max((first - second).distance, 0.01);
      _touchStartScale = context.read<DisplayScaleProvider>().scale;
      _touchOwnedLocally = pair.any(_locallyOwnedPointers.contains);
      _tapCandidates.removeAll(pair);
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    final downPosition = _pointerDownPositions[event.pointer];
    if (downPosition != null &&
        (event.position - downPosition).distance > kDoubleTapTouchSlop) {
      _tapCandidates.remove(event.pointer);
    }
    if (event.kind != PointerDeviceKind.touch ||
        !_touchPositions.containsKey(event.pointer)) {
      return;
    }
    _touchPositions[event.pointer] = event.position;
    final pair = _touchPair;
    if (pair == null || _touchOwnedLocally) return;
    final first = _touchPositions[pair[0]];
    final second = _touchPositions[pair[1]];
    if (first == null || second == null) return;
    context.read<DisplayScaleProvider>().setScale(
      _touchStartScale * ((first - second).distance / _touchStartDistance),
    );
  }

  void _pointerEnd(PointerEvent event) {
    final wasTapCandidate = _tapCandidates.remove(event.pointer);
    final wasTap = event is PointerUpEvent && wasTapCandidate;
    _pointerDownPositions.remove(event.pointer);
    _locallyOwnedPointers.remove(event.pointer);
    if (wasTap) {
      final lastTime = _lastTapTime;
      final lastPosition = _lastTapPosition;
      if (lastTime != null &&
          lastPosition != null &&
          event.timeStamp - lastTime <= kDoubleTapTimeout &&
          (event.position - lastPosition).distance <= kDoubleTapSlop) {
        context.read<DisplayScaleProvider>().toggleDoubleTapScale();
        _lastTapTime = null;
        _lastTapPosition = null;
      } else {
        _lastTapTime = event.timeStamp;
        _lastTapPosition = event.position;
      }
    }
    if (event.kind == PointerDeviceKind.touch) {
      _touchPositions.remove(event.pointer);
      if (_touchPair?.contains(event.pointer) == true) {
        _touchPair = null;
        _touchOwnedLocally = false;
      }
    }
  }

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
      const SingleActivator(LogicalKeyboardKey.equal, meta: true, shift: true):
          displayScale.zoomIn,
      const SingleActivator(LogicalKeyboardKey.numpadAdd, meta: true):
          displayScale.zoomIn,
      const SingleActivator(LogicalKeyboardKey.minus, meta: true):
          displayScale.zoomOut,
      const SingleActivator(LogicalKeyboardKey.numpadSubtract, meta: true):
          displayScale.zoomOut,
      const SingleActivator(LogicalKeyboardKey.digit0, meta: true):
          displayScale.reset,
    };

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _pointerDown,
      onPointerMove: _pointerMove,
      onPointerUp: _pointerEnd,
      onPointerCancel: _pointerEnd,
      onPointerPanZoomStart: _panZoomStart,
      onPointerPanZoomUpdate: _panZoomUpdate,
      onPointerPanZoomEnd: _panZoomEnd,
      onPointerSignal: _pointerSignal,
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
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: 0,
                  minHeight: 0,
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Marks a subtree whose own gesture system has exclusive zoom ownership.
///
/// The app-scale listener remains outside the gesture arena so ordinary
/// scrolling and controls are untouched. It uses hit testing to skip both
/// trackpad and touch pinch events that begin inside this boundary.
class AppScaleGestureBoundary extends SingleChildRenderObjectWidget {
  const AppScaleGestureBoundary({required super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderAppScaleGestureBoundary();
}

class _RenderAppScaleGestureBoundary extends RenderProxyBox {}
