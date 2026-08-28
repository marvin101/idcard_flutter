import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scrollController = ScrollController();
  final _homeKey = GlobalKey();
  final _featuresKey = GlobalKey();
  final _securityKey = GlobalKey();
  final _faqKey = GlobalKey();

  Future<void> _scrollTo(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  void _openSignIn() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
  }

  Future<void> _openRegistration() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => RegisterScreen(api: context.read<AuthProvider>().api),
      ),
    );
    if (result == 'sign-in' && mounted) _openSignIn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SelectionArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              pinned: true,
              toolbarHeight: 76,
              backgroundColor: const Color(0xff102f55),
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              titleSpacing: 0,
              title: _PageWidth(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 850;
                    return Row(
                      children: [
                        const _BrandMark(light: true),
                        const Spacer(),
                        if (!compact) ...[
                          _NavButton('Home', () => _scrollTo(_homeKey)),
                          _NavButton('Features', () => _scrollTo(_featuresKey)),
                          _NavButton(
                            'How it works',
                            () => _scrollTo(_featuresKey),
                          ),
                          _NavButton('Security', () => _scrollTo(_securityKey)),
                          _NavButton('FAQ', () => _scrollTo(_faqKey)),
                          const SizedBox(width: 10),
                        ],
                        OutlinedButton(
                          onPressed: _openSignIn,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0x66ffffff)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 17,
                            ),
                          ),
                          child: const Text('Sign in'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _HeroSection(
                    key: _homeKey,
                    onGetStarted: _openRegistration,
                    onSignIn: _openSignIn,
                  ),
                  _FeaturesSection(key: _featuresKey),
                  _SecuritySection(key: _securityKey),
                  _FaqSection(key: _faqKey),
                  _CallToAction(onGetStarted: _openRegistration),
                  const _Footer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    super.key,
    required this.onGetStarted,
    required this.onSignIn,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xfff8fbff), Color(0xffeef5f8)],
        ),
      ),
      child: _PageWidth(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 76),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 900;
              final copy = _HeroCopy(
                onGetStarted: onGetStarted,
                onSignIn: onSignIn,
              );
              const preview = _DashboardPreview();
              if (stacked) {
                return Column(
                  children: [copy, const SizedBox(height: 48), preview],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 64),
                  const Expanded(child: preview),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.onGetStarted, required this.onSignIn});

  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xffdff8f7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'SMARTER CAMPUS ID MANAGEMENT',
            style: TextStyle(
              color: Color(0xff087c80),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'Secure, accurate student ID cards—without the busywork.',
          style: TextStyle(
            color: Color(0xff183554),
            fontSize: 46,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'CampusID brings school-scoped student entry, secure photo uploads, flexible card design, and fast PDF output into one controlled workspace.',
          style: TextStyle(color: Color(0xff526579), fontSize: 18, height: 1.6),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            FilledButton.icon(
              onPressed: onGetStarted,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff11bfc1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 18,
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Get started'),
            ),
            OutlinedButton.icon(
              onPressed: onSignIn,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff183554),
                side: const BorderSide(color: Color(0xffb7c9d6)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
              ),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Sign in'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            _TrustPoint('School-scoped access'),
            _TrustPoint('Secure photo storage'),
            _TrustPoint('Fast PDF output'),
          ],
        ),
      ],
    );
  }
}

