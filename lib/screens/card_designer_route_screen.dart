import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/card_template.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'card_designer_screen.dart';
import 'login_screen.dart';
import '../widgets/authenticated_app_bar.dart';

/// Authenticated entry point for the web/app route `/design`.
class CardDesignerRouteScreen extends StatefulWidget {
  const CardDesignerRouteScreen({super.key});

  static const routeName = '/design';

  @override
  State<CardDesignerRouteScreen> createState() =>
      _CardDesignerRouteScreenState();
}

class _CardDesignerRouteScreenState extends State<CardDesignerRouteScreen> {
  String? _schoolUuid;
  Future<CardTemplate>? _template;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isAuthenticated) return const LoginScreen();
    if (!auth.canDesignCards) {
      return const _RouteMessage(
        icon: Icons.lock_outline,
        message: 'You are not authorized to design cards for this school.',
      );
    }

    final school = auth.selectedSchool;
    if (school == null) {
      return const _RouteMessage(
        icon: Icons.school_outlined,
        message: 'Select a school before opening the card designer.',
      );
    }

    if (_schoolUuid != school.uuid) {
      _schoolUuid = school.uuid;
      _template = _loadTemplate(auth.api, school.uuid);
    }

    return FutureBuilder<CardTemplate>(
      future: _template,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            appBar: AuthenticatedAppBar(title: Text('Card designer')),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _RouteMessage(
            icon: Icons.error_outline,
            message: 'Unable to load the card template: ${snapshot.error}',
          );
        }
        return CardDesignerScreen(
          schoolUuid: school.uuid,
          api: auth.api,
          initialTemplate: snapshot.data!,
        );
      },
    );
  }

  Future<CardTemplate> _loadTemplate(ApiService api, String schoolUuid) async {
    try {
      return await api.getCardTemplate(schoolUuid);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return CardTemplate.uploadedDesign;
      rethrow;
    }
  }
}

class _RouteMessage extends StatelessWidget {
  const _RouteMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AuthenticatedAppBar(title: Text('Card designer')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
