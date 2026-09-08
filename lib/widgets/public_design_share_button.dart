import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_routes.dart';
import '../models/public_design.dart';
import '../services/api_service.dart';

class PublicDesignShareButton extends StatelessWidget {
  const PublicDesignShareButton({
    super.key,
    required this.schoolUuid,
    required this.api,
  });

  final String schoolUuid;
  final ApiService api;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('public-design-share'),
    tooltip: 'Share saved design',
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) =>
          _PublicDesignShareDialog(schoolUuid: schoolUuid, api: api),
    ),
    icon: const Icon(Icons.share_outlined),
  );
}

class _PublicDesignShareDialog extends StatefulWidget {
  const _PublicDesignShareDialog({required this.schoolUuid, required this.api});

  final String schoolUuid;
  final ApiService api;

  @override
  State<_PublicDesignShareDialog> createState() =>
      _PublicDesignShareDialogState();
}

class _PublicDesignShareDialogState extends State<_PublicDesignShareDialog> {
  PublicDesignShare? _share;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _share = await widget.api.getPublicDesignShare(widget.schoolUuid);
    } catch (error) {
      _error = error.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  String? get _link {
    final token = _share?.publicToken;
    return token == null
        ? null
        : Uri.base.resolve(AppRoutes.publicDesign(token)).toString();
  }

  Future<void> _setEnabled(bool enabled) async {
    if (!enabled && _share?.enabled == true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Disable public preview?'),
          content: const Text(
            'The current link will stop working immediately.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Disable'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _mutate(
      () => widget.api.updatePublicDesignShare(
        schoolUuid: widget.schoolUuid,
        enabled: enabled,
      ),
    );
  }

  Future<void> _regenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate public link?'),
        content: const Text('The current link will stop working immediately.'),
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
    if (confirmed != true) return;
    await _mutate(
      () => widget.api.regeneratePublicDesignShare(widget.schoolUuid),
    );
  }

  Future<void> _mutate(Future<PublicDesignShare> Function() operation) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      _share = await operation();
    } catch (error) {
      _error = error.toString();
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Share saved design'),
    content: SizedBox(
      width: 520,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'The link shows the latest saved design with sample student details. Unsaved edits and real student records are never included.',
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  key: const Key('public-design-enabled'),
                  contentPadding: EdgeInsets.zero,
                  value: _share?.enabled ?? false,
                  onChanged: _saving ? null : _setEnabled,
                  title: const Text('Public preview enabled'),
                ),
                if (_share?.enabled == true && _link != null) ...[
                  const SizedBox(height: 8),
                  SelectableText(_link!, key: const Key('public-design-link')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: _link!),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Link copied.'),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy link'),
                      ),
                      TextButton(
                        onPressed: _saving ? null : _regenerate,
                        child: const Text('Regenerate link'),
                      ),
                    ],
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}
