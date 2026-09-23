import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

typedef CredentialSubmitCallback =
    Future<void> Function(String username, String password);

/// A persistent native HTML login form for browser password managers.
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

class _CredentialLoginFormState extends State<CredentialLoginForm> {
  web.HTMLFormElement? _form;
  web.HTMLButtonElement? _submitButton;
  web.HTMLButtonElement? _visibilityButton;
  web.EventListener? _submitListener;
  web.EventListener? _visibilityListener;
  bool _passwordVisible = false;
  bool _submissionInFlight = false;

  @override
  void didUpdateWidget(CredentialLoginForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy) _syncBusyState();
  }

  @override
  void dispose() {
    final form = _form;
    final submitListener = _submitListener;
    if (form != null && submitListener != null) {
      form.removeEventListener('submit', submitListener);
    }
    final visibilityButton = _visibilityButton;
    final visibilityListener = _visibilityListener;
    if (visibilityButton != null && visibilityListener != null) {
      visibilityButton.removeEventListener('click', visibilityListener);
    }
    super.dispose();
  }

  void _initializeForm(Object element) {
    final form = element as web.HTMLFormElement;
    form
      ..id = 'campusid-login-form'
      ..method = 'post'
      ..autocomplete = 'on'
      ..setAttribute('aria-label', 'CampusID sign in')
      ..setAttribute('style', _formStyle);

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
    form.addEventListener('submit', submitListener);

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
    visibilityButton.addEventListener('click', visibilityListener);

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
    _submitListener = submitListener;
    _visibilityListener = visibilityListener;
    _syncBusyState();
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
      if (mounted) _syncBusyState();
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

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 220,
    child: HtmlElementView.fromTagName(
      key: const ValueKey('campusid-native-login-form'),
      tagName: 'form',
      onElementCreated: _initializeForm,
    ),
  );
}

const _font =
    "font-family: Roboto, 'Helvetica Neue', Arial, sans-serif; color: #1f2937;";
const _formStyle =
    'position: relative; width: 100%; height: 100%; margin: 0; display: flex; '
    'flex-direction: column; box-sizing: border-box; $_font';
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
