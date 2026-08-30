import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_routes.dart';
import '../navigation/app_navigation.dart';
import '../config/launch_config.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => const PublicInformationPage(
    title: 'Privacy',
    summary:
        'This draft explains the information CampusID may handle and the decisions that must be confirmed before public launch.',
    sections: [
      PublicInformationSection(
        title: 'Who is responsible',
        paragraphs: [
          'CampusID supports schools in managing student ID-card workflows. The legal identity and contact details of the service operator, and the respective responsibilities of CampusID and participating schools, must be confirmed before public launch.',
          '[Service operator and privacy contact: To be confirmed before public launch]',
        ],
      ),
      PublicInformationSection(
        title: 'Information the service may process',
        paragraphs: [
          'Depending on how a school uses CampusID, the service may process student names, student photographs, school, class and section information, ID-card information, and school staff or user account information.',
          'Schools and authorized users should provide only information needed for their approved ID-card workflows.',
        ],
      ),
      PublicInformationSection(
        title: 'Why information is used',
        paragraphs: [
          'Information may be used to authenticate users, apply school-scoped access, manage student records and photographs, design ID cards, and generate individual cards or bulk PDF output.',
          '[Legal basis and any additional approved purposes: To be confirmed before public launch]',
        ],
      ),
      PublicInformationSection(
        title: 'Access and service providers',
        paragraphs: [
          'Access is intended for authorized school users according to their assigned role and school. The production service uses a hosted application backend, a PostgreSQL database, and object storage for student photographs.',
          '[Complete list of service providers, processing locations, and data-sharing terms: To be confirmed before public launch]',
        ],
      ),
      PublicInformationSection(
        title: 'Retention, deletion, and individual requests',
        paragraphs: [
          'Retention periods, deletion procedures, and the process for responding to privacy-related requests must be agreed with participating schools and documented before launch.',
          '[Retention schedule and request procedure: To be confirmed before public launch]',
        ],
      ),
      PublicInformationSection(
        title: 'Security and changes to this notice',
        paragraphs: [
          'CampusID uses account authentication and school-scoped authorization as part of the current application design. No security measure can eliminate every risk, and this draft does not make a certification or compliance claim.',
          '[Notice effective date and change-notification process: To be confirmed before public launch]',
        ],
      ),
    ],
  );
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) => const PublicInformationPage(
    title: 'Terms',
    summary:
        'These draft terms describe expected use of CampusID and require legal and business review before public launch.',
    sections: [
      PublicInformationSection(
        title: 'Status of this draft',
        paragraphs: [
          'These terms are a release-readiness draft, not finalized legal advice or a completed customer agreement.',
          '[Service operator, effective date, and contracting entity: To be confirmed before public launch]',
        ],
      ),
      PublicInformationSection(
        title: 'Authorized use',
        paragraphs: [
          'CampusID is intended for approved school ID-card administration. Users must access only schools and records they are authorized to manage and must keep their account credentials confidential.',
          'Users must not upload unlawful content, attempt to bypass access controls, disrupt the service, or use information for purposes unrelated to an approved school workflow.',
        ],
      ),
      PublicInformationSection(
        title: 'School responsibilities',
        paragraphs: [
          'Each participating school is responsible for deciding what information its authorized users enter, maintaining accurate role assignments, and confirming that it has appropriate authority for its use of student and staff information.',
          'Schools should promptly revoke access that is no longer required and report suspected account misuse through the published support channel.',
        ],
      ),
      PublicInformationSection(
        title: 'Accounts and generated materials',
        paragraphs: [
          'Users are responsible for the accuracy of submitted records, photographs, card designs, and generated PDF output. Generated cards should be reviewed before printing or distribution.',
          'Access may be restricted when an account or school assignment is pending, inactive, or revoked.',
        ],
      ),
      PublicInformationSection(
        title: 'Service terms still requiring approval',
        paragraphs: [
          '[Pricing, service availability, support commitments, suspension rules, intellectual-property terms, liability allocation, and termination process: To be confirmed before public launch]',
          '[Governing law and dispute process: To be confirmed before public launch]',
        ],
      ),
      PublicInformationSection(
        title: 'Contact and updates',
        paragraphs: [
          'Questions about these draft terms can be directed to the Support page. The final terms should state how material changes will be communicated.',
          '[Terms version and change-notification process: To be confirmed before public launch]',
        ],
      ),
    ],
  );
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) => PublicInformationPage(
    title: 'Contact & Support',
    summary:
        'For account access, school assignments, student records, or card-generation questions, contact your school administrator first.',
    sections: [
      const PublicInformationSection(
        title: 'CampusID support',
        paragraphs: [
          'A public CampusID support address has not yet been approved. The address below is a launch placeholder and must be replaced before release.',
        ],
      ),
      PublicInformationSection(
        title: LaunchConfig.supportEmail,
        paragraphs: const [LaunchConfig.supportEmailNotice],
        action: Builder(
          builder: (context) => OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: LaunchConfig.supportEmail),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support address copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy address'),
          ),
        ),
      ),
      const PublicInformationSection(
        title: 'When requesting help',
        paragraphs: [
          'Describe what you were trying to do, the school involved, and any error message you saw. Do not send passwords, access tokens, database credentials, or other secrets.',
          '[Support hours and response targets: To be confirmed before public launch]',
        ],
      ),
    ],
  );
}

