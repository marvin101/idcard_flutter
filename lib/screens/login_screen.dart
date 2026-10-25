import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../providers/auth_provider.dart';
import '../navigation/app_navigation.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/campus_home_link.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaCodeController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _mfaCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    try {
      await auth.login(_usernameController.text, _passwordController.text);
      if (auth.mfaRequired) {
        TextInput.finishAutofillContext();
        return;
      }
      TextInput.finishAutofillContext();
      if (mounted) {
        AppNavigation.completeAuthentication(
          context,
          resumeProtectedRoute: auth.selectedSchool != null,
        );
      }
    } on ApiException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.error ?? 'Unable to sign in.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to connect to the server.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _verifyMfa() async {
    final code = _mfaCodeController.text.trim();
    if (code.length < 6) return;
    final auth = context.read<AuthProvider>();
    try {
      await auth.verifyMfaLogin(code);
      TextInput.finishAutofillContext();
      if (mounted) {
        AppNavigation.completeAuthentication(
          context,
          resumeProtectedRoute: auth.selectedSchool != null,
        );
      }
    } on ApiException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.error ?? 'MFA verification failed.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to verify the authentication code.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.all(34),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: CampusHomeLink(
                            child: Image.asset(
                              'assets/images/campusid_logo.png',
                              width: 76,
                              height: 76,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'CampusID',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sign in to manage your school workspace.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        if (auth.sessionMessage != null) ...[
                          const SizedBox(height: 18),
                          Semantics(
                            liveRegion: true,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                auth.sessionMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.danger),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 30),
                        if (!auth.mfaRequired) ...[
                          TextFormField(
                            controller: _usernameController,
                            autofillHints: const [AutofillHints.username],
                            autocorrect: false,
                            enableSuggestions: false,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter your username.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            autofillHints: const [AutofillHints.password],
                            autocorrect: false,
                            enableSuggestions: false,
                            obscureText: _obscurePassword,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Enter your password.'
                                : null,
                          ),
                        ] else ...[
                          const Text(
                            'Two-factor authentication',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enter the six-digit code from your authenticator app, or use a recovery code.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            key: const Key('mfa-login-code'),
                            controller: _mfaCodeController,
                            autofocus: true,
                            autocorrect: false,
                            enableSuggestions: false,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _verifyMfa(),
                            decoration: const InputDecoration(
                              labelText: 'Authentication or recovery code',
                              prefixIcon: Icon(Icons.phonelink_lock_outlined),
                            ),
                            validator: (value) => value == null || value.trim().length < 6
                                ? 'Enter a valid authentication or recovery code.'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 50,
                          child: FilledButton(
                            onPressed: auth.busy
                                ? null
                                : auth.mfaRequired
                                ? _verifyMfa
                                : _submit,
                            child: auth.busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(auth.mfaRequired ? 'Verify code' : 'Sign in'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (auth.mfaRequired)
                          TextButton(
                            onPressed: auth.busy
                                ? null
                                : () {
                                    auth.cancelMfaLogin();
                                    _mfaCodeController.clear();
                                  },
                            child: const Text('Back to sign in'),
                          )
                        else
                          TextButton(
                            onPressed: auth.busy
                                ? null
                                : () => AppNavigation.navigateToPublicRoute<void>(
                                    context,
                                    AppRoutes.register,
                                  ),
                            child: const Text("Don't have an account? Register"),
                          ),
                        const SizedBox(height: 18),
                        const Text(
                          'Your permissions and school access are loaded from the server after sign-in.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
