import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../services/api_service.dart';

/// A responsive school-scoped directory for managing user access.
///
/// The callbacks intentionally keep networking outside the widget: call the
/// corresponding `/users/.../schools/...` API endpoint from the parent.
class SchoolUserAssignmentScreen extends StatefulWidget {
  const SchoolUserAssignmentScreen({
    super.key,
    required this.schoolUuid,
    this.schoolName = 'Selected school',
    this.initialUsers = const [],
    this.api,
    this.useDemoData = false,
    this.canManageElevatedRoles = false,
    this.onAssign,
    this.onUpdateRole,
    this.onRevoke,
  });

  final String schoolUuid;
  final String schoolName;
  final List<SchoolUserAssignment> initialUsers;
  final ApiService? api;
  final bool useDemoData;
  final bool canManageElevatedRoles;
  final Future<void> Function(SchoolUserAssignment user, SchoolRole role)?
  onAssign;
  final Future<void> Function(SchoolUserAssignment user, SchoolRole role)?
  onUpdateRole;
  final Future<void> Function(SchoolUserAssignment user)? onRevoke;

  @override
  State<SchoolUserAssignmentScreen> createState() =>
      _SchoolUserAssignmentScreenState();
}

class _SchoolUserAssignmentScreenState
    extends State<SchoolUserAssignmentScreen> {
  late List<SchoolUserAssignment> _users;
  final TextEditingController _searchController = TextEditingController();
  AssignmentFilter _filter = AssignmentFilter.all;
  String? _busyUserId;
  bool _loadingUsers = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _users = List.of(widget.initialUsers);
    if (widget.api != null && _users.isEmpty) {
      _loadUsers();
    } else if (widget.useDemoData && _users.isEmpty) {
      _users = List.of(_demoUsers);
    }
    _searchController.addListener(_refresh);
  }

  Future<void> _loadUsers() async {
    final api = widget.api;
    if (api == null) return;
    setState(() {
      _loadingUsers = true;
      _loadError = null;
    });
    try {
      final result = await api.getSchoolAssignments(widget.schoolUuid);
      final users = result
          .whereType<Map<String, dynamic>>()
          .map(SchoolUserAssignment.fromJson)
          .toList();
      if (!mounted) return;
      setState(() => _users = users);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not load school users.');
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  List<SchoolUserAssignment> get _visibleUsers {
    final query = _searchController.text.trim().toLowerCase();
    return _users.where((user) {
      final matchesFilter = switch (_filter) {
        AssignmentFilter.all => true,
        AssignmentFilter.assigned => user.isAssigned,
        AssignmentFilter.unassigned => !user.isAssigned,
      };
      final matchesQuery =
          query.isEmpty ||
          user.name.toLowerCase().contains(query) ||
          user.username.toLowerCase().contains(query) ||
          (user.email?.toLowerCase().contains(query) ?? false) ||
          (user.designation?.toLowerCase().contains(query) ?? false);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  Future<void> _setRole(SchoolUserAssignment user, SchoolRole role) async {
    setState(() => _busyUserId = user.id);
    try {
      if (user.isAssigned) {
        if (widget.onUpdateRole != null) {
          await widget.onUpdateRole!.call(user, role);
        } else if (widget.api != null) {
          await widget.api!.updateSchoolAccess(
            userUuid: user.id,
            schoolUuid: widget.schoolUuid,
            role: role.apiValue,
          );
        } else {
          throw StateError('No assignment update handler configured.');
        }
      } else {
        if (widget.onAssign != null) {
          await widget.onAssign!.call(user, role);
        } else if (widget.api != null) {
          await widget.api!.createSchoolAccess(
            userUuid: user.id,
            schoolUuid: widget.schoolUuid,
            role: role.apiValue,
          );
        } else {
          throw StateError('No assignment handler configured.');
        }
      }
      if (!mounted) return;
      setState(() {
        _users = _users
            .map(
              (item) => item.id == user.id ? item.copyWith(role: role) : item,
            )
            .toList();
      });
      _showMessage(
        user.isAssigned
            ? 'Role updated for ${user.name}.'
            : '${user.name} assigned.',
      );
    } catch (_) {
      _showMessage(
        'Could not update this user. Please try again.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  Future<void> _revoke(SchoolUserAssignment user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove school access?'),
        content: Text(
          '${user.name} will no longer be able to access ${widget.schoolName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove access'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyUserId = user.id);
    try {
      if (widget.onRevoke != null) {
        await widget.onRevoke!.call(user);
      } else if (widget.api != null) {
        await widget.api!.revokeSchoolAccess(
          userUuid: user.id,
          schoolUuid: widget.schoolUuid,
        );
      } else {
        throw StateError('No revoke handler configured.');
      }
      if (!mounted) return;
      setState(() {
        _users = _users
            .map(
              (item) =>
                  item.id == user.id ? item.copyWith(clearRole: true) : item,
            )
            .toList();
      });
      _showMessage('Access removed for ${user.name}.');
    } catch (_) {
      _showMessage('Could not remove access. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignedCount = _users.where((user) => user.isAssigned).length;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xfff6f8fc),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 24,
        title: const Row(
          children: [
            Icon(Icons.badge_outlined),
            SizedBox(width: 10),
            Text('ID Card Manager'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 20),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xffdbe5ff),
              child: Text(
                'PA',
                style: TextStyle(color: AppColors.primary, fontSize: 12),
              ),
            ),
          ),
        ],
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
                    Text(
                      'User assignments',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Give people the right level of access for this school.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _SchoolSummary(
                      schoolName: widget.schoolName,
                      total: _users.length,
                      assigned: assignedCount,
                    ),
                    const SizedBox(height: 24),
                    _AccessGuidance(),
                    const SizedBox(height: 24),
                    _UserDirectory(
                      users: _visibleUsers,
                      searchController: _searchController,
                      filter: _filter,
                      onFilterChanged: (filter) =>
                          setState(() => _filter = filter),
                      busyUserId: _busyUserId,
                      canManageElevatedRoles: widget.canManageElevatedRoles,
                      onSetRole: _setRole,
                      onRevoke: _revoke,
                      loading: _loadingUsers,
                      loadError: _loadError,
                      onRetry: _loadUsers,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SchoolSummary extends StatelessWidget {
  const _SchoolSummary({
    required this.schoolName,
    required this.total,
    required this.assigned,
  });

  final String schoolName;
  final int total;
  final int assigned;

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
        spacing: 28,
        runSpacing: 20,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 23,
                backgroundColor: Color(0xffe8edff),
                child: Icon(Icons.school_outlined, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selected school',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    schoolName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          _Metric(value: '$total', label: 'User accounts'),
          _Metric(value: '$assigned', label: 'Assigned'),
          _Metric(
            value: '${total - assigned}',
            label: 'Need assignment',
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    this.color = AppColors.primary,
  });
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      Text(
        label,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    ],
  );
}

class _AccessGuidance extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xfffff8e8),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xfff3dc98)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, color: Color(0xff98700c)),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'School administrators can manage teachers and staff. Only platform administrators can assign school administrators or card operators.',
            style: TextStyle(color: Color(0xff624d15), height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _UserDirectory extends StatelessWidget {
  const _UserDirectory({
    required this.users,
    required this.searchController,
    required this.filter,
    required this.onFilterChanged,
    required this.busyUserId,
    required this.canManageElevatedRoles,
    required this.onSetRole,
    required this.onRevoke,
    required this.loading,
    required this.loadError,
    required this.onRetry,
  });

  final List<SchoolUserAssignment> users;
  final TextEditingController searchController;
  final AssignmentFilter filter;
  final ValueChanged<AssignmentFilter> onFilterChanged;
  final String? busyUserId;
  final bool canManageElevatedRoles;
  final Future<void> Function(SchoolUserAssignment user, SchoolRole role)
  onSetRole;
  final Future<void> Function(SchoolUserAssignment user) onRevoke;
  final bool loading;
  final String? loadError;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffe4e8f0)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'People',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Search a user, then assign or update their school role.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final search = TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search name, email, or designation',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xfff9fafc),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xffdce1eb)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xffdce1eb)),
                  ),
                ),
              );
              final filters = SegmentedButton<AssignmentFilter>(
                segments: const [
                  ButtonSegment(
                    value: AssignmentFilter.all,
                    label: Text('All'),
                  ),
                  ButtonSegment(
                    value: AssignmentFilter.assigned,
                    label: Text('Assigned'),
                  ),
                  ButtonSegment(
                    value: AssignmentFilter.unassigned,
                    label: Text('Unassigned'),
                  ),
                ],
                selected: {filter},
                onSelectionChanged: (values) => onFilterChanged(values.first),
                showSelectedIcon: false,
              );
              return constraints.maxWidth > 650
                  ? Row(
                      children: [
                        Expanded(child: search),
                        const SizedBox(width: 16),
                        filters,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        search,
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: filters,
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 18),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 44),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (loadError != null)
            _LoadError(message: loadError!, onRetry: onRetry)
          else if (users.isEmpty)
            const _EmptyUsers()
          else
            ...users.map(
              (user) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _UserCard(
                  user: user,
                  loading: user.id == busyUserId,
                  canManageElevatedRoles: canManageElevatedRoles,
                  onSetRole: onSetRole,
                  onRevoke: onRevoke,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.loading,
    required this.canManageElevatedRoles,
    required this.onSetRole,
    required this.onRevoke,
  });
  final SchoolUserAssignment user;
  final bool loading;
  final bool canManageElevatedRoles;
  final Future<void> Function(SchoolUserAssignment user, SchoolRole role)
  onSetRole;
  final Future<void> Function(SchoolUserAssignment user) onRevoke;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: user.isAssigned ? Colors.white : const Color(0xfffffcf5),
      border: Border.all(
        color: user.isAssigned
            ? const Color(0xffe5e8ef)
            : const Color(0xfff1dca9),
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final identity = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xffe8edff),
              child: Text(
                user.initials,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.email ?? '@${user.username}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (user.designation != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        user.designation!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
        final actions = _UserActions(
          user: user,
          loading: loading,
          canManageElevatedRoles: canManageElevatedRoles,
          onSetRole: onSetRole,
          onRevoke: onRevoke,
        );
        return constraints.maxWidth > 680
            ? Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 20),
                  actions,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [identity, const SizedBox(height: 16), actions],
              );
      },
    ),
  );
}

