import 'package:flutter/material.dart';

import '../models/school_class.dart';
import '../models/section.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_button.dart';

class ClassesSectionsScreen extends StatefulWidget {
  const ClassesSectionsScreen({
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
  State<ClassesSectionsScreen> createState() => _ClassesSectionsScreenState();
}

class _ClassesSectionsScreenState extends State<ClassesSectionsScreen> {
  List<SchoolClass> _classes = const [];
  List<SchoolSection> _sections = const [];
  SchoolClass? _selectedClass;
  bool _loadingClasses = true;
  bool _loadingSections = false;
  String? _classError;
  String? _sectionError;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses({String? selectUuid}) async {
    setState(() {
      _loadingClasses = true;
      _classError = null;
    });

    try {
      final data = await widget.api.getClasses(widget.schoolUuid);
      final classes = data
          .whereType<Map<String, dynamic>>()
          .map(SchoolClass.fromJson)
          .toList();

      SchoolClass? next;
      if (selectUuid != null) {
        for (final item in classes) {
          if (item.uuid == selectUuid) {
            next = item;
            break;
          }
        }
      }
      next ??= _selectedClass == null
          ? (classes.isEmpty ? null : classes.first)
          : classes.where((item) => item.uuid == _selectedClass!.uuid).firstOrNull;
      next ??= classes.isEmpty ? null : classes.first;

      if (!mounted) return;
      setState(() {
        _classes = classes;
        _selectedClass = next;
        _loadingClasses = false;
      });

      await _loadSections(next);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingClasses = false;
        _classError = e.message;
        _selectedClass = null;
        _sections = const [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingClasses = false;
        _classError = e.toString();
      });
    }
  }

  Future<void> _loadSections(SchoolClass? schoolClass) async {
    if (schoolClass == null) {
      if (mounted) setState(() => _sections = const []);
      return;
    }

    setState(() {
      _loadingSections = true;
      _sectionError = null;
    });

    try {
      final data = await widget.api.getSections(
        schoolUuid: widget.schoolUuid,
        classUuid: schoolClass.uuid,
      );
      final sections = data
          .whereType<Map<String, dynamic>>()
          .map(SchoolSection.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _sections = sections;
        _loadingSections = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSections = false;
        _sectionError = e.message;
        _sections = const [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSections = false;
        _sectionError = e.toString();
      });
    }
  }

  void _selectClass(SchoolClass schoolClass) {
    setState(() => _selectedClass = schoolClass);
    _loadSections(schoolClass);
  }

  Future<void> _addClass() async {
    final name = await _showNameDialog(title: 'Add class', label: 'Class name');
    if (name == null) return;
    try {
      final created = await widget.api.createClass(
        schoolUuid: widget.schoolUuid,
        name: name,
      );
      await _loadClasses(selectUuid: created['uuid'] as String?);
      if (mounted) _showMessage('Class created.');
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message, error: true);
    }
  }

