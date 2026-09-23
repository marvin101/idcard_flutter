import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../providers/auth_provider.dart';
import '../navigation/app_navigation.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/campus_home_link.dart';
import '../widgets/login/credential_login_form.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Future<void> _submit(String username, String password) async {
    final auth = context.read<AuthProvider>();
    try {
      await auth.login(username, password);
      TextInput.finishAutofillContext();
      if (mounted) {
        final currentRoute = ModalRoute.of(context)?.settings.name;
        if (AppRoutes.isProtected(currentRoute) &&
            auth.selectedSchool != null) {
          return;
        }
        AppNavigation.resetToAuthenticatedRoot(context);
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
                    CredentialLoginForm(busy: auth.busy, onSubmit: _submit),
                    const SizedBox(height: 12),
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
    );
  }
}
