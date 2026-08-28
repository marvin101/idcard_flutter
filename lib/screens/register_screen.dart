import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';

class _RegistrationSchool {
  const _RegistrationSchool({required this.uuid, required this.name});

  final String uuid;
  final String name;

  factory _RegistrationSchool.fromJson(Map<String, dynamic> json) =>
      _RegistrationSchool(
        uuid: json['uuid'] as String,
        name: json['school_name'] as String,
      );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({required this.api, super.key});

  final ApiService api;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _designationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _createdName;
  List<_RegistrationSchool> _schools = const [];
  String? _selectedSchoolUuid;
  bool _loadingSchools = true;
  String? _schoolLoadError;

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    setState(() {
      _loadingSchools = true;
      _schoolLoadError = null;
    });
    try {
      final response = await widget.api.getRegistrationSchools();
      final schools = response
          .whereType<Map<String, dynamic>>()
          .map(_RegistrationSchool.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _schools = schools;
        if (!_schools.any((school) => school.uuid == _selectedSchoolUuid)) {
          _selectedSchoolUuid = null;
        }
        _schoolLoadError = schools.isEmpty
            ? 'No schools are currently available for registration.'
            : null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _schoolLoadError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _schoolLoadError = 'Unable to load schools. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loadingSchools = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _designationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final result = await widget.api.register(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        schoolUuid: _selectedSchoolUuid!,
        email: _emailController.text,
        mobile: _mobileController.text,
        designation: _designationController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _createdName =
            result['full_name'] as String? ?? _fullNameController.text.trim();
      });
    } on ApiException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) {
        _showError('Unable to connect to the server. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'Enter $label.';
    return null;
  }

  String? _validateUsername(String? value) {
    final required = _required(value, 'a username');
    if (required != null) return required;
    if (value!.trim().length < 3) {
      return 'Use at least 3 characters.';
    }
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value.trim())) {
      return 'Use letters, numbers, dots, hyphens, or underscores only.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter a password.';
    if (value.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value != _passwordController.text) return 'Passwords do not match.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f8fb),
      appBar: AppBar(
        backgroundColor: const Color(0xff102f55),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Image.asset(
              'assets/images/campusid_logo.png',
              width: 34,
              height: 34,
            ),
            const SizedBox(width: 10),
            const Text('CampusID'),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _createdName == null
                ? _RegistrationForm(
                    formKey: _formKey,
                    fullNameController: _fullNameController,
                    usernameController: _usernameController,
                    emailController: _emailController,
                    mobileController: _mobileController,
                    schools: _schools,
                    selectedSchoolUuid: _selectedSchoolUuid,
                    loadingSchools: _loadingSchools,
                    schoolLoadError: _schoolLoadError,
                    designationController: _designationController,
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController,
                    obscurePassword: _obscurePassword,
                    obscureConfirmation: _obscureConfirmation,
                    submitting: _submitting,
                    onTogglePassword: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    onToggleConfirmation: () => setState(
                      () => _obscureConfirmation = !_obscureConfirmation,
                    ),
                    onSchoolChanged: (value) =>
                        setState(() => _selectedSchoolUuid = value),
                    onReloadSchools: _loadSchools,
                    onSubmit: _submit,
                    requiredValidator: _required,
                    usernameValidator: _validateUsername,
                    emailValidator: _validateEmail,
                    passwordValidator: _validatePassword,
                    confirmationValidator: _validateConfirmation,
                  )
                : _RegistrationSuccess(
                    name: _createdName!,
                    schoolName: _schools
                        .firstWhere(
                          (school) => school.uuid == _selectedSchoolUuid,
                        )
                        .name,
                    onSignIn: () => Navigator.of(context).pop('sign-in'),
                  ),
          ),
        ),
      ),
    );
  }
}

