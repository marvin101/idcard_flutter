import 'package:flutter/material.dart';

import '../models/public_verification.dart';
import '../services/api_service.dart';

class PublicVerificationSettingsButton extends StatelessWidget {
  const PublicVerificationSettingsButton({
    super.key,
    required this.schoolUuid,
    required this.api,
  });

  final String schoolUuid;
  final ApiService api;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('public-verification-settings'),
    tooltip: 'Student verification links',
    icon: const Icon(Icons.verified_user_outlined),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) =>
          _VerificationSettingsDialog(schoolUuid: schoolUuid, api: api),
    ),
  );
}

class _VerificationSettingsDialog extends StatefulWidget {
  const _VerificationSettingsDialog({
    required this.schoolUuid,
    required this.api,
  });

  final String schoolUuid;
  final ApiService api;

  @override
  State<_VerificationSettingsDialog> createState() =>
      _VerificationSettingsDialogState();
}

class _VerificationSettingsDialogState
    extends State<_VerificationSettingsDialog> {
  PublicVerificationSettings? _settings;
  Object? _error;
  bool _saving = false;
  bool _enabled = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await widget.api.getPublicVerificationSettings(
        widget.schoolUuid,
      );
      if (!mounted) return;
      setState(() {
        _settings = value;
        _enabled = value.enabled;
        _selected
          ..clear()
          ..addAll(value.fields);
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  Future<void> _save() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.api.updatePublicVerificationSettings(
        schoolUuid: widget.schoolUuid,
        enabled: _enabled,
        fields: _selected.toList(),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Student verification links'),
    content: SizedBox(
      width: 480,
      child: _settings == null
          ? _error == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Unable to load verification settings.'),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    key: const Key('public-verification-enabled'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable public verification'),
                    subtitle: const Text(
                      'QR links work only while this setting is enabled.',
                    ),
                    value: _enabled,
                    onChanged: (value) => setState(() => _enabled = value),
                  ),
                  const Divider(),
                  const Text(
                    'Information shown after scanning',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Only these school-approved fields are disclosed.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  for (final field in _settings!.availableFields)
                    CheckboxListTile(
                      key: Key('public-verification-field-${field.key}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(field.label),
                      value: _selected.contains(field.key),
                      onChanged:
                          _selected.length == 1 && _selected.contains(field.key)
                          ? null
                          : (selected) => setState(() {
                              if (selected == true) {
                                _selected.add(field.key);
                              } else {
                                _selected.remove(field.key);
                              }
                            }),
                    ),
                  if (_error != null)
                    const Text(
                      'Could not save the settings. Please try again.',
                      style: TextStyle(color: Colors.red),
                    ),
                ],
              ),
            ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('save-public-verification-settings'),
        onPressed: _settings == null || _saving || _selected.isEmpty
            ? null
            : _save,
        child: Text(_saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
}