class _UserActions extends StatelessWidget {
  const _UserActions({
    required this.user,
    required this.loading,
    required this.canManageElevatedRoles,
    required this.onSetRole,
    required this.onRevoke,
  });
  final SchoolUserAssignment user;
  final bool loading;
  final bool canManageElevatedRoles;
  final Future<void> Function(SchoolUserAssignment user, SchoolRole role)
  onSetRole;
  final Future<void> Function(SchoolUserAssignment user) onRevoke;

  bool get _isElevatedAssignment =>
      user.role == SchoolRole.schoolAdmin ||
      user.role == SchoolRole.cardOperator;

  List<SchoolRole> get _availableRoles {
    if (canManageElevatedRoles) return SchoolRole.values;
    if (_isElevatedAssignment) return [user.role!];
    return const [SchoolRole.teacher, SchoolRole.staff];
  }

  bool get _canChangeAssignment =>
      canManageElevatedRoles || !_isElevatedAssignment;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 175,
        child: DropdownButtonFormField<SchoolRole>(
          initialValue: user.role,
          hint: const Text('Choose role'),
          isDense: true,
          isExpanded: true,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: _availableRoles
              .map(
                (role) => DropdownMenuItem(
                  value: role,
                  child: Text(role.label, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: loading || !_canChangeAssignment
              ? null
              : (role) {
                  if (role != null) onSetRole(user, role);
                },
        ),
      ),
      if (loading)
        const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        )
      else if (user.isAssigned && _canChangeAssignment)
        OutlinedButton.icon(
          onPressed: () => onRevoke(user),
          icon: const Icon(Icons.person_remove_outlined, size: 18),
          label: const Text('Remove'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
        )
      else
        FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: const Text('Choose a role'),
        ),
    ],
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Center(
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 42,
            color: AppColors.danger,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class _EmptyUsers extends StatelessWidget {
  const _EmptyUsers();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 44),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.person_search_outlined,
            size: 42,
            color: AppColors.disabled,
          ),
          SizedBox(height: 12),
          Text(
            'No matching users',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'Try another search or filter.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

enum AssignmentFilter { all, assigned, unassigned }

enum SchoolRole { schoolAdmin, cardOperator, teacher, staff }

extension SchoolRoleLabel on SchoolRole {
  String get apiValue => switch (this) {
    SchoolRole.schoolAdmin => 'school_admin',
    SchoolRole.cardOperator => 'card_operator',
    SchoolRole.teacher => 'teacher',
    SchoolRole.staff => 'staff',
  };

  String get label => switch (this) {
    SchoolRole.schoolAdmin => 'School administrator',
    SchoolRole.cardOperator => 'Card operator',
    SchoolRole.teacher => 'Teacher',
    SchoolRole.staff => 'Staff',
  };
}

class SchoolUserAssignment {
  const SchoolUserAssignment({
    required this.id,
    required this.name,
    required this.username,
    this.email,
    this.designation,
    this.role,
  });

  final String id;
  final String name;
  final String username;
  final String? email;
  final String? designation;
  final SchoolRole? role;

  factory SchoolUserAssignment.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role'] as String?;
    SchoolRole? role;
    for (final value in SchoolRole.values) {
      if (value.apiValue == rawRole) {
        role = value;
        break;
      }
    }
    return SchoolUserAssignment(
      id: json['user_uuid'] as String,
      name: json['full_name'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
      designation: json['designation'] as String?,
      role: role,
    );
  }

  bool get isAssigned => role != null;
  String get initials => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0])
      .join()
      .toUpperCase();

