import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/school_profile.dart';
import '../providers/school_profile_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

bool canEditSchoolProfile({
  required bool isPlatformAdmin,
  required String? schoolRole,
}) => isPlatformAdmin || schoolRole == 'school_admin' || schoolRole == 'admin';

class SchoolProfileScreen extends StatefulWidget {
  const SchoolProfileScreen({
    super.key,
    required this.schoolUuid,
    required this.schoolName,
    required this.api,
    required this.canEdit,
    this.provider,
    this.pickLogo,
    this.onSaved,
  });

  final String schoolUuid;
  final String schoolName;
  final ApiService api;
  final bool canEdit;
  final SchoolProfileProvider? provider;
  final Future<XFile?> Function()? pickLogo;
  final ValueChanged<SchoolProfile>? onSaved;

  @override
  State<SchoolProfileScreen> createState() => _SchoolProfileScreenState();
}

class _SchoolProfileScreenState extends State<SchoolProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolCode = TextEditingController();
  final _schoolName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();
  final _principalName = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _state = TextEditingController();
  final _country = TextEditingController();
  final _postalCode = TextEditingController();

  late final SchoolProfileProvider _provider;
  late final bool _ownsProvider;
  SchoolProfile? _syncedProfile;

  @override
  void initState() {
    super.initState();
    _ownsProvider = widget.provider == null;
    _provider =
        widget.provider ??
        SchoolProfileProvider(
          api: widget.api,
          schoolUuid: widget.schoolUuid,
          canEdit: widget.canEdit,
        );
    _provider.addListener(_onProviderChanged);
    _syncProfile();
  }

  void _onProviderChanged() {
    if (!mounted) return;
    _syncProfile();
    setState(() {});
  }

  void _syncProfile() {
    final profile = _provider.profile;
    if (profile == null || identical(profile, _syncedProfile)) return;
    _syncedProfile = profile;
    _schoolCode.text = profile.schoolCode;
    _schoolName.text = profile.schoolName;
    _email.text = profile.email ?? '';
    _phone.text = profile.phone ?? '';
    _website.text = profile.website ?? '';
    _principalName.text = profile.principalName ?? '';
    _address.text = profile.address ?? '';
    _city.text = profile.city ?? '';
    _district.text = profile.district ?? '';
    _state.text = profile.state ?? '';
    _country.text = profile.country ?? '';
    _postalCode.text = profile.postalCode ?? '';
  }

  Future<void> _pickLogo() async {
    final logo =
        await (widget.pickLogo?.call() ??
            ImagePicker().pickImage(source: ImageSource.gallery));
    if (logo != null) {
      await _provider.chooseLogo(logo);
    }
  }

  Future<void> _save() async {
    final current = _provider.profile;
    if (current == null || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final saved = await _provider.save(
      current.copyWith(
        schoolName: _schoolName.text,
        email: _email.text,
        phone: _phone.text,
        website: _website.text,
        principalName: _principalName.text,
        address: _address.text,
        city: _city.text,
        district: _district.text,
        state: _state.text,
        country: _country.text,
        postalCode: _postalCode.text,
      ),
    );
    if (saved && mounted) {
      widget.onSaved?.call(_provider.profile!);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('School profile saved.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff5f7fb),
    appBar: AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      title: const Text('School Profile'),
    ),
    body: _provider.loading && _provider.profile == null
        ? const Center(child: CircularProgressIndicator())
        : _provider.profile == null
        ? _LoadFailure(provider: _provider)
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfileHeader(
                        profile: _provider.profile!,
                        selectedLogoBytes: _provider.selectedLogoBytes,
                        canEdit: widget.canEdit,
                        busy: _provider.saving,
                        onPickLogo: _pickLogo,
                      ),
                      if (_provider.error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          key: const Key('school-profile-error'),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _provider.error!,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final fieldWidth = constraints.maxWidth > 700
                                  ? (constraints.maxWidth - 16) / 2
                                  : constraints.maxWidth;
                              return Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  _field(
                                    width: fieldWidth,
                                    controller: _schoolCode,
                                    label: 'School code',
                                    readOnly: true,
                                    helperText: 'Stable identifier (read-only)',
                                  ),
                                  _field(
                                    key: const Key('school-name-field'),
                                    width: fieldWidth,
                                    controller: _schoolName,
                                    label: 'School name',
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'School name is required.'
                                        : null,
                                  ),
                                  _field(
                                    width: fieldWidth,
                                    controller: _email,
                                    label: 'Email',
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  _field(
                                    width: fieldWidth,
                                    controller: _phone,
                                    label: 'Phone',
                                    keyboardType: TextInputType.phone,
                                  ),
                                  _field(
                                    width: fieldWidth,
                                    controller: _website,
                                    label: 'Website',
                                    keyboardType: TextInputType.url,
                                  ),
                                  _field(
                                    width: fieldWidth,
                                    controller: _principalName,
                                    label: 'Principal name',
                                  ),
                                  _field(
                                    width: constraints.maxWidth,
                                    controller: _address,
                                    label: 'Address',
                                    maxLines: 3,
                                  ),
                                  _field(
                                    width: fieldWidth,
                                    controller: _city,
                                    label: 'City',
                                  ),
                                  _field(
                                    width: fieldWidth,
                                    controller: _district,
                                    label: 'District',
                                  ),
                                  _field(
                                    width: fieldWidth,
                                    controller: _state,
                                    label: 'State',
                                  ),
                                  _field(
                                    width: fieldWidth,
                                    controller: _country,
                                    label: 'Country',
                                  ),
                                  _field(
                                    width: fieldWidth,
                                    controller: _postalCode,
                                    label: 'Postal code',
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      if (widget.canEdit) ...[
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            key: const Key('save-school-profile'),
                            onPressed: _provider.saving ? null : _save,
                            icon: _provider.saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _provider.saving ? 'Saving…' : 'Save profile',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
  );

  Widget _field({
    Key? key,
    required double width,
    required TextEditingController controller,
    required String label,
    bool readOnly = false,
    String? helperText,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => SizedBox(
    key: key,
    width: width,
    child: TextFormField(
      controller: controller,
      enabled: widget.canEdit || readOnly,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(labelText: label, helperText: helperText),
    ),
  );

  @override
  void dispose() {
    _provider.removeListener(_onProviderChanged);
    if (_ownsProvider) _provider.dispose();
    for (final controller in [
      _schoolCode,
      _schoolName,
      _email,
      _phone,
      _website,
      _principalName,
      _address,
      _city,
      _district,
      _state,
      _country,
      _postalCode,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.selectedLogoBytes,
    required this.canEdit,
    required this.busy,
    required this.onPickLogo,
  });

  final SchoolProfile profile;
  final Uint8List? selectedLogoBytes;
  final bool canEdit;
  final bool busy;
  final VoidCallback onPickLogo;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 20,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 112,
            height: 112,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xffeef2f8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xffdce2ec)),
            ),
            clipBehavior: Clip.antiAlias,
            child: selectedLogoBytes != null
                ? Image.memory(
                    selectedLogoBytes!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  )
                : profile.logoUrl != null
                ? Image.network(
                    profile.logoUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.school_outlined, size: 44),
                  )
                : const Icon(Icons.school_outlined, size: 44),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.schoolName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  canEdit
                      ? 'Upload a JPEG, PNG or WebP logo up to 2 MB.'
                      : 'Profile details are read-only for your school role.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (canEdit) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('choose-school-logo'),
                    onPressed: busy ? null : onPickLogo,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      profile.logoPath == null ? 'Choose logo' : 'Replace logo',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.provider});
  final SchoolProfileProvider provider;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(provider.error ?? 'Unable to load the school profile.'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: provider.load,
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
