import 'package:flutter/material.dart';

import '../models/public_verification.dart';
import '../services/api_service.dart';

class PublicStudentVerificationScreen extends StatefulWidget {
  const PublicStudentVerificationScreen({
    super.key,
    required this.token,
    required this.api,
  });

  final String token;
  final ApiService api;

  @override
  State<PublicStudentVerificationScreen> createState() =>
      _PublicStudentVerificationScreenState();
}

class _PublicStudentVerificationScreenState
    extends State<PublicStudentVerificationScreen> {
  late Future<PublicStudentVerification> _verification;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _verification = widget.api.getPublicStudentVerification(widget.token);
  }

  void _retry() => setState(_load);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff3f5f9),
    body: SafeArea(
      child: FutureBuilder<PublicStudentVerification>(
        future: _verification,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return _Unavailable(onRetry: _retry);
          return _VerificationCard(view: snapshot.data!, api: widget.api);
        },
      ),
    ),
  );
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.view, required this.api});

  final PublicStudentVerification view;
  final ApiService api;

  String? _asset(String? value) {
    if (value == null || value.isEmpty) return null;
    if (Uri.tryParse(value)?.hasScheme == true) return value;
    return Uri.parse(
      '${api.baseUrl.replaceFirst(RegExp(r'/+$'), '')}/',
    ).resolve(value).toString();
  }

  @override
  Widget build(BuildContext context) {
    final verified = view.verified;
    final statusColor = verified
        ? const Color(0xff18794e)
        : const Color(0xff9a6700);
    final statusText = verified
        ? 'Verified student record'
        : 'Verification pending';
    final logo = _asset(view.logoUrl);
    final photo = _asset(view.photoUrl);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            elevation: 3,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: const Color(0xff242c61),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      if (logo != null) ...[
                        Image.network(
                          logo,
                          height: 64,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        view.schoolName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        view.schoolCode,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Container(
                  key: const Key('verification-status'),
                  color: statusColor.withValues(alpha: .1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        verified
                            ? Icons.verified_outlined
                            : Icons.schedule_outlined,
                        color: statusColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      if (photo != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            photo,
                            width: 120,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      for (final field in view.fields)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 150,
                                child: Text(
                                  field.label,
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  field.value.isEmpty ? '—' : field.value,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      Container(
                        key: const Key('signed-credential-status'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xffeef4ff),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              view.signatureVerified
                                  ? Icons.gpp_good_outlined
                                  : Icons.link_outlined,
                              color: const Color(0xff242c61),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                view.signatureVerified
                                    ? 'Cryptographic signature verified • valid until ${_date(view.credentialExpiresAt)}'
                                    : 'Legacy secure link • valid until ${_date(view.credentialExpiresAt)}',
                                style: const TextStyle(
                                  color: Color(0xff242c61),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text(
                        'This information is supplied and controlled by the school. The link can be revoked at any time.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _date(DateTime? value) {
    if (value == null) return 'not provided';
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gpp_bad_outlined, size: 52),
          const SizedBox(height: 12),
          const Text(
            'This verification link is unavailable.',
            key: Key('verification-unavailable'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'It may be invalid, disabled, or no longer active.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