  SchoolUserAssignment copyWith({SchoolRole? role, bool clearRole = false}) =>
      SchoolUserAssignment(
        id: id,
        name: name,
        username: username,
        email: email,
        designation: designation,
        role: clearRole ? null : (role ?? this.role),
      );
}

const _demoUsers = [
  SchoolUserAssignment(
    id: '1',
    name: 'Anita Sharma',
    username: 'anita.sharma',
    email: 'anita.sharma@greenfield.edu',
    designation: 'Vice Principal',
    role: SchoolRole.schoolAdmin,
  ),
  SchoolUserAssignment(
    id: '2',
    name: 'Rahul Verma',
    username: 'rahul.verma',
    email: 'rahul.verma@greenfield.edu',
    designation: 'Class Teacher',
    role: SchoolRole.teacher,
  ),
  SchoolUserAssignment(
    id: '3',
    name: 'Meera Iyer',
    username: 'meera.iyer',
    email: 'meera.iyer@greenfield.edu',
    designation: 'Office Executive',
    role: SchoolRole.cardOperator,
  ),
  SchoolUserAssignment(
    id: '4',
    name: 'Arjun Kapoor',
    username: 'arjun.kapoor',
    email: 'arjun.kapoor@greenfield.edu',
    designation: 'Sports Coordinator',
  ),
  SchoolUserAssignment(
    id: '5',
    name: 'Sana Khan',
    username: 'sana.khan',
    email: 'sana.khan@greenfield.edu',
    designation: 'Librarian',
    role: SchoolRole.staff,
  ),
];
