import 'package:flutter/material.dart';

import '../models/academic_session.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/authenticated_app_bar.dart';

class AcademicSessionsScreen extends StatefulWidget {
  const AcademicSessionsScreen({
    super.key,
    required this.schoolUuid,
    required this.schoolName,
    required this.api,
    required this.canManage,
  });

  final String schoolUuid;
  final String schoolName;
  final ApiService api;
  final bool canManage;

  @override
  State<AcademicSessionsScreen> createState() => _AcademicSessionsScreenState();
}

class _AcademicSessionsScreenState extends State<AcademicSessionsScreen> {
  List<AcademicSession> _sessions = const [];

  bool _loading = true;
  String? _loadError;
  String? _busySessionId;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final sessions = await widget.api.getAcademicSessions(widget.schoolUuid);

      if (!mounted) {
        return;
      }

      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _loadError = e.message;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _addSession() async {
    final result = await showDialog<_SessionFormResult>(
      context: context,
      builder: (context) => const _SessionFormDialog(),
    );

    if (result == null) {
      return;
    }

    try {
      await widget.api.createAcademicSession(
        schoolUuid: widget.schoolUuid,
        name: result.name,
        startDate: result.startDate,
        endDate: result.endDate,
        isCurrent: result.isCurrent,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Academic session created.');

      await _loadSessions();
    } on ApiException catch (e) {
      if (mounted) {
        _showMessage(e.message, error: true);
      }
    }
  }

  Future<void> _editSession(AcademicSession session) async {
    final result = await showDialog<_SessionFormResult>(
      context: context,
      builder: (context) => _SessionFormDialog(session: session),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _busySessionId = session.uuid;
    });

    try {
      await widget.api.updateAcademicSession(
        schoolUuid: widget.schoolUuid,
        sessionUuid: session.uuid,
        name: result.name,
        startDate: result.startDate,
        endDate: result.endDate,
        isCurrent: result.isCurrent,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Academic session updated.');

      await _loadSessions();
    } on ApiException catch (e) {
      if (mounted) {
        _showMessage(e.message, error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busySessionId = null;
        });
      }
    }
  }

  Future<void> _setCurrent(AcademicSession session) async {
    if (session.isCurrent) {
      return;
    }

    setState(() {
      _busySessionId = session.uuid;
    });

    try {
      await widget.api.updateAcademicSession(
        schoolUuid: widget.schoolUuid,
        sessionUuid: session.uuid,
        name: session.name,
        startDate: session.startDate,
        endDate: session.endDate,
        isCurrent: true,
      );

      if (!mounted) {
        return;
      }

      _showMessage('${session.name} is now the current session.');

      await _loadSessions();
    } on ApiException catch (e) {
      if (mounted) {
        _showMessage(e.message, error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busySessionId = null;
        });
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  AcademicSession? get _currentSession {
    for (final session in _sessions) {
      if (session.isCurrent) {
        return session;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AuthenticatedAppBar(title: Text('Academic Sessions')),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth > 900 ? 48.0 : 20.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPageHeading(),
                      const SizedBox(height: 22),
                      _buildSummary(),
                      const SizedBox(height: 24),
                      _buildSectionHeading(),
                      const SizedBox(height: 14),
                      _buildContent(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPageHeading() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;

        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Academic sessions',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Manage the academic years and current session for '
              '${widget.schoolName}.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        );

        final addButton = widget.canManage
            ? FilledButton.icon(
                key: const Key('add-academic-session'),
                onPressed: _addSession,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add session'),
              )
            : null;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              if (addButton != null) ...[
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: addButton),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: heading),
            ?addButton,
          ],
        );
      },
    );
  }

