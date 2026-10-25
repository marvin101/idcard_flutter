import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../models/auth_models.dart';
import '../navigation/app_navigation.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../widgets/authenticated_app_bar.dart';

enum AccountSection { profile, security }

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.initialSection});

  final AccountSection initialSection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AuthenticatedAppBar(title: Text('Account')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.pagePadding),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final navigation = _AccountNavigation(
                    selected: initialSection,
                  );
                  final content = initialSection == AccountSection.profile
                      ? const _ProfilePanel()
                      : const _SecurityPanel();
                  if (constraints.maxWidth < 760) {
                    return ListView(
                      children: [
                        navigation,
                        const SizedBox(height: AppDimensions.sectionSpacing),
                        content,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 220, child: navigation),
                      const SizedBox(width: AppDimensions.sectionSpacing),
                      Expanded(child: SingleChildScrollView(child: content)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountNavigation extends StatelessWidget {
  const _AccountNavigation({required this.selected});

  final AccountSection selected;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppDimensions.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _item(
              context,
              section: AccountSection.profile,
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              route: AppRoutes.accountProfile,
            ),
            const SizedBox(height: 4),
            _item(
              context,
              section: AccountSection.security,
              icon: Icons.shield_outlined,
              label: 'Security',
              route: AppRoutes.accountSecurity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required AccountSection section,
    required IconData icon,
    required String label,
    required String route,
  }) {
    final active = selected == section;
    return TextButton.icon(
      key: Key('account-nav-${section.name}'),
      onPressed: active
          ? null
          : () => AppNavigation.navigateToModule(context, route),
      icon: Icon(icon),
      label: Align(alignment: Alignment.centerLeft, child: Text(label)),
      style: TextButton.styleFrom(
        foregroundColor: active ? AppColors.primary : AppColors.textSecondary,
        backgroundColor: active ? AppColors.accentSoft : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _ProfilePanel extends StatefulWidget {
  const _ProfilePanel();

  @override
  State<_ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<_ProfilePanel> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  bool _photoBusy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final user = context.read<AuthProvider>().user;
    _usernameController.text = user?.username ?? '';
    _nameController.text = user?.fullName ?? '';
    _emailController.text = user?.email ?? '';
    _phoneController.text = user?.mobile ?? '';
    _initialized = true;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;
    return Card(
      elevation: AppDimensions.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              const Text(
                'Manage your personal account details. Your access roles are controlled by an administrator.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              _AvatarEditor(
                user: user,
                busy: _photoBusy,
                onUpload: _uploadPhoto,
                onRemove: user.profilePhotoUrl == null ? null : _removePhoto,
              ),
              const SizedBox(height: 28),
              TextFormField(
                key: const Key('profile-username'),
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final username = value?.trim() ?? '';
                  if (username.length < 3 || username.length > 100) {
                    return 'Use 3 to 100 characters.';
                  }
                  if (RegExp(r'\s').hasMatch(username)) {
                    return 'Username cannot contain spaces.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.fieldSpacing),
              TextFormField(
                key: const Key('profile-full-name'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your full name.'
                    : null,
              ),
              const SizedBox(height: AppDimensions.fieldSpacing),
              TextFormField(
                key: const Key('profile-email'),
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return null;
                  final at = email.lastIndexOf('@');
                  if (at <= 0 ||
                      !email.substring(at + 1).contains('.') ||
                      RegExp(r'\s').hasMatch(email)) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.fieldSpacing),
              TextFormField(
                key: const Key('profile-phone'),
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: 'Include country code when applicable',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppDimensions.fieldSpacing),
              TextFormField(
                key: const Key('profile-role'),
                initialValue: _roleLabel(auth, user),
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  suffixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                ),
              ),
              if (user.schoolContexts.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'School access',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final school in user.schoolContexts)
                      Chip(
                        avatar: const Icon(Icons.school_outlined, size: 18),
                        label: Text(
                          '${school.schoolName} · ${_humanize(school.role)}',
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              _AccountMetadata(user: user),
              const SizedBox(height: 28),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const Key('profile-save'),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().updateSelfProfile(
        username: _usernameController.text,
        fullName: _nameController.text,
        email: _emailController.text,
        mobile: _phoneController.text,
      );
      if (!mounted) return;
      _showMessage('Profile updated.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message, error: true);
    } catch (_) {
      if (mounted) _showMessage('Could not update your profile.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadPhoto() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (photo == null || !mounted) return;
    setState(() => _photoBusy = true);
    try {
      await context.read<AuthProvider>().uploadProfilePhoto(photo);
      if (mounted) _showMessage('Profile photo updated.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message, error: true);
    } catch (_) {
      if (mounted) {
        _showMessage('Could not upload the profile photo.', error: true);
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _photoBusy = true);
    try {
      await context.read<AuthProvider>().removeProfilePhoto();
      if (mounted) _showMessage('Profile photo removed.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message, error: true);
    } catch (_) {
      if (mounted) {
        _showMessage('Could not remove the profile photo.', error: true);
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
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
}

class _AvatarEditor extends StatelessWidget {
  const _AvatarEditor({
    required this.user,
    required this.busy,
    required this.onUpload,
    required this.onRemove,
  });

  final AuthUser user;
  final bool busy;
  final VoidCallback onUpload;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 20,
      runSpacing: 12,
      children: [
        CircleAvatar(
          key: const Key('profile-avatar'),
          radius: 42,
          backgroundColor: AppColors.accentSoft,
          foregroundColor: AppColors.primary,
          backgroundImage: user.profilePhotoUrl == null
              ? null
              : NetworkImage(user.profilePhotoUrl!),
          child: user.profilePhotoUrl == null
              ? Text(
                  user.initials,
                  key: const Key('profile-avatar-initials'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.fullName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('profile-photo-upload'),
                  onPressed: busy ? null : onUpload,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    user.profilePhotoUrl == null ? 'Add photo' : 'Replace',
                  ),
                ),
                if (onRemove != null)
                  TextButton(
                    key: const Key('profile-photo-remove'),
                    onPressed: busy ? null : onRemove,
                    child: const Text('Remove'),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _AccountMetadata extends StatelessWidget {
  const _AccountMetadata({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 12,
        children: [
          _metadata('Account status', user.isActive ? 'Active' : 'Inactive'),
          if (user.lastLogin != null)
            _metadata('Last sign in', _formatDate(user.lastLogin!)),
          if (user.createdAt != null)
            _metadata('Member since', _formatDate(user.createdAt!)),
        ],
      ),
    );
  }

  Widget _metadata(String label, String value) => SizedBox(
    width: 180,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _SecurityPanel extends StatefulWidget {
  const _SecurityPanel();

  @override
  State<_SecurityPanel> createState() => _SecurityPanelState();
}

class _SecurityPanelState extends State<_SecurityPanel> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _currentVisible = false;
  bool _newVisible = false;
  bool _confirmVisible = false;
  bool _saving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppDimensions.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Security',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              const Text(
                'Change your password. Other signed-in sessions will be revoked.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              const _MfaManagementPanel(),
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 24),
              _passwordField(
                key: const Key('current-password'),
                controller: _currentController,
                label: 'Current password',
                visible: _currentVisible,
                onToggle: () =>
                    setState(() => _currentVisible = !_currentVisible),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your current password.'
                    : null,
              ),
              const SizedBox(height: AppDimensions.fieldSpacing),
              _passwordField(
                key: const Key('new-password'),
                controller: _newController,
                label: 'New password',
                visible: _newVisible,
                onToggle: () => setState(() => _newVisible = !_newVisible),
                validator: (value) => value == null || value.length < 8
                    ? 'Use at least 8 characters.'
                    : null,
              ),
              const SizedBox(height: AppDimensions.fieldSpacing),
              _passwordField(
                key: const Key('confirm-password'),
                controller: _confirmController,
                label: 'Confirm new password',
                visible: _confirmVisible,
                onToggle: () =>
                    setState(() => _confirmVisible = !_confirmVisible),
                validator: (value) => value != _newController.text
                    ? 'Passwords do not match.'
                    : null,
              ),
              const SizedBox(height: 28),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const Key('change-password-submit'),
                  onPressed: _saving ? null : _changePassword,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.password_rounded),
                  label: const Text('Change password'),
                ),
              ),
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 20),
              const _AccountActivityDisclosure(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required bool visible,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      obscureText: !visible,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: const [],
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          tooltip: visible ? 'Hide password' : 'Show password',
          onPressed: onToggle,
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().api.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AppColors.danger,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not change your password.'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}


class _MfaManagementPanel extends StatefulWidget {
  const _MfaManagementPanel();

  @override
  State<_MfaManagementPanel> createState() => _MfaManagementPanelState();
}

class _MfaManagementPanelState extends State<_MfaManagementPanel> {
  final _codeController = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  bool _enabled = false;
  int _recoveryRemaining = 0;
  String? _provisioningUri;
  String? _manualSecret;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<AuthProvider>().api.getMfaStatus();
      if (!mounted) return;
      setState(() {
        _enabled = result['enabled'] == true;
        _recoveryRemaining = (result['recovery_codes_remaining'] as num?)?.toInt() ?? 0;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load MFA status.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startEnrollment() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await context.read<AuthProvider>().api.startMfaEnrollment();
      final uri = result['provisioning_uri'] as String?;
      if (uri == null || uri.isEmpty) {
        throw const ApiException(500, 'The server did not return an authenticator setup URI.');
      }
      final parsed = Uri.tryParse(uri);
      final secret = parsed?.queryParameters['secret'];
      if (secret == null || secret.isEmpty) {
        throw const ApiException(500, 'The authenticator setup URI did not contain a secret.');
      }
      if (!mounted) return;
      setState(() {
        _provisioningUri = uri;
        _manualSecret = secret;
        _codeController.clear();
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not start MFA enrollment.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyEnrollment() async {
    final code = _codeController.text.trim();
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the six-digit code from your authenticator app.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await context.read<AuthProvider>().api.verifyMfaEnrollment(code);
      final recoveryCodes = (result['recovery_codes'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList();
      if (!mounted) return;
      setState(() {
        _enabled = true;
        _recoveryRemaining = recoveryCodes.length;
        _provisioningUri = null;
        _manualSecret = null;
        _codeController.clear();
      });
      await _showRecoveryCodes(recoveryCodes);
      await _loadStatus();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not verify MFA enrollment.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showRecoveryCodes(List<String> codes) async {
    if (!mounted || codes.isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save your recovery codes'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'These codes are shown only once. Store them somewhere secure. Each code can be used once if you lose access to your authenticator.',
              ),
              const SizedBox(height: 16),
              SelectableText(codes.join('\n'), style: const TextStyle(fontFamily: 'monospace', height: 1.8)),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('I have saved them'),
          ),
        ],
      ),
    );
  }

  Future<void> _disableMfa() async {
    final formKey = GlobalKey<FormState>();
    final password = TextEditingController();
    final code = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disable two-factor authentication?'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Confirm your password and enter a current authenticator code or an unused recovery code.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
                validator: (value) => value == null || value.isEmpty ? 'Enter your password.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Authentication or recovery code'),
                validator: (value) => value == null || value.trim().length < 6 ? 'Enter a valid code.' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Disable MFA'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      password.dispose();
      code.dispose();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().api.disableMfa(
        currentPassword: password.text,
        code: code.text,
      );
      if (!mounted) return;
      setState(() {
        _enabled = false;
        _recoveryRemaining = 0;
        _provisioningUri = null;
        _manualSecret = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Two-factor authentication disabled.')),
      );
      await _loadStatus();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not disable MFA.');
    } finally {
      password.dispose();
      code.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phonelink_lock_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('Two-factor authentication', style: Theme.of(context).textTheme.titleMedium)),
              if (_loading || _busy)
                const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  key: const Key('mfa-status-refresh'),
                  tooltip: 'Refresh MFA status',
                  onPressed: _loadStatus,
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _loading
                ? 'Checking account security…'
                : _enabled
                    ? 'Enabled. Your account requires an authenticator code when signing in. $_recoveryRemaining recovery codes remain.'
                    : 'Add an authenticator app as a second sign-in step.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          if (!_loading && !_enabled && _provisioningUri == null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('mfa-start-enrollment'),
              onPressed: _busy ? null : _startEnrollment,
              icon: const Icon(Icons.security_rounded),
              label: const Text('Set up authenticator'),
            ),
          ],
          if (!_loading && !_enabled && _provisioningUri != null) ...[
            const SizedBox(height: 14),
            const Text('1. Open an authenticator app and choose to add an account manually.'),
            const SizedBox(height: 6),
            const Text('2. Enter this setup key. Keep it private; anyone with this key can generate your sign-in codes.'),
            const SizedBox(height: 8),
            SelectableText(_manualSecret ?? '', key: const Key('mfa-manual-secret'), style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, letterSpacing: 1.1)),
            const SizedBox(height: 8),
            const Text('3. Enter the six-digit code shown by the app to finish setup.'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('mfa-enrollment-code'),
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Six-digit authenticator code'),
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  key: const Key('mfa-enrollment-verify'),
                  onPressed: _busy ? null : _verifyEnrollment,
                  child: const Text('Verify and enable'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => setState(() {
                    _provisioningUri = null;
                    _manualSecret = null;
                    _codeController.clear();
                    _error = null;
                  }),
                  child: const Text('Cancel setup'),
                ),
              ],
            ),
          ],
          if (!_loading && _enabled) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('mfa-disable'),
              onPressed: _busy ? null : _disableMfa,
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('Disable two-factor authentication'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountActivityDisclosure extends StatefulWidget {
  const _AccountActivityDisclosure();

  @override
  State<_AccountActivityDisclosure> createState() =>
      _AccountActivityDisclosureState();
}

class _AccountActivityDisclosureState extends State<_AccountActivityDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        key: const Key('account-activity-toggle'),
        onPressed: () => setState(() => _expanded = !_expanded),
        icon: Icon(_expanded ? Icons.expand_less_rounded : Icons.history_rounded),
        label: Text(_expanded ? 'Hide account activity' : 'View account activity'),
      ),
      if (_expanded) ...[
        const SizedBox(height: 12),
        const _AccountActivityPanel(),
      ],
    ],
  );
}

class _AccountActivityPanel extends StatefulWidget {
  const _AccountActivityPanel();

  @override
  State<_AccountActivityPanel> createState() => _AccountActivityPanelState();
}

class _AccountActivityPanelState extends State<_AccountActivityPanel> {
  static const _pageSize = 20;
  final List<SecurityEvent> _events = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents({bool loadMore = false}) async {
    if (loadMore) {
      if (_loadingMore || _loading || _events.length >= _total) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await context.read<AuthProvider>().api.getSecurityEvents(
        limit: _pageSize,
        offset: loadMore ? _events.length : 0,
      );
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          final known = _events.map((event) => event.uuid).toSet();
          _events.addAll(page.items.where((event) => !known.contains(event.uuid)));
        } else {
          _events
            ..clear()
            ..addAll(page.items);
        }
        _total = page.total;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load account activity.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text('Account activity', style: Theme.of(context).textTheme.titleLarge),
          ),
          IconButton(
            key: const Key('account-activity-refresh'),
            tooltip: 'Refresh activity',
            onPressed: _loading || _loadingMore ? null : _loadEvents,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      const SizedBox(height: 4),
      const Text(
        'Recent security-related changes to your account.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      if (_loading && _events.isEmpty)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        )
      else if (_error != null && _events.isEmpty)
        _ActivityMessage(message: _error!, actionLabel: 'Try again', onAction: _loadEvents)
      else if (_events.isEmpty)
        const _ActivityMessage(message: 'No account activity has been recorded yet.')
      else ...[
        for (final event in _events) _SecurityEventTile(event: event),
        if (_error != null)
          _ActivityMessage(
            message: _error!,
            actionLabel: 'Retry',
            onAction: () => _loadEvents(loadMore: true),
          ),
        if (_events.length < _total)
          Align(
            alignment: Alignment.center,
            child: OutlinedButton.icon(
              key: const Key('account-activity-load-more'),
              onPressed: _loadingMore ? null : () => _loadEvents(loadMore: true),
              icon: _loadingMore
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(_loadingMore ? 'Loading…' : 'Load more'),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Showing ${_events.length} of $_total events',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    ],
  );
}

class _SecurityEventTile extends StatelessWidget {
  const _SecurityEventTile({required this.event});
  final SecurityEvent event;

  @override
  Widget build(BuildContext context) {
    final details = <String>[];
    if (event.ipAddress?.isNotEmpty == true) details.add('IP address: ${event.ipAddress}');
    final browser = _browserLabel(event.userAgent);
    if (browser != null) details.add('Device: $browser');
    if (event.details['other_sessions_revoked'] == true) details.add('Other sessions were signed out');
    if (event.details['current_session_preserved'] == true) details.add('Current session preserved');
    if (event.eventType == 'login_mfa_verified') {
      final method = event.details['method'];
      if (method == 'recovery_code') {
        details.add('Method: recovery code');
      } else if (method == 'totp') {
        details.add('Method: authenticator app');
      }
    }
    if (event.eventType == 'login_failed' || event.eventType == 'login_mfa_failed') {
      final stage = event.details['stage'];
      if (stage == 'password') details.add('Stage: password');
      if (stage == 'second_factor') details.add('Stage: two-factor verification');
      if (stage == 'account_status') details.add('Stage: account status');
    }

    return Card(
      key: Key('security-event-${event.uuid}'),
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: AppColors.surfaceSoft,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_eventIcon(event.eventType), color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_eventLabel(event.eventType), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(_formatDate(event.createdAt), style: const TextStyle(color: AppColors.textSecondary)),
                  for (final detail in details) ...[
                    const SizedBox(height: 5),
                    Text(detail, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityMessage extends StatelessWidget {
  const _ActivityMessage({required this.message, this.actionLabel, this.onAction});
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

String _eventLabel(String value) => switch (value) {
  'password_changed' => 'Password changed',
  'login' => 'Signed in',
  'logout' => 'Signed out',
  'login_mfa_verified' => 'Sign-in successful',
  'login_failed' => 'Sign-in failed',
  'login_mfa_failed' => 'Two-factor verification failed',
  'mfa_enabled' => 'Two-factor authentication enabled',
  'mfa_disabled' => 'Two-factor authentication disabled',
  _ => _humanize(value),
};

IconData _eventIcon(String value) => switch (value) {
  'password_changed' => Icons.password_rounded,
  'login' || 'login_mfa_verified' => Icons.login_rounded,
  'login_failed' || 'login_mfa_failed' => Icons.warning_amber_rounded,
  'logout' => Icons.logout_rounded,
  'mfa_enabled' || 'mfa_disabled' => Icons.phonelink_lock_rounded,
  _ => Icons.shield_outlined,
};

String? _browserLabel(String? userAgent) {
  if (userAgent == null || userAgent.trim().isEmpty) return null;
  final value = userAgent.toLowerCase();
  final browser = value.contains('edg/')
      ? 'Microsoft Edge'
      : value.contains('firefox/')
      ? 'Firefox'
      : value.contains('chrome/')
      ? 'Chrome'
      : value.contains('safari/')
      ? 'Safari'
      : 'Browser';
  final platform = value.contains('windows')
      ? 'Windows'
      : value.contains('android')
      ? 'Android'
      : value.contains('iphone') || value.contains('ipad')
      ? 'iOS'
      : value.contains('mac os')
      ? 'macOS'
      : value.contains('linux')
      ? 'Linux'
      : null;
  return platform == null ? browser : '$browser on $platform';
}

String _roleLabel(AuthProvider auth, AuthUser user) {
  if (user.isPlatformAdministrator) return 'Platform administrator';
  final selectedRole = auth.selectedSchoolAccess?.role;
  if (selectedRole != null) return _humanize(selectedRole);
  if (user.schoolContexts.length == 1) {
    return _humanize(user.schoolContexts.first.role);
  }
  return 'Account member';
}

String _humanize(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