class _TrustPoint extends StatelessWidget {
  const _TrustPoint(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.check_circle, color: Color(0xff11bfc1), size: 18),
      const SizedBox(width: 7),
      Text(
        label,
        style: const TextStyle(
          color: Color(0xff526579),
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _DashboardPreview extends StatelessWidget {
  const _DashboardPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1a173755),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1.25,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Container(
                width: 78,
                color: const Color(0xff102f55),
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: const Column(
                  children: [
                    _LogoImage(size: 42),
                    SizedBox(height: 30),
                    _SideIcon(Icons.dashboard_rounded, selected: true),
                    _SideIcon(Icons.school_rounded),
                    _SideIcon(Icons.badge_rounded),
                    _SideIcon(Icons.picture_as_pdf_rounded),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: const Color(0xfff6f8fb),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Campus overview',
                              style: TextStyle(
                                color: Color(0xff183554),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: Color(0xffdff8f7),
                            child: Icon(
                              Icons.person,
                              size: 18,
                              color: Color(0xff087c80),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              'Students',
                              '1,248',
                              Icons.people_alt_rounded,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              'Cards ready',
                              '986',
                              Icons.badge_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recent card activity',
                                style: TextStyle(
                                  color: Color(0xff183554),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 15),
                              ...List.generate(
                                3,
                                (index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 11),
                                  child: Row(
                                    children: [
                                      const CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Color(0xffe7edf3),
                                        child: Icon(
                                          Icons.person,
                                          size: 14,
                                          color: Color(0xff8394a5),
                                        ),
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Container(
                                          height: 7,
                                          decoration: BoxDecoration(
                                            color: const Color(0xffe7edf3),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xff11bfc1),
                                        size: 17,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideIcon extends StatelessWidget {
  const _SideIcon(this.icon, {this.selected = false});
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 42,
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: selected ? const Color(0xff11bfc1) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, color: Colors.white, size: 20),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xff11bfc1), size: 22),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xff183554),
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xff718295), fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection({super.key});

  @override
  Widget build(BuildContext context) => _Section(
    eyebrow: 'BUILT FOR REAL SCHOOL WORKFLOWS',
    title: 'Everything your ID-card team needs.',
    description:
        'Keep student information accurate, protect school boundaries, and move from entry to print without juggling disconnected tools.',
    child: const _ResponsiveCards(
      children: [
        _InfoCard(
          Icons.admin_panel_settings_outlined,
          'School-scoped permissions',
          'Give each administrator and operator access only to the schools and actions assigned to them.',
        ),
        _InfoCard(
          Icons.add_photo_alternate_outlined,
          'Student data and photos',
          'Enter card details, crop and upload photos, and keep every record ready for production.',
        ),
        _InfoCard(
          Icons.dashboard_customize_outlined,
          'Flexible Card Designer',
          'Adjust school card colors and layout while preserving controlled, reusable templates.',
        ),
        _InfoCard(
          Icons.picture_as_pdf_outlined,
          'Individual and bulk PDFs',
          'Preview cards and generate filtered print-ready output for the students you select.',
        ),
      ],
    ),
  );
}

class _SecuritySection extends StatelessWidget {
  const _SecuritySection({super.key});

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xff102f55),
    child: _PageWidth(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 76),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 760;
            const copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SECURITY BY DESIGN',
                  style: TextStyle(
                    color: Color(0xff55e0df),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Permissions enforced at every layer.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  'CampusID does more than hide buttons. The backend verifies authentication, active school assignments, and role permissions for every protected request.',
                  style: TextStyle(
                    color: Color(0xffc3d1df),
                    fontSize: 17,
                    height: 1.6,
                  ),
                ),
              ],
            );
            const points = Column(
              children: [
                _SecurityPoint(
                  Icons.domain_verification_outlined,
                  'Active school assignments',
                  'Pending and revoked access stays blocked.',
                ),
                _SecurityPoint(
                  Icons.manage_accounts_outlined,
                  'Role-based workflows',
                  'Admins and card operators receive clearly separated abilities.',
                ),
                _SecurityPoint(
                  Icons.cloud_done_outlined,
                  'Secure service architecture',
                  'FastAPI authorization with PostgreSQL and Supabase Storage.',
                ),
              ],
            );
            if (stacked) {
              return const Column(
                children: [copy, SizedBox(height: 38), points],
              );
            }
            return const Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: copy),
                SizedBox(width: 72),
                Expanded(child: points),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _SecurityPoint extends StatelessWidget {
  const _SecurityPoint(this.icon, this.title, this.description);
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xff174267),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: const Color(0xff55e0df)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(color: Color(0xffb5c5d4), height: 1.45),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FaqSection extends StatelessWidget {
  const _FaqSection({super.key});

  @override
  Widget build(BuildContext context) => _Section(
    eyebrow: 'FREQUENTLY ASKED QUESTIONS',
    title: 'A clearer path from student entry to printed card.',
    description: 'The essentials schools need before getting started.',
    child: const Column(
      children: [
        _FaqItem(
          'Can one user work with multiple schools?',
          'Yes. Active school assignments remain separate, and users switch school context without mixing records.',
        ),
        _FaqItem(
          'What can a Card Operator do?',
          'Card Operators can add students through ID-card entry, update card data, and upload photos for assigned schools.',
        ),
        _FaqItem(
          'Where are student photos stored?',
          'Photos use persistent Supabase Storage; access to the corresponding student workflow is authorized by FastAPI.',
        ),
      ],
    ),
  );
}

class _FaqItem extends StatelessWidget {
  const _FaqItem(this.question, this.answer);
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffdfe7ee)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
      childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
      title: Text(
        question,
        style: const TextStyle(
          color: Color(0xff183554),
          fontWeight: FontWeight.w700,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            answer,
            style: const TextStyle(color: Color(0xff526579), height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class _CallToAction extends StatelessWidget {
  const _CallToAction({required this.onGetStarted});
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xffeffafa),
    padding: const EdgeInsets.symmetric(vertical: 68, horizontal: 24),
    child: Column(
      children: [
        const _LogoImage(size: 72),
        const SizedBox(height: 20),
        const Text(
          'Ready to manage campus identity with confidence?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xff183554),
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Create your account, then ask your administrator to assign your school and role.',
          style: TextStyle(color: Color(0xff526579), fontSize: 16),
        ),
        const SizedBox(height: 26),
        FilledButton(
          onPressed: onGetStarted,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xff11bfc1),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
          ),
          child: const Text('Create your CampusID account'),
        ),
      ],
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xff0b2747),
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
    child: const _PageWidth(
      child: Row(
        children: [
          _BrandMark(light: true),
          Spacer(),
          Text(
            'Secure identity for every campus.',
            style: TextStyle(color: Color(0xffaebdca), fontSize: 13),
          ),
        ],
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.child,
  });
  final String eyebrow;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => _PageWidth(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 78),
      child: Column(
        children: [
          Text(
            eyebrow,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xff079598),
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xff183554),
              fontSize: 34,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xff65778a),
                fontSize: 16,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 42),
          child,
        ],
      ),
    ),
  );
}

class _ResponsiveCards extends StatelessWidget {
  const _ResponsiveCards({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000
          ? 4
          : constraints.maxWidth >= 620
          ? 2
          : 1;
      const gap = 16.0;
      final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(this.icon, this.title, this.description);
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 250),
    padding: const EdgeInsets.all(25),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffdfe7ee)),
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0d173755),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xffe6fafa),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xff079598)),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xff183554),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: const TextStyle(color: Color(0xff65778a), height: 1.55),
        ),
      ],
    ),
  );
}

class _NavButton extends StatelessWidget {
  const _NavButton(this.label, this.onPressed);
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xffdce7f0),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 16),
    ),
    child: Text(label),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.light});
  final bool light;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const _LogoImage(size: 42),
      const SizedBox(width: 11),
      Text(
        'CampusID',
        style: TextStyle(
          color: light ? Colors.white : AppColors.primary,
          fontSize: 23,
          fontWeight: FontWeight.w800,
          letterSpacing: -.5,
        ),
      ),
    ],
  );
}

class _LogoImage extends StatelessWidget {
  const _LogoImage({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/campusid_logo.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  );
}

class _PageWidth extends StatelessWidget {
  const _PageWidth({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1240),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: child,
      ),
    ),
  );
}