  Widget _buildSummary() {
    final current = _currentSession;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;

        final totalCard = _SummaryMetricCard(
          icon: Icons.calendar_month_outlined,
          label: 'Total sessions',
          value: '${_sessions.length}',
          accentColor: AppColors.accent,
          backgroundColor: AppColors.accentSoft,
        );

        final currentCard = _SummaryMetricCard(
          icon: Icons.check_circle_outline,
          label: 'Current session',
          value: current?.name ?? 'None',
          accentColor: AppColors.success,
          backgroundColor: AppColors.successSoft,
        );

        if (compact) {
          return Column(
            children: [totalCard, const SizedBox(height: 12), currentCard],
          );
        }

        return Row(
          children: [
            Expanded(child: totalCard),
            const SizedBox(width: 14),
            Expanded(child: currentCard),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeading() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sessions',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Review session dates and choose which academic year is active.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        if (!_loading && _loadError == null && _sessions.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_sessions.length} ${_sessions.length == 1 ? 'session' : 'sessions'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const _LoadingState();
    }

    if (_loadError != null) {
      return _StateCard(
        icon: Icons.error_outline,
        iconColor: AppColors.danger,
        iconBackground: AppColors.dangerSoft,
        title: 'Unable to load academic sessions',
        message: _loadError!,
        action: OutlinedButton.icon(
          onPressed: _loadSessions,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    if (_sessions.isEmpty) {
      return _StateCard(
        icon: Icons.calendar_today_outlined,
        iconColor: AppColors.accent,
        iconBackground: AppColors.accentSoft,
        title: 'No academic sessions yet',
        message: widget.canManage
            ? 'Create the first academic session for this school.'
            : 'No academic sessions have been configured for this school.',
        action: widget.canManage
            ? FilledButton.icon(
                onPressed: _addSession,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add session'),
              )
            : null,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 2 : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 202,
          ),
          itemCount: _sessions.length,
          itemBuilder: (context, index) {
            final session = _sessions[index];

            return _SessionCard(
              session: session,
              canManage: widget.canManage,
              busy: _busySessionId == session.uuid,
              onEdit: () => _editSession(session),
              onSetCurrent: () => _setCurrent(session),
            );
          },
        );
      },
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: accentColor, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.canManage,
    required this.busy,
    required this.onEdit,
    required this.onSetCurrent,
  });

  final AcademicSession session;
  final bool canManage;
  final bool busy;

  final VoidCallback onEdit;
  final VoidCallback onSetCurrent;

  @override
  Widget build(BuildContext context) {
    final borderColor = session.isCurrent
        ? AppColors.success
        : AppColors.border;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: borderColor,
          width: session.isCurrent ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: session.isCurrent
                        ? AppColors.successSoft
                        : AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    session.isCurrent
                        ? Icons.check_circle_outline
                        : Icons.calendar_month_outlined,
                    color: session.isCurrent
                        ? AppColors.success
                        : AppColors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.isCurrent
                            ? 'Active academic session'
                            : 'Academic session',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (session.isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'CURRENT',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.date_range_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _dateRange(session),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (canManage)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                  ),
                  if (!session.isCurrent) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: busy ? null : onSetCurrent,
                        icon: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Set current'),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _dateRange(AcademicSession session) {
    final start = _formatDate(session.startDate);

    final end = _formatDate(session.endDate);

    if (start == null && end == null) {
      return 'Dates not specified';
    }

    if (start == null) {
      return 'Until $end';
    }

    if (end == null) {
      return 'From $start';
    }

    return '$start - $end';
  }

  String? _formatDate(DateTime? date) {
    if (date == null) {
      return null;
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(42),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(height: 14),
          Text(
            'Loading academic sessions...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  final String title;
  final String message;

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, size: 29, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

class _SessionFormResult {
  const _SessionFormResult({
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
  });

  final String name;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isCurrent;
}

class _SessionFormDialog extends StatefulWidget {
  const _SessionFormDialog({this.session});

  final AcademicSession? session;

  @override
  State<_SessionFormDialog> createState() => _SessionFormDialogState();
}

class _SessionFormDialogState extends State<_SessionFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;

  DateTime? _startDate;
  DateTime? _endDate;

  late bool _isCurrent;

  bool get _editing => widget.session != null;

  @override
  void initState() {
    super.initState();

    final session = widget.session;

    _nameController = TextEditingController(text: session?.name ?? '');

    _startDate = session?.startDate;

    _endDate = session?.endDate;

    _isCurrent = session?.isCurrent ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final date = await _pickDate(_startDate);

    if (date == null) {
      return;
    }

    setState(() {
      _startDate = date;
    });
  }

  Future<void> _pickEndDate() async {
    final date = await _pickDate(_endDate);

    if (date == null) {
      return;
    }

    setState(() {
      _endDate = date;
    });
  }

  Future<DateTime?> _pickDate(DateTime? initial) {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date cannot be earlier than start date.'),
          backgroundColor: AppColors.danger,
        ),
      );

      return;
    }

    Navigator.of(context).pop(
      _SessionFormResult(
        name: _nameController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        isCurrent: _isCurrent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Edit academic session' : 'Add academic session'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: 'Session name',
                    hintText: 'e.g. 2026-27',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a session name.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _DateField(
                  label: 'Start date',
                  value: _startDate,
                  onTap: _pickStartDate,
                  onClear: () {
                    setState(() {
                      _startDate = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _DateField(
                  label: 'End date',
                  value: _endDate,
                  onTap: _pickEndDate,
                  onClear: () {
                    setState(() {
                      _endDate = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    value: _isCurrent,
                    onChanged: (value) {
                      setState(() {
                        _isCurrent = value ?? false;
                      });
                    },
                    title: const Text(
                      'Set as current session',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Any other current session for this school will be unset automatically.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_editing ? 'Save changes' : 'Create session'),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;

  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          suffixIcon: value == null
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: const Icon(Icons.clear),
                ),
        ),
        child: Text(
          value == null ? 'Not specified' : _format(value!),
          style: TextStyle(
            color: value == null
                ? AppColors.textSecondary
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  String _format(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