class _RegistrationForm extends StatelessWidget {
  const _RegistrationForm({
    required this.formKey,
    required this.fullNameController,
    required this.usernameController,
    required this.emailController,
    required this.mobileController,
    required this.schools,
    required this.selectedSchoolUuid,
    required this.loadingSchools,
    required this.schoolLoadError,
    required this.designationController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirmation,
    required this.submitting,
    required this.onTogglePassword,
    required this.onToggleConfirmation,
    required this.onSchoolChanged,
    required this.onReloadSchools,
    required this.onSubmit,
    required this.requiredValidator,
    required this.usernameValidator,
    required this.emailValidator,
    required this.passwordValidator,
    required this.confirmationValidator,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController mobileController;
  final List<_RegistrationSchool> schools;
  final String? selectedSchoolUuid;
  final bool loadingSchools;
  final String? schoolLoadError;
  final TextEditingController designationController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirmation;
  final bool submitting;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmation;
  final ValueChanged<String?> onSchoolChanged;
  final VoidCallback onReloadSchools;
  final VoidCallback onSubmit;
  final String? Function(String?, String) requiredValidator;
  final String? Function(String?) usernameValidator;
  final String? Function(String?) emailValidator;
  final String? Function(String?) passwordValidator;
  final String? Function(String?) confirmationValidator;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: Color(0xffdfe7ee)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create your CampusID account',
              style: TextStyle(
                color: Color(0xff183554),
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Select your school to request access. A platform or school administrator will review the request and assign your role.',
              style: TextStyle(
                color: Color(0xff65778a),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 620;
                final fields = [
                  TextFormField(
                    controller: fullNameController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => requiredValidator(value, 'your name'),
                  ),
                  TextFormField(
                    controller: usernameController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    validator: usernameValidator,
                  ),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: emailValidator,
                  ),
                  TextFormField(
                    controller: mobileController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                      labelText: 'Mobile (optional)',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSchoolUuid,
                    isExpanded: true,
                    items: schools
                        .map(
                          (school) => DropdownMenuItem<String>(
                            value: school.uuid,
                            child: Text(
                              school.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: loadingSchools || schools.isEmpty
                        ? null
                        : onSchoolChanged,
                    decoration: InputDecoration(
                      labelText: 'School',
                      prefixIcon: const Icon(Icons.school_outlined),
                      helperText:
                          schoolLoadError ?? 'Select your registered school.',
                      helperStyle: schoolLoadError == null
                          ? null
                          : const TextStyle(color: AppColors.danger),
                      suffixIcon: loadingSchools
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : schoolLoadError == null
                          ? null
                          : IconButton(
                              tooltip: 'Reload schools',
                              onPressed: onReloadSchools,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                    ),
                    validator: (value) {
                      if (loadingSchools) return 'Wait for schools to load.';
                      if (schoolLoadError != null) {
                        return 'Reload the school list.';
                      }
                      if (value == null) return 'Select your school.';
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: designationController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Designation',
                      prefixIcon: Icon(Icons.work_outline),
                    ),
                    validator: (value) =>
                        requiredValidator(value, 'your designation'),
                  ),
                ];
                if (!twoColumns) {
                  return Column(
                    children: fields
                        .where((field) => field is! SizedBox)
                        .map(
                          (field) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: field,
                          ),
                        )
                        .toList(),
                  );
                }
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: fields
                      .map(
                        (field) => SizedBox(
                          width: (constraints.maxWidth - 16) / 2,
                          child: field,
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: passwordController,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: onTogglePassword,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: passwordValidator,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: confirmPasswordController,
              obscureText: obscureConfirmation,
              onFieldSubmitted: (_) => onSubmit(),
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: const Icon(Icons.lock_reset_outlined),
                suffixIcon: IconButton(
                  onPressed: onToggleConfirmation,
                  icon: Icon(
                    obscureConfirmation
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: confirmationValidator,
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: submitting ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff11bfc1),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create account'),
              ),
            ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Already registered? Sign in'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RegistrationSuccess extends StatelessWidget {
  const _RegistrationSuccess({
    required this.name,
    required this.schoolName,
    required this.onSignIn,
  });
  final String name;
  final String schoolName;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: Color(0xffdfe7ee)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(38),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 38,
            backgroundColor: Color(0xffdff8f7),
            child: Icon(
              Icons.check_rounded,
              color: Color(0xff079598),
              size: 42,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Welcome, $name!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xff183554),
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your account has been created and your access request was sent to $schoolName. It does not grant access yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xff526579),
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xfff4f8fb),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Color(0xff087c80)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'A School Admin for $schoolName can now review your name and designation, then assign the appropriate role. CampusID will enforce that decision when you sign in.',
                    style: const TextStyle(
                      color: Color(0xff526579),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: onSignIn,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff102f55),
              ),
              child: const Text('Continue to sign in'),
            ),
          ),
        ],
      ),
    ),
  );
}