class PublicInformationSection {
  const PublicInformationSection({
    required this.title,
    required this.paragraphs,
    this.action,
  });

  final String title;
  final List<String> paragraphs;
  final Widget? action;
}

class PublicInformationPage extends StatelessWidget {
  const PublicInformationPage({
    super.key,
    required this.title,
    required this.summary,
    required this.sections,
  });

  final String title;
  final String summary;
  final List<PublicInformationSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8fbff),
      appBar: AppBar(
        toolbarHeight: 76,
        backgroundColor: const Color(0xff102f55),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const _PublicBrandMark(),
        actions: [
          TextButton(
            onPressed: () => AppNavigation.navigateToPublicRoute<void>(
              context,
              AppRoutes.landing,
              replace: true,
            ),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Back to home'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 72),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xff183554),
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      summary,
                      style: const TextStyle(
                        color: Color(0xff526579),
                        fontSize: 18,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 36),
                    ...sections.map(_PublicSectionCard.new),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () =>
                              AppNavigation.navigateToPublicRoute<void>(
                                context,
                                AppRoutes.privacy,
                                replace: true,
                              ),
                          child: const Text('Privacy'),
                        ),
                        TextButton(
                          onPressed: () =>
                              AppNavigation.navigateToPublicRoute<void>(
                                context,
                                AppRoutes.terms,
                                replace: true,
                              ),
                          child: const Text('Terms'),
                        ),
                        TextButton(
                          onPressed: () =>
                              AppNavigation.navigateToPublicRoute<void>(
                                context,
                                AppRoutes.support,
                                replace: true,
                              ),
                          child: const Text('Contact & Support'),
                        ),
                      ],
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

class _PublicSectionCard extends StatelessWidget {
  const _PublicSectionCard(this.section);

  final PublicInformationSection section;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffdce7ef)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: const TextStyle(
            color: Color(0xff183554),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        ...section.paragraphs.map(
          (paragraph) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              paragraph,
              style: TextStyle(
                color: paragraph.startsWith('[')
                    ? const Color(0xff9a5b00)
                    : const Color(0xff526579),
                fontSize: 15.5,
                height: 1.6,
                fontWeight: paragraph.startsWith('[')
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ),
        ),
        if (section.action case final action?) ...[
          const SizedBox(height: 4),
          action,
        ],
      ],
    ),
  );
}

class _PublicBrandMark extends StatelessWidget {
  const _PublicBrandMark();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'assets/images/campusid_logo.png',
        width: 42,
        height: 42,
        fit: BoxFit.contain,
      ),
      const SizedBox(width: 11),
      const Text(
        'CampusID',
        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
      ),
    ],
  );
}
