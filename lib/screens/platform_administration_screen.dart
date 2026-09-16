import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_routes.dart';
import '../models/auth_models.dart';
import '../navigation/app_navigation.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/authenticated_app_bar.dart';

class PlatformAdministrationScreen extends StatefulWidget {
  const PlatformAdministrationScreen({super.key, required this.api});
  final ApiService api;
  @override
  State<PlatformAdministrationScreen> createState() =>
      _PlatformAdministrationScreenState();
}

class _PlatformAdministrationScreenState
    extends State<PlatformAdministrationScreen> {
  List<Map<String, dynamic>> _schools = [], _users = [];
  bool _busy = false, _more = false;
  String? _error;
  String _search = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.getAdminSchools(),
        widget.api.getAccounts(
          offset: append ? _users.length : 0,
          search: _search,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _schools = results[0].cast<Map<String, dynamic>>();
        final page = results[1].cast<Map<String, dynamic>>();
        _users = append ? [..._users, ...page] : page;
        _more = page.length == 100;
      });
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

  Future<Map<String, dynamic>?> _form({
    Map<String, dynamic>? user,
    bool school = false,
  }) async {
    final fields = school
        ? ['school_code', 'school_name']
        : [
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
    final key = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _OwnedControllers(
        controllers: controllers.values.toList(),
        child: AlertDialog(
          title: Text(
            school
                ? 'Create school'
                : user == null
                ? 'Create account'
                : 'Edit account',
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user != null)
                      const Text(
                        'Account edits affect every assigned school. Leave password empty to keep it.',
                      ),
                    for (final field in fields)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: TextFormField(
                          key: ValueKey('admin-$field'),
                          controller: controllers[field],
                          obscureText: field == 'password',
                          decoration: InputDecoration(
                            labelText: field.replaceAll('_', ' '),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if ((school ||
                                    field == 'username' ||
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
                      ),
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
                Navigator.pop(context, <String, dynamic>{
                  for (final field in fields)
                    if (!(field == 'password' &&
                        user != null &&
                        controllers[field]!.text.isEmpty))
                      field: field == 'password'
                          ? controllers[field]!.text
                          : controllers[field]!.text.trim(),
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

  Future<void> _memberships(Map<String, dynamic> user) async {
    try {
      final rows = await widget.api.getUserSchools(user['uuid'] as String);
      final roles = <String, String>{
        for (final row in rows.cast<Map<String, dynamic>>())
          row['school_uuid'] as String: row['role'] == 'admin'
              ? 'school_admin'
              : row['role'] as String,
      };
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('School access — ${user['full_name']}'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final school in _schools.where(
                    (s) => s['is_active'] == true,
                  ))
                    DropdownButtonFormField<String>(
                      initialValue: roles[school['uuid']] ?? '',
                      decoration: InputDecoration(
                        labelText: school['school_name'] as String,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('No access'),
                        ),
                        for (final role in [
                          'school_admin',
                          'card_operator',
                          'teacher',
                          'staff',
                        ])
                          DropdownMenuItem(
                            value: role,
                            child: Text(role.replaceAll('_', ' ')),
                          ),
                      ],
                      onChanged: (role) {
                        if (role != null) {
                          roles[school['uuid'] as String] = role;
                        }
                      },
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
              onPressed: () async {
                Navigator.pop(context);
                final existing = <String, String>{
                  for (final row in rows.cast<Map<String, dynamic>>())
                    row['school_uuid'] as String: row['role'] as String,
                };
                await _run(() async {
                  for (final school in _schools.where(
                    (s) => s['is_active'] == true,
                  )) {
                    final id = school['uuid'] as String,
                        role = roles[school['uuid']] ?? '';
                    if (role.isEmpty && existing.containsKey(id)) {
                      await widget.api.revokeSchoolAccess(
                        userUuid: user['uuid'] as String,
                        schoolUuid: id,
                      );
                    } else if (role.isNotEmpty && existing[id] != role) {
                      if (existing.containsKey(id)) {
                        await widget.api.updateSchoolAccess(
                          userUuid: user['uuid'] as String,
                          schoolUuid: id,
                          role: role,
                        );
                      } else {
                        await widget.api.createSchoolAccess(
                          userUuid: user['uuid'] as String,
                          schoolUuid: id,
                          role: role,
                        );
                      }
                    }
                  }
                });
              },
              child: const Text('Save access'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
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
        appBar: const AuthenticatedAppBar(
          title: Text('Platform administration'),
        ),
        body: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Schools'),
                Tab(text: 'Accounts'),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: FilledButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  final data = await _form(school: true);
                                  if (data != null) {
                                    await _run(() async {
                                      await widget.api.createSchool(
                                        data['school_code'] as String,
                                        data['school_name'] as String,
                                      );
                                      await auth.refreshAuthority();
                                    });
                                  }
                                },
                          child: const Text('Create school'),
                        ),
                      ),
                      for (final school in _schools)
                        ListTile(
                          title: Text(school['school_name'] as String),
                          subtitle: Text(
                            '${school['school_code']} · ${school['is_active'] == true ? 'Active' : 'Inactive'}',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                tooltip: 'Edit profile',
                                icon: const Icon(Icons.edit),
                                onPressed: _busy || school['is_active'] != true
                                    ? null
                                    : () async {
                                        await auth.selectSchool(
                                          SchoolSummary.fromJson(school),
                                        );
                                        if (context.mounted) {
                                          AppNavigation.navigateToModule(
                                            context,
                                            AppRoutes.schoolProfile,
                                          );
                                        }
                                      },
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        final active =
                                            school['is_active'] != true;
                                        if (await _confirm(
                                          active
                                              ? 'Activate school?'
                                              : 'Deactivate school?',
                                          active
                                              ? 'Restore access to this school?'
                                              : 'All school data and public submissions become unavailable. Records are retained.',
                                        )) {
                                          await _run(() async {
                                            await widget.api
                                                .setSchoolActivation(
                                                  school['uuid'] as String,
                                                  active,
                                                );
                                            await auth.refreshAuthority();
                                          });
                                        }
                                      },
                                child: Text(
                                  school['is_active'] == true
                                      ? 'Deactivate'
                                      : 'Activate',
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Search accounts; press Enter',
                              ),
                              onSubmitted: (value) {
                                _search = value;
                                _load();
                              },
                            ),
                            FilledButton(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      final data = await _form();
                                      if (data != null) {
                                        await _run(() async {
                                          await widget.api.createAccount(data);
                                        });
                                      }
                                    },
                              child: const Text('Create account'),
                            ),
                          ],
                        ),
                      ),
                      for (final user in _users)
                        ListTile(
                          title: Text(user['full_name'] as String),
                          subtitle: Text(
                            '${user['username']} · ${user['is_active'] == true ? 'Active' : 'Inactive'}${user['platform_role'] == 'platform_admin' || user['is_platform_admin'] == true ? ' · Platform Admin' : ''}',
                          ),
                          trailing: PopupMenuButton<String>(
                            enabled: !_busy,
                            onSelected: (action) async {
                              if (action == 'edit') {
                                final data = await _form(user: user);
                                if (data != null) {
                                  await _run(() async {
                                    await widget.api.updateAccount(
                                      user['uuid'] as String,
                                      data,
                                    );
                                  });
                                }
                              }
                              if (action == 'access') await _memberships(user);
                              if (action == 'active' &&
                                  await _confirm(
                                    'Change account activation?',
                                    'This affects every school and revokes existing sessions.',
                                  )) {
                                await _run(() async {
                                  await widget.api.updateAccount(
                                    user['uuid'] as String,
                                    {'is_active': user['is_active'] != true},
                                  );
                                });
                              }
                              if (action == 'platform' &&
                                  await _confirm(
                                    'Change platform authority?',
                                    'Platform administrators can administer every school and account.',
                                  )) {
                                await _run(() async {
                                  await widget.api.updateAccount(
                                    user['uuid'] as String,
                                    {
                                      'platform_role':
                                          user['platform_role'] ==
                                                  'platform_admin' ||
                                              user['is_platform_admin'] == true
                                          ? null
                                          : 'platform_admin',
                                    },
                                  );
                                });
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit account / reset password'),
                              ),
                              if (user['is_active'] == true)
                                const PopupMenuItem(
                                  value: 'access',
                                  child: Text('School roles and assignments'),
                                ),
                              if (user['uuid'] != auth.user?.uuid) ...[
                                PopupMenuItem(
                                  value: 'active',
                                  child: Text(
                                    user['is_active'] == true
                                        ? 'Deactivate account'
                                        : 'Activate account',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'platform',
                                  child: Text('Change platform role'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (_more)
                        TextButton(
                          onPressed: _busy ? null : () => _load(append: true),
                          child: const Text('Load more accounts'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
