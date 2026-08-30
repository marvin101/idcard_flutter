import 'package:flutter/material.dart';

import '../models/academic_session.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_button.dart';
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

      if (!mounted) return;

      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _addSession() async {
    final result = await showDialog<_SessionFormResult>(
      context: context,
      builder: (_) => const _SessionFormDialog(),
    );
    if (result == null) return;

    try {
      await widget.api.createAcademicSession(
        schoolUuid: widget.schoolUuid,
        name: result.name,
        startDate: result.startDate,
        endDate: result.endDate,
        isCurrent: result.isCurrent,
      );
      if (!mounted) return;
      _showMessage('Academic session created.');
      await _loadSessions();
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message, error: true);
    }
  }

  Future<void> _editSession(AcademicSession session) async {
    final result = await showDialog<_SessionFormResult>(
      context: context,
      builder: (_) => _SessionFormDialog(session: session),
    );
    if (result == null) return;

    setState(() => _busySessionId = session.uuid);
    try {
      await widget.api.updateAcademicSession(
        schoolUuid: widget.schoolUuid,
        sessionUuid: session.uuid,
        name: result.name,
        startDate: result.startDate,
        endDate: result.endDate,
        isCurrent: result.isCurrent,
      );
      if (!mounted) return;
      _showMessage('Academic session updated.');
      await _loadSessions();
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busySessionId = null);
    }
  }

  Future<void> _setCurrent(AcademicSession session) async {
    if (session.isCurrent) return;
    setState(() => _busySessionId = session.uuid);
    try {
      await widget.api.updateAcademicSession(
        schoolUuid: widget.schoolUuid,
        sessionUuid: session.uuid,
        name: session.name,
        startDate: session.startDate,
        endDate: session.endDate,
        isCurrent: true,
      );
      if (!mounted) return;
      _showMessage('${session.name} is now the current session.');
      await _loadSessions();
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busySessionId = null);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _sessions.where((session) => session.isCurrent).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AuthenticatedAppBar(
        title: Row(
          children: [
            Icon(Icons.calendar_month_outlined),
            SizedBox(width: 10),
            Text('Academic Sessions'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: constraints.maxWidth > 900 ? 48 : 20,
              vertical: 32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schools  /  ${widget.schoolName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Academic sessions',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Create and manage the academic years used by this school.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.canManage)
                          SizedBox(
                            width: 170,
                            child: AppButton(
                              text: 'Add session',
                              icon: Icons.add,
                              onPressed: _addSession,
                              height: 46,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SummaryCard(
                      total: _sessions.length,
                      currentName: current.isEmpty ? null : current.first.name,
                    ),
                    const SizedBox(height: 24),
                    _buildContent(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_loadError != null) {
      return _StateCard(
        icon: Icons.error_outline,
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
        title: 'No academic sessions yet',
        message: widget.canManage
            ? 'Create the first academic session for this school.'
            : 'No academic sessions have been configured for this school.',
        action: widget.canManage
            ? OutlinedButton.icon(
                onPressed: _addSession,
                icon: const Icon(Icons.add),
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
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 188,
          ),
          itemCount: _sessions.length,
          itemBuilder: (_, index) => _SessionCard(
            session: _sessions[index],
            canManage: widget.canManage,
            busy: _busySessionId == _sessions[index].uuid,
            onEdit: () => _editSession(_sessions[index]),
            onSetCurrent: () => _setCurrent(_sessions[index]),
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.total, required this.currentName});

  final int total;
  final String? currentName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe4e8f0)),
      ),
      child: Wrap(
        spacing: 36,
        runSpacing: 20,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Metric(value: '$total', label: 'Total sessions'),
          _Metric(
            value: currentName ?? 'None',
            label: 'Current session',
            wide: true,
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, this.wide = false});

  final String value;
  final String label;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: wide ? 360 : 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
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
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: session.isCurrent ? AppColors.accent : const Color(0xffe4e8f0),
          width: session.isCurrent ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (session.isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffe8edff),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'CURRENT',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.date_range_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  _dateRange(session),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: session.isCurrent
                        ? const SizedBox.shrink()
                        : OutlinedButton.icon(
                            onPressed: busy ? null : onSetCurrent,
                            icon: busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                  ),
                            label: const Text('Set current'),
                          ),
                  ),
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
    if (start == null && end == null) return 'Dates not specified';
    if (start == null) return 'Until ${end!}';
    if (end == null) return 'From $start';
    return '$start  –  $end';
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe4e8f0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.accent),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
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
    if (date == null) return;
    setState(() => _startDate = date);
  }

  Future<void> _pickEndDate() async {
    final date = await _pickDate(_endDate);
    if (date == null) return;
    setState(() => _endDate = date);
  }

  Future<DateTime?> _pickDate(DateTime? initial) => showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now(),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

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
              children: [
                TextFormField(
                  controller: _nameController,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: 'Session name',
                    hintText: 'e.g. 2026–27',
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
                  onClear: () => setState(() => _startDate = null),
                ),
                const SizedBox(height: 12),
                _DateField(
                  label: 'End date',
                  value: _endDate,
                  onTap: _pickEndDate,
                  onClear: () => setState(() => _endDate = null),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isCurrent,
                  onChanged: (value) =>
                      setState(() => _isCurrent = value ?? false),
                  title: const Text('Set as current session'),
                  subtitle: const Text(
                    'Any other current session for this school will be unset automatically.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
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
      borderRadius: BorderRadius.circular(8),
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

  String _format(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