  Future<void> _editClass(SchoolClass schoolClass) async {
    final name = await _showNameDialog(
      title: 'Edit class',
      label: 'Class name',
      initialValue: schoolClass.name,
    );
    if (name == null) return;
    setState(() => _busyId = schoolClass.uuid);
    try {
      await widget.api.updateClass(
        schoolUuid: widget.schoolUuid,
        classUuid: schoolClass.uuid,
        name: name,
      );
      await _loadClasses(selectUuid: schoolClass.uuid);
      if (mounted) _showMessage('Class updated.');
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _deleteClass(SchoolClass schoolClass) async {
    final confirmed = await _confirm(
      title: 'Delete class?',
      message: 'Delete ${schoolClass.name}? This cannot be undone.',
    );
    if (!confirmed) return;
    setState(() => _busyId = schoolClass.uuid);
    try {
      await widget.api.deleteClass(
        schoolUuid: widget.schoolUuid,
        classUuid: schoolClass.uuid,
      );
      await _loadClasses();
      if (mounted) _showMessage('Class deleted.');
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _addSection() async {
    final schoolClass = _selectedClass;
    if (schoolClass == null) return;
    final name = await _showNameDialog(title: 'Add section', label: 'Section name');
    if (name == null) return;
    try {
      await widget.api.createSection(
        schoolUuid: widget.schoolUuid,
        classUuid: schoolClass.uuid,
        name: name,
      );
      await _loadSections(schoolClass);
      if (mounted) _showMessage('Section created.');
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message, error: true);
    }
  }

  Future<void> _editSection(SchoolSection section) async {
    final schoolClass = _selectedClass;
    if (schoolClass == null) return;
    final name = await _showNameDialog(
      title: 'Edit section',
      label: 'Section name',
      initialValue: section.name,
    );
    if (name == null) return;
    setState(() => _busyId = section.uuid);
    try {
      await widget.api.updateSection(
        schoolUuid: widget.schoolUuid,
        classUuid: schoolClass.uuid,
        sectionUuid: section.uuid,
        name: name,
      );
      await _loadSections(schoolClass);
      if (mounted) _showMessage('Section updated.');
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _deleteSection(SchoolSection section) async {
    final schoolClass = _selectedClass;
    if (schoolClass == null) return;
    final confirmed = await _confirm(
      title: 'Delete section?',
      message: 'Delete section ${section.name}? This cannot be undone.',
    );
    if (!confirmed) return;
    setState(() => _busyId = section.uuid);
    try {
      await widget.api.deleteSection(
        schoolUuid: widget.schoolUuid,
        classUuid: schoolClass.uuid,
        sectionUuid: section.uuid,
      );
      await _loadSections(schoolClass);
      if (mounted) _showMessage('Section deleted.');
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<String?> _showNameDialog({
    required String title,
    required String label,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: label),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Enter a name.';
              return null;
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _confirm({required String title, required String message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.account_tree_outlined),
            SizedBox(width: 10),
            Text('Classes & Sections'),
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
                                'Classes & Sections',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Organize the classes and sections used by this school.',
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
                            width: 155,
                            child: AppButton(
                              text: 'Add class',
                              icon: Icons.add,
                              onPressed: _addClass,
                              height: 46,
                            ),
                          ),
                      ],
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
    if (_loadingClasses) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_classError != null) {
      return _StateCard(
        icon: Icons.error_outline,
        title: 'Unable to load classes',
        message: _classError!,
        action: OutlinedButton.icon(
          onPressed: _loadClasses,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    if (_classes.isEmpty) {
      return _StateCard(
        icon: Icons.account_tree_outlined,
        title: 'No classes yet',
        message: widget.canManage
            ? 'Create the first class for this school.'
            : 'No classes have been configured for this school.',
        action: widget.canManage
            ? OutlinedButton.icon(
                onPressed: _addClass,
                icon: const Icon(Icons.add),
                label: const Text('Add class'),
              )
            : null,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 800) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: _classesPanel()),
              const SizedBox(width: 20),
              Expanded(flex: 6, child: _sectionsPanel()),
            ],
          );
        }
        return Column(
          children: [
            _classesPanel(),
            const SizedBox(height: 20),
            _sectionsPanel(),
          ],
        );
      },
    );
  }

  Widget _classesPanel() {
    return _Panel(
      title: 'Classes',
      count: _classes.length,
      child: Column(
        children: _classes.map((schoolClass) {
          final selected = _selectedClass?.uuid == schoolClass.uuid;
          final busy = _busyId == schoolClass.uuid;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: selected ? AppColors.primary.withAlpha(20) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: busy ? null : () => _selectClass(schoolClass),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : const Color(0xffeef1f7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.class_outlined,
                          size: 20,
                          color: selected ? Colors.white : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          schoolClass.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (widget.canManage) ...[
                        IconButton(
                          tooltip: 'Edit class',
                          onPressed: busy ? null : () => _editClass(schoolClass),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Delete class',
                          onPressed: busy ? null : () => _deleteClass(schoolClass),
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                      ] else if (selected)
                        const Icon(Icons.chevron_right, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionsPanel() {
    final schoolClass = _selectedClass;
    return _Panel(
      title: schoolClass == null ? 'Sections' : 'Sections · ${schoolClass.name}',
      count: _sections.length,
      action: widget.canManage && schoolClass != null
          ? TextButton.icon(
              onPressed: _addSection,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add section'),
            )
          : null,
      child: schoolClass == null
          ? const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: Text('Select a class to view its sections.')),
            )
          : _buildSectionsContent(),
    );
  }

  Widget _buildSectionsContent() {
    if (_loadingSections) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_sectionError != null) {
      return _StateCard(
        icon: Icons.error_outline,
        title: 'Unable to load sections',
        message: _sectionError!,
        action: OutlinedButton.icon(
          onPressed: () => _loadSections(_selectedClass),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }
    if (_sections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const Icon(Icons.layers_outlined, size: 38, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            const Text('No sections yet', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(
              widget.canManage ? 'Add a section to this class.' : 'No sections have been configured.',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (widget.canManage) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _addSection,
                icon: const Icon(Icons.add),
                label: const Text('Add section'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: _sections.map((section) {
        final busy = _busyId == section.uuid;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xfff8f9fc),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffe4e8f0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(23),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    section.name.isEmpty ? '?' : section.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(section.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (widget.canManage) ...[
                  IconButton(
                    tooltip: 'Edit section',
                    onPressed: busy ? null : () => _editSection(section),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Delete section',
                    onPressed: busy ? null : () => _deleteSection(section),
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.count, required this.child, this.action});

  final String title;
  final int count;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe4e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xffeef1f7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.icon, required this.title, required this.message, this.action});

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
          Icon(icon, size: 42, color: AppColors.textSecondary),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
