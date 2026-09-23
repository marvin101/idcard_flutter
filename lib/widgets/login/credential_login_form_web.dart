import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

typedef CredentialSubmitCallback =
    Future<void> Function(String username, String password);

/// Reserves space in Flutter while a persistent native form is mounted as a
/// direct child of the document body for browser password-manager discovery.
class CredentialLoginForm extends StatefulWidget {
  const CredentialLoginForm({
    required this.busy,
    required this.onSubmit,
    super.key,
  });

  final bool busy;
  final CredentialSubmitCallback onSubmit;

  @override
  State<CredentialLoginForm> createState() => _CredentialLoginFormState();
}

class _CredentialLoginFormState extends State<CredentialLoginForm>
    with WidgetsBindingObserver {
  final _placeholderKey = GlobalKey();

  web.HTMLFormElement? _form;
  web.HTMLButtonElement? _submitButton;
  web.HTMLButtonElement? _visibilityButton;
  web.HTMLStyleElement? _styleElement;
  web.EventListener? _submitListener;
  web.EventListener? _visibilityListener;
  web.EventListener? _viewportListener;
  ScrollPosition? _scrollPosition;
  bool _passwordVisible = false;
  bool _submissionInFlight = false;
  bool _geometrySyncScheduled = false;
  bool _routeIsCurrent = false;
  bool _formAttached = false;
  bool _domListenersAttached = false;
  bool _viewportListenersAttached = false;
  bool _scrollListenerAttached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createBodyForm();
    _createViewportListener();
    _scheduleGeometrySync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (routeIsCurrent != _routeIsCurrent) {
      _routeIsCurrent = routeIsCurrent;
      if (_routeIsCurrent) {
        _attachForm();
      } else {
        _detachForm();
      }
    }
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (!identical(nextPosition, _scrollPosition)) {
      if (_scrollListenerAttached) {
        _scrollPosition?.removeListener(_scheduleGeometrySync);
        _scrollListenerAttached = false;
      }
      _scrollPosition = nextPosition;
    }
    _startActiveListeners();
    _scheduleGeometrySync();
  }

  @override
  void didUpdateWidget(CredentialLoginForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy) _syncBusyState();
    _scheduleGeometrySync();
  }

  @override
  void didChangeMetrics() => _scheduleGeometrySync();

  @override
  void reassemble() {
    super.reassemble();
    _scheduleGeometrySync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detachForm();
    _scrollPosition = null;
    _form = null;
    _submitButton = null;
    _visibilityButton = null;
    _styleElement = null;
    _submitListener = null;
    _visibilityListener = null;
    _viewportListener = null;
    super.dispose();
  }

  void _createBodyForm() {
    // A hot restart can leave DOM owned by the previous Dart isolate behind.
    // Remove it once when taking ownership, rather than on every rebuild.
    web.Element? staleForm;
    while ((staleForm = web.document.querySelector('#campusid-login-form')) !=
        null) {
      staleForm!.remove();
    }
    web.document.querySelector('#campusid-login-form-styles')?.remove();

    final styleElement = web.HTMLStyleElement()
      ..id = 'campusid-login-form-styles'
      ..textContent = _focusStyles;

    final form = web.HTMLFormElement()
      ..id = 'campusid-login-form'
      ..method = 'post'
      ..autocomplete = 'on'
      ..setAttribute('aria-label', 'CampusID sign in')
      ..setAttribute('style', _hiddenFormStyle);

    final usernameLabel = _label('campusid-username', 'Username');
    final usernameInput = web.HTMLInputElement()
      ..id = 'campusid-username'
      ..name = 'username'
      ..type = 'text'
      ..autocomplete = 'username'
      ..required = true
      ..autocapitalize = 'none'
      ..spellcheck = false
      ..setAttribute('aria-label', 'Username')
      ..setAttribute('style', _inputStyle);

    final passwordLabel = _label('campusid-password', 'Password');
    final passwordInput = web.HTMLInputElement()
      ..id = 'campusid-password'
      ..name = 'password'
      ..type = 'password'
      ..autocomplete = 'current-password'
      ..required = true
      ..setAttribute('aria-label', 'Password')
      ..setAttribute('style', _passwordInputStyle);

    final visibilityButton = web.HTMLButtonElement()
      ..type = 'button'
      ..textContent = 'Show'
      ..title = 'Show password'
      ..setAttribute('aria-label', 'Show password')
      ..setAttribute('style', _visibilityButtonStyle);

    final passwordRow = web.HTMLDivElement()
      ..setAttribute('style', _passwordRowStyle)
      ..append(passwordInput);

    final submitButton = web.HTMLButtonElement()
      ..type = 'submit'
      ..setAttribute('style', _submitButtonStyle);

    final submitListener = ((web.Event event) {
      event.preventDefault();
      if (widget.busy || _submissionInFlight || !form.reportValidity()) return;
      unawaited(_submit(usernameInput.value, passwordInput.value));
    }).toJS;
    final visibilityListener = ((web.Event event) {
      event.preventDefault();
      _passwordVisible = !_passwordVisible;
      passwordInput.type = _passwordVisible ? 'text' : 'password';
      visibilityButton
        ..textContent = _passwordVisible ? 'Hide' : 'Show'
        ..title = _passwordVisible ? 'Hide password' : 'Show password'
        ..setAttribute(
          'aria-label',
          _passwordVisible ? 'Hide password' : 'Show password',
        );
    }).toJS;
    form
      ..append(usernameLabel)
      ..append(usernameInput)
      ..append(passwordLabel)
      ..append(passwordRow)
      ..append(submitButton)
      // Keep keyboard order Username -> Password -> Sign in. The visibility
      // control remains visually attached to the password field.
      ..append(visibilityButton);

    _form = form;
    _submitButton = submitButton;
    _visibilityButton = visibilityButton;
    _styleElement = styleElement;
    _submitListener = submitListener;
    _visibilityListener = visibilityListener;
    _syncBusyState();
  }

  void _attachForm() {
    final form = _form;
    final styleElement = _styleElement;
    if (form == null || styleElement == null || _formAttached) return;
    web.document.head?.append(styleElement);
    web.document.body?.append(form);
    _formAttached = true;
    _startActiveListeners();
    _scheduleGeometrySync();
  }

  void _detachForm() {
    _stopActiveListeners();
    _form?.remove();
    _styleElement?.remove();
    _formAttached = false;
  }

  void _createViewportListener() {
    _viewportListener = ((web.Event _) => _scheduleGeometrySync()).toJS;
    _startActiveListeners();
  }

  void _startActiveListeners() {
    if (!_routeIsCurrent) return;

    final form = _form;
    final submitListener = _submitListener;
    final visibilityButton = _visibilityButton;
    final visibilityListener = _visibilityListener;
    if (!_domListenersAttached &&
        form != null &&
        submitListener != null &&
        visibilityButton != null &&
        visibilityListener != null) {
      form.addEventListener('submit', submitListener);
      visibilityButton.addEventListener('click', visibilityListener);
      _domListenersAttached = true;
    }

    final listener = _viewportListener;
    if (!_viewportListenersAttached && listener != null) {
      web.window.addEventListener('resize', listener);
      web.window.addEventListener('scroll', listener);
      web.window.visualViewport?.addEventListener('resize', listener);
      web.window.visualViewport?.addEventListener('scroll', listener);
      _viewportListenersAttached = true;
    }

    final scrollPosition = _scrollPosition;
    if (!_scrollListenerAttached && scrollPosition != null) {
      scrollPosition.addListener(_scheduleGeometrySync);
      _scrollListenerAttached = true;
    }
  }

  void _stopActiveListeners() {
    final form = _form;
    final submitListener = _submitListener;
    final visibilityButton = _visibilityButton;
    final visibilityListener = _visibilityListener;
    if (_domListenersAttached) {
      form?.removeEventListener('submit', submitListener);
      visibilityButton?.removeEventListener('click', visibilityListener);
      _domListenersAttached = false;
    }

    final listener = _viewportListener;
    if (_viewportListenersAttached && listener != null) {
      web.window.removeEventListener('resize', listener);
      web.window.removeEventListener('scroll', listener);
      web.window.visualViewport?.removeEventListener('resize', listener);
      web.window.visualViewport?.removeEventListener('scroll', listener);
      _viewportListenersAttached = false;
    }

    if (_scrollListenerAttached) {
      _scrollPosition?.removeListener(_scheduleGeometrySync);
      _scrollListenerAttached = false;
    }
  }

  web.HTMLLabelElement _label(String htmlFor, String text) =>
      web.HTMLLabelElement()
        ..htmlFor = htmlFor
        ..textContent = text
        ..setAttribute('style', _labelStyle);

  Future<void> _submit(String username, String password) async {
    _submissionInFlight = true;
    _syncBusyState();
    try {
      await widget.onSubmit(username, password);
    } finally {
      _submissionInFlight = false;
      if (mounted) {
        _syncBusyState();
        _scheduleGeometrySync();
      }
    }
  }

  void _syncBusyState() {
    final button = _submitButton;
    if (button == null) return;
    final busy = widget.busy || _submissionInFlight;
    button
      ..disabled = busy
      ..textContent = busy ? 'Signing in…' : 'Sign in'
      ..setAttribute('aria-busy', busy.toString())
      ..setAttribute(
        'style',
        busy ? _disabledSubmitButtonStyle : _submitButtonStyle,
      );
  }

  void _scheduleGeometrySync() {
    if (!mounted || _geometrySyncScheduled) return;
    _geometrySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _geometrySyncScheduled = false;
      if (mounted) _syncGeometry();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _syncGeometry() {
    final form = _form;
    if (!_routeIsCurrent || !_formAttached) return;
    final renderObject = _placeholderKey.currentContext?.findRenderObject();
    if (form == null || renderObject is! RenderBox || !renderObject.hasSize) {
      form?.setAttribute('style', _hiddenFormStyle);
      return;
    }

    final flutterView = web.document.querySelector('flutter-view');
    final flutterViewRect = flutterView?.getBoundingClientRect();
    final viewOffsetX = flutterViewRect?.left ?? 0;
    final viewOffsetY = flutterViewRect?.top ?? 0;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;

    if (!topLeft.dx.isFinite ||
        !topLeft.dy.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      form.setAttribute('style', _hiddenFormStyle);
      return;
    }

    form.setAttribute(
      'style',
      _positionedFormStyle(
        left: viewOffsetX + topLeft.dx,
        top: viewOffsetY + topLeft.dy,
        width: size.width,
        height: size.height,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _scheduleGeometrySync();
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _scheduleGeometrySync();
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: SizedBox(key: _placeholderKey, height: _formHeight),
      ),
    );
  }
}

