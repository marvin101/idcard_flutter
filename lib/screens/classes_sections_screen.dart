import 'package:flutter/material.dart';

import '../models/school_class.dart';
import '../models/section.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/authenticated_app_bar.dart';

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
      final classes = await widget.api.getClasses(widget.schoolUuid);

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
          : classes
                .where((item) => item.uuid == _selectedClass!.uuid)
                .firstOrNull;

      next ??= classes.isEmpty ? null : classes.first;

      if (!mounted) {
        return;
      }

      setState(() {
        _classes = classes;
        _selectedClass = next;
        _loadingClasses = false;
      });

      await _loadSections(next);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingClasses = false;
        _classError = e.message;
        _selectedClass = null;
        _sections = const [];
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingClasses = false;
        _classError = e.toString();
      });
    }
  }

  Future<void> _loadSections(SchoolClass? schoolClass) async {
    if (schoolClass == null) {
      if (mounted) {
        setState(() {
          _sections = const [];
        });
      }

      return;
    }

    setState(() {
      _loadingSections = true;
      _sectionError = null;
    });

    try {
      final sections = await widget.api.getSections(
        schoolUuid: widget.schoolUuid,
        classUuid: schoolClass.uuid,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _sections = sections;
        _loadingSections = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingSections = false;
        _sectionError = e.message;
        _sections = const [];
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingSections = false;
        _sectionError = e.toString();
      });
    }
  }

  void _selectClass(SchoolClass schoolClass) {
    setState(() {
      _selectedClass = schoolClass;
    });

    _loadSections(schoolClass);
  }

  Future<void> _addClass() async {
    final name = await _showNameDialog(title: 'Add class', label: 'Class name');

    if (name == null) {
      return;
    }

    try {
      final created = await widget.api.createClass(
        schoolUuid: widget.schoolUuid,
        name: name,
      );

      await _loadClasses(selectUuid: created['uuid'] as String?);

      if (mounted) {
        _showMessage('Class created.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        _showMessage(e.message, error: true);
      }
    }
  }

  Future<void> _editClass(SchoolClass schoolClass) async {
    final name = await _showNameDialog(
      title: 'Edit class',
      label: 'Class name',
      initialValue: schoolClass.name,
    );

    if (name == null) {
      return;
    }

    setState(() {
      _busyId = schoolClass.uuid;
    });

    try {
      await widget.api.updateClass(
        schoolUuid: widget.schoolUuid,
        classUuid: schoolClass.uuid,
        name: name,
      );

      await _loadClasses(selectUuid: schoolClass.uuid);

      if (mounted) {
        _showMessage('Class updated.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        _showMessage(e.message, error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyId = null;
        });
      }
    }
  }

  Future<void> _deleteClass(SchoolClass schoolClass) async {
    final confirmed = await _confirm(
      title: 'Delete class?',
      message: 'Delete ${schoolClass.name}? This cannot be undone.',
    );

    if (!confirmed) {
      return;
    }

    setState(() {
      _busyId = schoolClass.uuid;
    });

    try {
      await widget.api.deleteClass(
        schoolUuid: widget.schoolUuid,
        classUuid: schoolClass.uuid,
      );

      await _loadClasses();

      if (mounted) {
        _showMessage('Class deleted.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        _showMessage(e.message, error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyId = null;
        });
      }
    }
  }

  Future<void> _addSection() async {
    final schoolClass = _selectedClass;

    if (schoolClass == null) {
      return;
    }

    final name = await _showNameDialog(
      title: 'Add section',
      label: 'Section name',
    );

    if (name == null) {
      return;
    }

    try {
      await widget.api.createSection(
        schoolUuid: widget.schoolUuid,
        classUuid: schoolClass.uuid,
        name: name,
      );

      await _loadSections(schoolClass);

      if (mounted) {
        _showMessage('Section created.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        _showMessage(e.message, error: true);
      }
    }
  }

  Future<void> _editSection(SchoolSection section) async {
    final schoolClass = _selectedClass;

    if (schoolClass == null) {
      return;
    }

    final name = await _showNameDialog(
      title: 'Edit section',
      label: 'Section name',
      initialValue: section.name,
    );

    if (name == null) {
      return;
    }

    setState(() {
      _busyId = section.uuid;
    });

    try {
      await widget.api.updateSection(
        schoolUuid: widget.schoolUuid,
        classUuid: schoolClass.uuid,
        sectionUuid: section.uuid,
        name: name,
      );

      await _loadSections(schoolClass);

      if (mounted) {
        _showMessage('Section updated.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        _showMessage(e.message, error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyId = null;
        });
      }
    }
  }

  Future<void> _deleteSection(SchoolSection section) async {
    final schoolClass = _selectedClass;

    if (schoolClass == null) {
      return;
    }

    final confirmed = await _confirm(
      title: 'Delete section?',
      message: 'Delete section ${section.name}? This cannot be undone.',
    );

    if (!confirmed) {
      return;
    }

    setState(() {
      _busyId = section.uuid;
    });

    try {
      await widget.api.deleteSection(
        schoolUuid: widget.schoolUuid,
        classUuid: schoolClass.uuid,
        sectionUuid: section.uuid,
      );

      await _loadSections(schoolClass);

      if (mounted) {
        _showMessage('Section deleted.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        _showMessage(e.message, error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyId = null;
        });
      }
    }
  }

  Future<String?> _showNameDialog({
    required String title,
    required String label,
    String initialValue = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) =>
          _NameDialog(title: title, label: label, initialValue: initialValue),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
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
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AuthenticatedAppBar(
        title: Text('Classes & Sections — ${widget.schoolName}'),
      ),
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
              'Classes & sections',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Organize the classes and sections used by '
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
                key: const Key('add-class-action'),
                onPressed: _addClass,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add class'),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;

        final classCard = _SummaryMetricCard(
          icon: Icons.account_tree_outlined,
          label: 'Total classes',
          value: '${_classes.length}',
          accentColor: AppColors.accent,
          backgroundColor: AppColors.accentSoft,
        );

        final sectionCard = _SummaryMetricCard(
          icon: Icons.layers_outlined,
          label: _selectedClass == null
              ? 'Sections'
              : '${_selectedClass!.name} sections',
          value: _loadingSections ? '...' : '${_sections.length}',
          accentColor: AppColors.success,
          backgroundColor: AppColors.successSoft,
        );

        if (compact) {
          return Column(
            children: [classCard, const SizedBox(height: 12), sectionCard],
          );
        }

        return Row(
          children: [
            Expanded(child: classCard),
            const SizedBox(width: 14),
            Expanded(child: sectionCard),
          ],
        );
      },
    );
  }

  Widget _buildContent() {
    if (_loadingClasses) {
      return const _LoadingState(message: 'Loading classes and sections...');
    }

    if (_classError != null) {
      return _StateCard(
        icon: Icons.error_outline,
        iconColor: AppColors.danger,
        iconBackground: AppColors.dangerSoft,
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
        iconColor: AppColors.accent,
        iconBackground: AppColors.accentSoft,
        title: 'No classes yet',
        message: widget.canManage
            ? 'Create the first class for this school to start organizing sections.'
            : 'No classes have been configured for this school.',
        action: widget.canManage
            ? FilledButton.icon(
                onPressed: _addClass,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add class'),
              )
            : null,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 820) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: _classesPanel()),
              const SizedBox(width: 18),
              Expanded(flex: 6, child: _sectionsPanel()),
            ],
          );
        }

        return Column(
          children: [
            _classesPanel(),
            const SizedBox(height: 18),
            _sectionsPanel(),
          ],
        );
      },
    );
  }

  Widget _classesPanel() {
    return _Panel(
      icon: Icons.account_tree_outlined,
      title: 'Classes',
      subtitle: 'Select a class to manage its sections.',
      count: _classes.length,
      child: Column(
        children: _classes.map((schoolClass) {
          final selected = _selectedClass?.uuid == schoolClass.uuid;

          final busy = _busyId == schoolClass.uuid;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ClassTile(
              schoolClass: schoolClass,
              selected: selected,
              busy: busy,
              canManage: widget.canManage,
              onTap: () => _selectClass(schoolClass),
              onEdit: () => _editClass(schoolClass),
              onDelete: () => _deleteClass(schoolClass),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionsPanel() {
    final schoolClass = _selectedClass;

    return _Panel(
      icon: Icons.layers_outlined,
      title: schoolClass == null
          ? 'Sections'
          : 'Sections · ${schoolClass.name}',
      subtitle: schoolClass == null
          ? 'Choose a class to view its sections.'
          : 'Manage sections within ${schoolClass.name}.',
      count: _sections.length,
      action: widget.canManage && schoolClass != null
          ? TextButton.icon(
              key: const Key('add-section-action'),
              onPressed: _addSection,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add section'),
            )
          : null,
      child: schoolClass == null
          ? const _PanelEmptyMessage(
              icon: Icons.touch_app_outlined,
              title: 'Select a class',
              message: 'Choose a class from the list to view its sections.',
            )
          : _buildSectionsContent(),
    );
  }

  Widget _buildSectionsContent() {
    if (_loadingSections) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_sectionError != null) {
      return _InlineState(
        icon: Icons.error_outline,
        iconColor: AppColors.danger,
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
      return _InlineState(
        icon: Icons.layers_outlined,
        iconColor: AppColors.accent,
        title: 'No sections yet',
        message: widget.canManage
            ? 'Add the first section to this class.'
            : 'No sections have been configured for this class.',
        action: widget.canManage
            ? OutlinedButton.icon(
                onPressed: _addSection,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add section'),
              )
            : null,
      );
    }

    return Column(
      children: _sections.map((section) {
        final busy = _busyId == section.uuid;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SectionTile(
            section: section,
            busy: busy,
            canManage: widget.canManage,
            onEdit: () => _editSection(section),
            onDelete: () => _deleteSection(section),
          ),
        );
      }).toList(),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

class _ClassTile extends StatelessWidget {
  const _ClassTile({
    required this.schoolClass,
    required this.selected,
    required this.busy,
    required this.canManage,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final SchoolClass schoolClass;
  final bool selected;
  final bool busy;
  final bool canManage;

  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentSoft : AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : AppColors.surface,
                  borderRadius: BorderRadius.circular(11),
                  border: selected ? null : Border.all(color: AppColors.border),
                ),
                child: Icon(
                  Icons.class_outlined,
                  size: 20,
                  color: selected ? Colors.white : AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  schoolClass.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (canManage) ...[
                IconButton(
                  tooltip: 'Edit class',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 19),
                ),
                IconButton(
                  tooltip: 'Delete class',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: AppColors.danger,
                  ),
                ),
              ] else
                Icon(
                  Icons.chevron_right_rounded,
                  color: selected ? AppColors.accent : AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.section,
    required this.busy,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final SchoolSection section;
  final bool busy;
  final bool canManage;

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final initial = section.name.trim().isEmpty
        ? '?'
        : section.name.trim().substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.successSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Section',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (canManage) ...[
            IconButton(
              tooltip: 'Edit section',
              visualDensity: VisualDensity.compact,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 19),
            ),
            IconButton(
              tooltip: 'Delete section',
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
                size: 19,
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.child,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;

  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _PanelEmptyMessage extends StatelessWidget {
  const _PanelEmptyMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 34),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineState extends StatelessWidget {
  const _InlineState({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.message});

  final String message;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 14),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
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

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.label,
    required this.initialValue,
  });

  final String title;
  final String label;
  final String initialValue;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: widget.label,
              prefixIcon: const Icon(Icons.label_outline),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter a name.';
              }

              return null;
            },
            onFieldSubmitted: (_) => _save(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
