import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_routes.dart';
import '../navigation/app_navigation.dart';
import '../config/launch_config.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => const PublicInformationPage(
    title: 'Privacy Policy',
    summary: 'Effective 16 September 2026 · Last updated 16 September 2026',
    sections: [
      PublicInformationSection(
        title: 'Who operates CampusID',
        paragraphs: [
          'CampusID is operated by Paul Lakra, P.O. Bijuliya, Ratu, 835222, Ranchi, Jharkhand, India.',
          'Privacy enquiries may be sent to campusid@proton.me.',
        ],
      ),
      PublicInformationSection(
        title: 'Who controls school information',
        paragraphs: [
          'CampusID is primarily provided to schools and educational institutions. For student, teacher, staff, and other school records entered into CampusID, the relevant school generally determines why that information is collected and how it is used.',
          'CampusID processes that information to provide the services requested by the school. Schools are responsible for ensuring that they have the appropriate authority, notice, consent, or other lawful basis for information they enter into CampusID.',
        ],
      ),
      PublicInformationSection(
        title: 'Information we process',
        paragraphs: [
          'CampusID may process account information such as name, email address, account role, school assignments, account status, authentication information, and session information.',
          'School information may include school name, address, contact information, logo, branding, principal details, academic sessions, classes, and sections.',
          'Student information may include name, admission or identification number, class and section, configured personal details, photograph, school-defined custom fields, verification status, and card-printing information.',
          'Teacher and staff information may include name, employee number, designation, department, photograph, custom fields, verification status, and card-printing information.',
          'CampusID may also process card templates, layout settings, QR or barcode fields, print settings, audit information, IP addresses, security logs, browser information, and service diagnostics.',
        ],
      ),
      PublicInformationSection(
        title: 'Why information is processed',
        paragraphs: [
          'Information is processed to create and manage accounts, authenticate users, manage schools and authorized users, maintain student and personnel records, generate identity cards, process imports and photographs, provide verification and audit workflows, operate public forms and signed verification links, protect the service, troubleshoot problems, and respond to support or privacy requests.',
          'CampusID does not use student or personnel information for advertising.',
        ],
      ),
      PublicInformationSection(
        title: 'Children and student information',
        paragraphs: [
          'CampusID is designed for educational institutions and may therefore process information relating to children.',
          'Schools are responsible for ensuring that student information is collected and used appropriately for their educational and administrative purposes and that any required notices, permissions, parental or guardian authorization, or other legal requirements are satisfied.',
        ],
      ),
      PublicInformationSection(
        title: 'Public Forms',
        paragraphs: [
          'Schools may enable public CampusID forms for collecting student information. Information submitted through a form is associated with the school that created it and enters the configured review workflow.',
          'A public-form submitter cannot directly set internal verification or printed status. Anyone using a public-form link should submit only information they are authorized to provide.',
        ],
      ),
      PublicInformationSection(
        title: 'Public previews and verification',
        paragraphs: [
          'CampusID may provide limited public functions such as read-only card-design previews and signed student-verification links.',
          'These features are designed to expose only information required for their intended purpose. Public links may be disabled, regenerated, expired, or otherwise invalidated.',
        ],
      ),
      PublicInformationSection(
        title: 'Service providers',
        paragraphs: [
          'CampusID currently uses infrastructure including Render, Vercel, and Supabase for application hosting, web hosting, PostgreSQL database services, and object storage.',
          'Those providers may process information as necessary to provide their infrastructure services.',
        ],
      ),
      PublicInformationSection(
        title: 'Retention and deletion',
        paragraphs: [
          'School records are retained while required to provide CampusID services to the relevant school or until removed through authorized administrative actions and applicable requirements.',
          'Technical records, audit records, security logs, and backups may be retained where reasonably necessary for security, recovery, dispute resolution, or legal compliance. Temporary import files and temporary media should be removed after their intended workflow is completed or expires.',
        ],
      ),
      PublicInformationSection(
        title: 'Security',
        paragraphs: [
          'CampusID uses safeguards including authenticated access, role-based authorization, school-level access boundaries, password hashing, session management, server-side permission checks, request validation, storage-path validation, selected rate limits, audit trails, and HTTPS transport.',
          'No internet service can guarantee absolute security. Users should keep credentials confidential and report suspected unauthorized access.',
        ],
      ),
      PublicInformationSection(
        title: 'Data sharing',
        paragraphs: [
          'CampusID does not sell personal information to advertisers.',
          'Information may be shared with the school responsible for the relevant records, authorized users of that school, infrastructure providers required to operate CampusID, or where required by law or necessary to address serious misuse or security threats.',
        ],
      ),
      PublicInformationSection(
        title: 'Your rights and requests',
        paragraphs: [
          'Depending on applicable law and your relationship with the relevant school, you may be able to request information about processing, access, correction, updating, deletion or erasure where applicable, withdrawal of consent where relevant, or grievance handling.',
          'For school-managed student or personnel records, requests may need to be directed first to the relevant school because the school controls those records.',
          'Privacy requests may be sent to campusid@proton.me.',
        ],
      ),
      PublicInformationSection(
        title: 'Browser storage and sessions',
        paragraphs: [
          'CampusID may use browser storage or similar technologies where necessary to maintain authentication state, support secure session refresh, retain application preferences, and operate the service correctly.',
          'CampusID does not use this functionality for behavioural advertising.',
        ],
      ),
      PublicInformationSection(
        title: 'Changes to this policy',
        paragraphs: [
          'CampusID may update this Privacy Policy as the service evolves or legal requirements change. The updated policy will display a revised last-updated date, and material changes may also be communicated through the service where appropriate.',
        ],
      ),
      PublicInformationSection(
        title: 'Contact',
        paragraphs: [
          'CampusID · Paul Lakra',
          'P.O. Bijuliya, Ratu, 835222, Ranchi, Jharkhand, India',
          'campusid@proton.me',
        ],
      ),
    ],
  );
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) => const PublicInformationPage(
    title: 'Terms of Service',
    summary:
        'These Terms are governed by the laws of India, subject to applicable mandatory law. Courts having jurisdiction in Ranchi, Jharkhand, India will have jurisdiction over disputes arising from or relating to these Terms, subject to applicable law.',
    sections: [
      PublicInformationSection(
        title: 'Governing law and disputes',
        paragraphs: [
          'These Terms are governed by the laws of India, subject to applicable mandatory law.',
          'Courts having jurisdiction in Ranchi, Jharkhand, India will have jurisdiction over disputes arising from or relating to these Terms, subject to applicable law.',
        ],
      ),
      PublicInformationSection(
        title: 'Limitation of liability',
        paragraphs: [
          'To the maximum extent permitted by applicable law, CampusID and its operator will not be liable for indirect, incidental, special, consequential, or similar losses arising from unauthorized account use, inaccurate information entered by a school or user, inappropriate issuance of an identity card, third-party infrastructure failure, or use of the service contrary to these Terms.',
          'Nothing in these Terms excludes or limits liability that cannot lawfully be excluded or limited.',
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
      PublicInformationSection(
        title: 'Contact',
        paragraphs: [
          'CampusID · Paul Lakra',
          'P.O. Bijuliya, Ratu, 835222, Ranchi, Jharkhand, India',
          'campusid@proton.me',
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
          LaunchConfig.supportConfigured
              ? 'Use the published support address below to contact CampusID.'
              : 'A public CampusID support address has not yet been approved. The address below is a launch placeholder and must be replaced before release.',
        ],
      ),
      PublicInformationSection(
        title: LaunchConfig.supportEmail,
        paragraphs: const [LaunchConfig.supportEmailNotice],
        action: Builder(
          builder: (context) => OutlinedButton.icon(
            onPressed: !LaunchConfig.supportConfigured
                ? null
                : () async {
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
          'CampusID support is currently provided on a reasonable-efforts basis. Response times may vary depending on the nature and severity of the request.',
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