const _formHeight = 220.0;
const _font =
    "font-family: Roboto, 'Helvetica Neue', Arial, sans-serif; color: #1f2937;";
const _formLayoutStyle =
    'margin: 0; display: flex; flex-direction: column; box-sizing: border-box; '
    'background: transparent; pointer-events: auto; z-index: 2147483000; $_font';
const _hiddenFormStyle =
    'position: fixed; visibility: hidden; left: 0; top: 0; width: 0; height: 0; '
    '$_formLayoutStyle';

String _positionedFormStyle({
  required double left,
  required double top,
  required double width,
  required double height,
}) =>
    'position: fixed; visibility: visible; '
    'left: ${left.toStringAsFixed(3)}px; top: ${top.toStringAsFixed(3)}px; '
    'width: ${width.toStringAsFixed(3)}px; height: ${height.toStringAsFixed(3)}px; '
    '$_formLayoutStyle';

const _focusStyles = '''
#campusid-login-form input:focus-visible {
  border-color: #102f55 !important;
  outline: 3px solid rgba(16, 47, 85, 0.22);
  outline-offset: 1px;
}
#campusid-login-form button:focus-visible {
  outline: 3px solid rgba(16, 47, 85, 0.32);
  outline-offset: 2px;
}
''';
const _labelStyle =
    'font-size: 13px; font-weight: 500; line-height: 18px; margin: 0 0 4px 12px; $_font';
