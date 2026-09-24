import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../models/auth_models.dart';
import '../navigation/app_navigation.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/authenticated_app_bar.dart';

const _roles = ['school_admin', 'card_operator', 'teacher', 'staff'];

String _roleName(String value) => switch (value) {
  'platform_admin' => 'Platform Admin',
  'school_admin' || 'admin' => 'School Admin',
  'card_operator' => 'Card Operator',
  'teacher' => 'Teacher',
  'staff' => 'Staff',
  _ => value.replaceAll('_', ' '),
};

bool _platformAdmin(Map<String, dynamic> user) =>
    user['platform_role'] == 'platform_admin' ||
    user['is_platform_admin'] == true;

class PlatformAdministrationScreen extends StatefulWidget {
  const PlatformAdministrationScreen({super.key, required this.api});
  final ApiService api;

  @override
  State<PlatformAdministrationScreen> createState() => _AdministrationState();
}

class _AdministrationState extends State<PlatformAdministrationScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _schools = [], _users = [];
  Map<String, List<_Membership>> _access = {};
  bool _busy = false, _more = false;
  String? _error;
  String _role = '', _school = '', _status = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(_filteredChanged);
    _load();
  }

  @override
  void dispose() {
    _search
      ..removeListener(_filteredChanged)
      ..dispose();
    super.dispose();
  }

  void _filteredChanged() => setState(() {});

  Future<void> _load({bool append = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await Future.wait([
        widget.api.getAdminSchools(),
        widget.api.getAccounts(offset: append ? _users.length : 0),
      ]);
      final page = result[1].cast<Map<String, dynamic>>();
      final access = append
          ? Map<String, List<_Membership>>.of(_access)
          : <String, List<_Membership>>{};
      await Future.wait(
        page.where((u) => u['is_active'] == true).map((u) async {
          final id = u['uuid'] as String;
          try {
            final rows = await widget.api.getUserSchools(id);
            access[id] = rows
                .whereType<Map<String, dynamic>>()
                .map(_Membership.fromJson)
                .toList();
          } catch (_) {
            access[id] = const [];
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        _schools = result[0].cast<Map<String, dynamic>>();
        _users = append ? [..._users, ...page] : page;
        _access = access;
        _more = page.length == 100;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Map<String, dynamic>> get _visibleUsers {
    final q = _search.text.trim().toLowerCase();
    return _users.where((u) {
      final access = _access[u['uuid']] ?? const <_Membership>[];
      final searchMatch =
          q.isEmpty ||
          (u['full_name'] as String).toLowerCase().contains(q) ||
          (u['username'] as String).toLowerCase().contains(q) ||
          access.any((a) => a.schoolName.toLowerCase().contains(q));
      final statusMatch =
          _status.isEmpty || (_status == 'active') == (u['is_active'] == true);
      final roleMatch =
          _role.isEmpty ||
          (_role == 'platform_admin'
              ? _platformAdmin(u)
              : access.any((a) => a.role == _role));
      final schoolMatch =
          _school.isEmpty ||
          (!_platformAdmin(u) && access.any((a) => a.schoolUuid == _school));
      return searchMatch && statusMatch && roleMatch && schoolMatch;
    }).toList();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;

  Future<Map<String, String>?> _schoolForm() async {
    final code = TextEditingController(), name = TextEditingController();
    final key = GlobalKey<FormState>();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _OwnedControllers(
        controllers: [code, name],
        child: AlertDialog(
          title: const Text('Create school'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const ValueKey('admin-school_code'),
                    controller: code,
                    decoration: const InputDecoration(labelText: 'School code'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('admin-school_name'),
                    controller: name,
                    decoration: const InputDecoration(labelText: 'School name'),
                    validator: _required,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!key.currentState!.validate()) return;
                Navigator.pop(context, {
                  'school_code': code.text.trim(),
                  'school_name': name.text.trim(),
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  static String? _required(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Required' : null;

  Future<_AccountDraft?> _accountForm([Map<String, dynamic>? user]) async {
    final fields = [
      if (user == null) 'username',
      'full_name',
      'email',
      'mobile',
      'designation',
      'password',
    ];
    final controllers = {
      for (final field in fields)
        field: TextEditingController(
          text: field == 'password' ? '' : (user?[field] as String? ?? ''),
        ),
    };
    var type = user != null && _platformAdmin(user)
        ? 'platform_admin'
        : 'regular';
    final selected = {
      for (final item in _access[user?['uuid']] ?? const <_Membership>[])
        item.schoolUuid: item.role == 'admin' ? 'school_admin' : item.role,
    };
    final key = GlobalKey<FormState>();
    return showDialog<_AccountDraft>(
      context: context,
      builder: (context) => _OwnedControllers(
        controllers: controllers.values.toList(),
        child: StatefulBuilder(
          builder: (context, update) {
            final available = _schools
                .where(
                  (s) =>
                      s['is_active'] == true &&
                      !selected.containsKey(s['uuid']),
                )
                .toList();
            return AlertDialog(
              title: Text(user == null ? 'Create account' : 'Edit account'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Form(
                    key: key,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (user != null)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Changes affect every assigned school. Leave password empty to keep it.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        DropdownButtonFormField<String>(
                          key: const ValueKey('admin-platform_role'),
                          initialValue: type,
                          decoration: const InputDecoration(
                            labelText: 'Account type',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'regular',
                              child: Text('School-based account'),
                            ),
                            DropdownMenuItem(
                              value: 'platform_admin',
                              child: Text('Platform administrator'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) update(() => type = v);
                          },
                        ),
                        for (final field in fields) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            key: ValueKey('admin-$field'),
                            controller: controllers[field],
                            obscureText: field == 'password',
                            decoration: InputDecoration(
                              labelText: field == 'full_name'
                                  ? 'Full name'
                                  : field == 'password' && user != null
                                  ? 'New password (optional)'
                                  : '${field[0].toUpperCase()}${field.substring(1)}',
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if ((field == 'username' ||
                                      field == 'full_name' ||
                                      (field == 'password' && user == null)) &&
                                  text.isEmpty) {
                                return 'Required';
                              }
                              if (field == 'password' &&
                                  text.isNotEmpty &&
                                  text.length < 8) {
                                return 'At least 8 characters';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (type == 'platform_admin')
                          const _AllSchools()
                        else ...[
                          const Text(
                            'Assigned schools',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Choose a role for each school. Multiple schools are supported.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 10),
                          for (final entry in selected.entries)
                            _AssignmentRow(
                              key: ValueKey('assignment-${entry.key}'),
                              school: _schools.firstWhere(
                                (s) => s['uuid'] == entry.key,
                                orElse: () => {
                                  'uuid': entry.key,
                                  'school_name': 'Unavailable school',
                                  'is_active': false,
                                },
                              ),
                              role: entry.value,
                              onRole: (v) =>
                                  update(() => selected[entry.key] = v),
                              onRemove: () =>
                                  update(() => selected.remove(entry.key)),
                            ),
                          if (selected.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No schools assigned yet.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          if (available.isNotEmpty)
                            SizedBox(
                              key: const ValueKey('admin-add-school'),
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('add-school-${selected.length}'),
                                initialValue: null,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Add school',
                                  prefixIcon: Icon(Icons.add),
                                ),
                                items: [
                                  for (final s in available)
                                    DropdownMenuItem(
                                      value: s['uuid'] as String,
                                      child: Text(
                                        s['school_name'] as String,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (id) {
                                  if (id != null) {
                                    update(
                                      () => selected[id] = 'card_operator',
                                    );
                                  }
                                },
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!key.currentState!.validate()) return;
                    Navigator.pop(
                      context,
                      _AccountDraft(
                        data: {
                          for (final field in fields)
                            if (!(field == 'password' &&
                                user != null &&
                                controllers[field]!.text.isEmpty))
                              field: field == 'password'
                                  ? controllers[field]!.text
                                  : controllers[field]!.text.trim(),
                          'platform_role': type == 'platform_admin'
                              ? 'platform_admin'
                              : null,
                        },
                        roles: Map.of(selected),
                        platformAdmin: type == 'platform_admin',
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _sync(
    String userId,
    Map<String, String> old,
    Map<String, String> next,
  ) async {
    for (final item in old.entries) {
      if (!next.containsKey(item.key)) {
        await widget.api.revokeSchoolAccess(
          userUuid: userId,
          schoolUuid: item.key,
        );
      }
    }
    for (final item in next.entries) {
      if (!old.containsKey(item.key)) {
        await widget.api.createSchoolAccess(
          userUuid: userId,
          schoolUuid: item.key,
          role: item.value,
        );
      } else if (old[item.key] != item.value &&
          !(old[item.key] == 'admin' && item.value == 'school_admin')) {
        await widget.api.updateSchoolAccess(
          userUuid: userId,
          schoolUuid: item.key,
          role: item.value,
        );
      }
    }
  }

  Future<void> _createAccount() async {
    final draft = await _accountForm();
    if (draft == null) return;
    await _run(() async {
      final created = await widget.api.createAccount(draft.data);
      if (!draft.platformAdmin) {
        await _sync(created['uuid'] as String, const {}, draft.roles);
      }
    });
  }

  Future<void> _editAccount(Map<String, dynamic> user) async {
    final draft = await _accountForm(user);
    if (draft == null) return;
    final old = {
      for (final item in _access[user['uuid']] ?? const <_Membership>[])
        item.schoolUuid: item.role,
    };
    await _run(() async {
      await widget.api.updateAccount(user['uuid'] as String, draft.data);
      if (!draft.platformAdmin) {
        await _sync(user['uuid'] as String, old, draft.roles);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isPlatformAdmin) {
      return const Scaffold(
        body: Center(child: Text('Platform administrator access required.')),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const AuthenticatedAppBar(
          title: Text('Platform administration'),
        ),
        body: Column(
          children: [
            const Material(
              color: Colors.white,
              child: TabBar(
                tabs: [
                  Tab(text: 'Schools'),
                  Tab(text: 'Accounts'),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              ListTile(
                tileColor: AppColors.dangerSoft,
                leading: const Icon(
                  Icons.error_outline,
                  color: AppColors.danger,
                ),
                title: Text(_error!),
                trailing: TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Retry'),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [_schoolsTab(auth), _accountsTab(auth)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page(Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: constraints.maxWidth > 900 ? 32 : 16,
        vertical: 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: child,
        ),
      ),
    ),
  );

  Widget _schoolsTab(AuthProvider auth) => _page(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Toolbar(
          title: 'Schools',
          subtitle: 'Manage school profiles, user access, and availability.',
          action: FilledButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    final data = await _schoolForm();
                    if (data != null) {
                      await _run(() async {
                        await widget.api.createSchool(
                          data['school_code']!,
                          data['school_name']!,
                        );
                        await auth.refreshAuthority();
                      });
                    }
                  },
            icon: const Icon(Icons.add),
            label: const Text('Create school'),
          ),
        ),
        const SizedBox(height: 20),
        if (_schools.isEmpty && !_busy)
          const _Empty(
            Icons.school_outlined,
            'No schools yet',
            'Create a school to start administering CampusID.',
          )
        else
          for (final school in _schools) ...[
            _SchoolCard(
              school: school,
              busy: _busy,
              onEdit: school['is_active'] != true
                  ? null
                  : () async {
                      await auth.selectSchool(SchoolSummary.fromJson(school));
                      if (mounted) {
                        AppNavigation.navigateToModule(
                          context,
                          AppRoutes.schoolProfile,
                        );
                      }
                    },
              onUsers: null,
              onActivation: () async {
                final active = school['is_active'] != true;
                if (await _confirm(
                  active ? 'Activate school?' : 'Deactivate school?',
                  active
                      ? 'Restore access to this school?'
                      : 'All school data and public submissions become unavailable. Records are retained.',
                )) {
                  await _run(() async {
                    await widget.api.setSchoolActivation(
                      school['uuid'] as String,
                      active,
                    );
                    await auth.refreshAuthority();
                  });
                }
              },
            ),
            const SizedBox(height: 12),
          ],
      ],
    ),
  );

  Widget _accountsTab(AuthProvider auth) => _page(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Toolbar(
          title: 'Account directory',
          subtitle: 'See roles, status, and school access at a glance.',
          action: FilledButton.icon(
            onPressed: _busy ? null : _createAccount,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Create account'),
          ),
        ),
        const SizedBox(height: 20),
        _Filters(
          search: _search,
          schools: _schools,
          role: _role,
          school: _school,
          status: _status,
          onRole: (v) => setState(() => _role = v ?? ''),
          onSchool: (v) => setState(() => _school = v ?? ''),
          onStatus: (v) => setState(() => _status = v ?? ''),
        ),
        const SizedBox(height: 20),
        if (_visibleUsers.isEmpty && !_busy)
          const _Empty(
            Icons.person_search_outlined,
            'No matching accounts',
            'Try another search or filter.',
          )
        else
          for (final user in _visibleUsers) ...[
            _AccountCard(
              user: user,
              access: _access[user['uuid']] ?? const [],
              busy: _busy,
              current: user['uuid'] == auth.user?.uuid,
              onEdit: () => _editAccount(user),
              onActivation: () async {
                if (await _confirm(
                  user['is_active'] == true
                      ? 'Deactivate account?'
                      : 'Activate account?',
                  user['is_active'] == true && _platformAdmin(user)
                      ? 'Deactivate this platform administrator? This affects every school, revokes existing sessions, and is blocked if this is the last active platform administrator.'
                      : 'This affects every school and revokes existing sessions.',
                )) {
                  await _run(
                    () async => widget.api.updateAccount(
                      user['uuid'] as String,
                      {'is_active': user['is_active'] != true},
                    ),
                  );
                }
              },
              onPlatform: () async {
                if (await _confirm(
                  _platformAdmin(user)
                      ? 'Demote platform administrator?'
                      : 'Promote to platform administrator?',
                  _platformAdmin(user)
                      ? 'Demote this account to a school-based user? This is blocked if it is the last active platform administrator.'
                      : 'Promote this account? Platform administrators can administer every school and account.',
                )) {
                  await _run(
                    () async =>
                        widget.api.updateAccount(user['uuid'] as String, {
                          'platform_role': _platformAdmin(user)
                              ? null
                              : 'platform_admin',
                        }),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        if (_more)
          Center(
            child: OutlinedButton(
              onPressed: _busy ? null : () => _load(append: true),
              child: const Text('Load more accounts'),
            ),
          ),
      ],
    ),
  );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.title,
    required this.subtitle,
    required this.action,
  });
  final String title, subtitle;
  final Widget action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      const SizedBox(width: 16),
      action,
    ],
  );
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.search,
    required this.schools,
    required this.role,
    required this.school,
    required this.status,
    required this.onRole,
    required this.onSchool,
    required this.onStatus,
  });
  final TextEditingController search;
  final List<Map<String, dynamic>> schools;
  final String role, school, status;
  final ValueChanged<String?> onRole, onSchool, onStatus;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            key: const ValueKey('account-search'),
            controller: search,
            decoration: const InputDecoration(
              labelText: 'Search accounts',
              hintText: 'Name, username, or school',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        _Dropdown('Role', 185, role, const {
          '': 'All roles',
          'platform_admin': 'Platform Admin',
          'school_admin': 'School Admin',
          'card_operator': 'Card Operator',
          'teacher': 'Teacher',
          'staff': 'Staff',
        }, onRole),
        _Dropdown('School', 225, school, {
          '': 'All schools',
          for (final s in schools)
            s['uuid'] as String: s['school_name'] as String,
        }, onSchool),
        _Dropdown('Status', 155, status, const {
          '': 'All statuses',
          'active': 'Active',
          'inactive': 'Inactive',
        }, onStatus),
      ],
    ),
  );
}

class _Dropdown extends StatelessWidget {
  const _Dropdown(this.label, this.width, this.value, this.items, this.changed);
  final String label, value;
  final double width;
  final Map<String, String> items;
  final ValueChanged<String?> changed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      key: ValueKey('admin-${label.toLowerCase()}-filter'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final e in items.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: changed,
    ),
  );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.user,
    required this.access,
    required this.busy,
    required this.current,
    required this.onEdit,
    required this.onActivation,
    required this.onPlatform,
  });
  final Map<String, dynamic> user;
  final List<_Membership> access;
  final bool busy, current;
  final VoidCallback onEdit, onActivation, onPlatform;
  @override
  Widget build(BuildContext context) {
    final admin = _platformAdmin(user);
    final roles = admin
        ? const ['platform_admin']
        : access.map((a) => a.role).toSet().toList();
    return _Panel(
      child: LayoutBuilder(
        builder: (context, size) {
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user['full_name'] as String,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final role in roles)
                    _Badge(
                      _roleName(role),
                      Icons.badge_outlined,
                      color: AppColors.info,
                      background: AppColors.infoSoft,
                    ),
                  if (roles.isEmpty)
                    const _Badge('No role assigned', Icons.badge_outlined),
                  _Badge(
                    user['is_active'] == true ? 'Active' : 'Inactive',
                    user['is_active'] == true
                        ? Icons.check_circle_outline
                        : Icons.pause_circle_outline,
                    color: user['is_active'] == true
                        ? AppColors.success
                        : AppColors.textSecondary,
                    background: user['is_active'] == true
                        ? AppColors.successSoft
                        : AppColors.surfaceMuted,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (admin)
                const Text(
                  'Access: All schools',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                _SchoolChips(access),
              const SizedBox(height: 10),
              Text(
                '@${user['username']}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              PopupMenuButton<String>(
                tooltip: 'More account actions',
                enabled: !busy,
                onSelected: (v) =>
                    v == 'active' ? onActivation() : onPlatform(),
                itemBuilder: (_) => current
                    ? []
                    : [
                        PopupMenuItem(
                          value: 'platform',
                          child: Text(
                            admin
                                ? 'Demote to regular user'
                                : 'Promote to platform administrator',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'active',
                          child: Text(
                            user['is_active'] == true
                                ? 'Deactivate account'
                                : 'Activate account',
                          ),
                        ),
                      ],
              ),
            ],
          );
          return size.maxWidth > 680
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: info),
                    const SizedBox(width: 16),
                    actions,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [info, const SizedBox(height: 14), actions],
                );
        },
      ),
    );
  }
}

class _SchoolChips extends StatelessWidget {
  const _SchoolChips(this.access);
  final List<_Membership> access;
  @override
  Widget build(BuildContext context) {
    if (access.isEmpty) {
      return const Text(
        'Schools: None assigned',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }
    final shown = access.take(2);
    return Semantics(
      label: 'Assigned schools: ${access.map((a) => a.schoolName).join(', ')}',
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Text(
              'Schools:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final item in shown)
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(item.schoolName),
            ),
          if (access.length > 2)
            Tooltip(
              message: access.skip(2).map((a) => a.schoolName).join('\n'),
              child: Chip(label: Text('+${access.length - 2} more')),
            ),
        ],
      ),
    );
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({
    required this.school,
    required this.busy,
    required this.onEdit,
    required this.onUsers,
    required this.onActivation,
  });
  final Map<String, dynamic> school;
  final bool busy;
  final VoidCallback? onEdit, onUsers;
  final VoidCallback onActivation;
  @override
  Widget build(BuildContext context) => _Panel(
    child: LayoutBuilder(
      builder: (context, size) {
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              school['school_name'] as String,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _Badge(school['school_code'] as String, Icons.tag),
                _Badge(
                  school['is_active'] == true ? 'Active' : 'Inactive',
                  school['is_active'] == true
                      ? Icons.check_circle_outline
                      : Icons.pause_circle_outline,
                  color: school['is_active'] == true
                      ? AppColors.success
                      : AppColors.textSecondary,
                  background: school['is_active'] == true
                      ? AppColors.successSoft
                      : AppColors.surfaceMuted,
                ),
              ],
            ),
          ],
        );
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
            PopupMenuButton<String>(
              tooltip: 'More school actions',
              enabled: !busy,
              onSelected: (v) =>
                  v == 'users' ? onUsers?.call() : onActivation(),
              itemBuilder: (_) => [
                if (onUsers != null)
                  const PopupMenuItem(
                    value: 'users',
                    child: Text('Manage accounts'),
                  ),
                PopupMenuItem(
                  value: 'active',
                  child: Text(
                    school['is_active'] == true
                        ? 'Deactivate school'
                        : 'Activate school',
                  ),
                ),
              ],
            ),
          ],
        );
        return size.maxWidth > 600
            ? Row(
                children: [
                  Expanded(child: info),
                  actions,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [info, const SizedBox(height: 14), actions],
              );
      },
    ),
  );
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({
    super.key,
    required this.school,
    required this.role,
    required this.onRole,
    required this.onRemove,
  });
  final Map<String, dynamic> school;
  final String role;
  final ValueChanged<String> onRole;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    final active = school['is_active'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              school['school_name'] as String,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 165,
            child: DropdownButtonFormField<String>(
              key: ValueKey('admin-school-role-${school['uuid']}'),
              initialValue: _roles.contains(role) ? role : 'school_admin',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Role'),
              items: [
                for (final value in _roles)
                  DropdownMenuItem(
                    value: value,
                    child: Text(
                      _roleName(value),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: active
                  ? (v) {
                      if (v != null) onRole(v);
                    }
                  : null,
            ),
          ),
          IconButton(
            key: ValueKey('remove-school-${school['uuid']}'),
            tooltip: 'Remove ${school['school_name']}',
            onPressed: active ? onRemove : null,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _AllSchools extends StatelessWidget {
  const _AllSchools();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.infoSoft,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Row(
      children: [
        Icon(Icons.public, color: AppColors.info),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Platform administrators have access to all schools; individual school assignments are not required.',
          ),
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
}

class _Badge extends StatelessWidget {
  const _Badge(
    this.label,
    this.icon, {
    this.color = AppColors.textSecondary,
    this.background = AppColors.surfaceMuted,
  });
  final String label;
  final IconData icon;
  final Color color, background;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.icon, this.title, this.message);
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.disabled),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    ),
  );
}

class _AccountDraft {
  const _AccountDraft({
    required this.data,
    required this.roles,
    required this.platformAdmin,
  });
  final Map<String, dynamic> data;
  final Map<String, String> roles;
  final bool platformAdmin;
}

class _Membership {
  const _Membership(this.schoolUuid, this.schoolName, this.role);
  final String schoolUuid, schoolName, role;
  factory _Membership.fromJson(Map<String, dynamic> json) => _Membership(
    json['school_uuid'] as String,
    json['school_name'] as String,
    json['role'] as String,
  );
}

class _OwnedControllers extends StatefulWidget {
  const _OwnedControllers({required this.controllers, required this.child});
  final List<TextEditingController> controllers;
  final Widget child;
  @override
  State<_OwnedControllers> createState() => _OwnedControllersState();
}

class _OwnedControllersState extends State<_OwnedControllers> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
