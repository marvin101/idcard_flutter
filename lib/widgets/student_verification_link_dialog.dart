import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/public_verification.dart';
import '../services/api_service.dart';

Future<void> showStudentVerificationLinkDialog({
  required BuildContext context,
  required ApiService api,
  required String schoolUuid,
  required String studentUuid,
  required String studentName,
}) => showDialog<void>(
  context: context,
  builder: (_) => _StudentVerificationLinkDialog(
    api: api,
    schoolUuid: schoolUuid,
    studentUuid: studentUuid,
    studentName: studentName,
  ),
);

class _StudentVerificationLinkDialog extends StatefulWidget {
  const _StudentVerificationLinkDialog({
    required this.api,
    required this.schoolUuid,
    required this.studentUuid,
    required this.studentName,
  });

  final ApiService api;
  final String schoolUuid;
  final String studentUuid;
  final String studentName;

  @override
  State<_StudentVerificationLinkDialog> createState() =>
      _StudentVerificationLinkDialogState();
}

class _StudentVerificationLinkDialogState
    extends State<_StudentVerificationLinkDialog> {
  StudentVerificationLink? _link;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final link = await widget.api.getStudentVerificationLink(
        schoolUuid: widget.schoolUuid,
        studentUuid: widget.studentUuid,
      );
      if (mounted) {
        setState(() {
          _link = link;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    setState(() => _busy = true);
    try {
      final link = await widget.api.updateStudentVerificationLink(
        schoolUuid: widget.schoolUuid,
        studentUuid: widget.studentUuid,
        enabled: enabled,
      );
      if (mounted) {
        setState(() {
          _link = link;
          _busy = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  Future<void> _regenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate verification link?'),
        content: const Text(
          'The current link and any QR code containing it will stop working. Reprint the card after regenerating.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final link = await widget.api.regenerateStudentVerificationLink(
        schoolUuid: widget.schoolUuid,
        studentUuid: widget.studentUuid,
      );
      if (mounted) {
        setState(() {
          _link = link;
          _busy = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.studentName} verification'),
    content: SizedBox(
      width: 480,
      child: _link == null
          ? _error == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Unable to load the verification link.'),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  key: const Key('student-verification-enabled'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Link enabled'),
                  subtitle: const Text(
                    'Disable immediately revokes this student’s public page.',
                  ),
                  value: _link!.enabled,
                  onChanged: _busy ? null : _setEnabled,
                ),
                const SizedBox(height: 8),
                const Text('Verification URL'),
                const SizedBox(height: 6),
                SelectableText(_link!.verificationUrl ?? 'Unavailable'),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'The last change failed. Please try again.',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
    ),
    actions: [
      if (_link?.verificationUrl != null)
        TextButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  await Clipboard.setData(
                    ClipboardData(text: _link!.verificationUrl!),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Verification link copied')),
                    );
                  }
                },
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copy'),
        ),
      TextButton(
        key: const Key('regenerate-student-verification'),
        onPressed: _link == null || _busy ? null : _regenerate,
        child: const Text('Regenerate'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    ],
  );
}