const _inputStyle =
    'width: 100%; height: 48px; border: 1px solid #9ca3af; border-radius: 8px; '
    'box-sizing: border-box; padding: 0 14px; background: #ffffff; font-size: 16px; $_font';
const _passwordRowStyle =
    'position: relative; width: 100%; height: 48px; margin-bottom: 24px;';
const _passwordInputStyle =
    'width: 100%; height: 48px; border: 1px solid #9ca3af; border-radius: 8px; '
    'box-sizing: border-box; padding: 0 70px 0 14px; background: #ffffff; font-size: 16px; $_font';
const _visibilityButtonStyle =
    'position: absolute; right: 5px; top: 97px; height: 38px; border: 0; '
    'border-radius: 6px; padding: 0 10px; background: transparent; cursor: pointer; '
    'font-size: 13px; font-weight: 600; color: #102f55;';
const _submitButtonStyle =
    'width: 100%; height: 50px; border: 0; border-radius: 24px; padding: 0 20px; '
    'background: #102f55; color: #ffffff; cursor: pointer; font-size: 14px; '
    'font-weight: 600; font-family: Roboto, "Helvetica Neue", Arial, sans-serif;';
const _disabledSubmitButtonStyle =
    '$_submitButtonStyle opacity: 0.6; cursor: default;';
