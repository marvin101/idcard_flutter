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
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  bool _photoBusy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final user = context.read<AuthProvider>().user;
    _nameController.text = user?.fullName ?? '';
    _phoneController.text = user?.mobile ?? '';
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
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
                'Manage your personal account details. Your email and access roles are controlled by an administrator.',
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
                initialValue: user.email ?? 'Not provided',
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  suffixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                ),
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
        fullName: _nameController.text,
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
          _metadata('Username', user.username),
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
              const SizedBox(height: 28),
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
