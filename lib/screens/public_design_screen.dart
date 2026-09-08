import 'package:flutter/material.dart';

import '../models/api_student.dart';
import '../models/public_design.dart';
import '../services/api_service.dart';
import '../widgets/design_document_view.dart';

class PublicDesignScreen extends StatefulWidget {
  const PublicDesignScreen({super.key, required this.token, required this.api});

  final String token;
  final ApiService api;

  @override
  State<PublicDesignScreen> createState() => _PublicDesignScreenState();
}

class _PublicDesignScreenState extends State<PublicDesignScreen> {
  late Future<PublicDesignView> _design;

  static final _sampleStudent = ApiStudent(
    uuid: 'public-preview',
    sessionUuid: 'public-preview',
    classUuid: 'public-preview',
    sectionUuid: 'public-preview',
    admissionNo: 'ADM-001',
    rollNo: '18',
    stream: 'SCIENCE',
    fullName: 'Sample Student',
    fatherName: 'Parent Name',
    motherName: 'Parent Name',
    dob: DateTime(2010, 1, 15),
    gender: 'Female',
    bloodGroup: 'A+',
    mobile: '9876543210',
    aadhaar: '123456789012',
    address: 'Sample address',
    isActive: true,
  );

  @override
  void initState() {
    super.initState();
    _design = widget.api.getPublicDesign(widget.token);
  }

  void _retry() => setState(() {
    _design = widget.api.getPublicDesign(widget.token);
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff3f5f9),
    appBar: AppBar(
      title: const Text('CampusID design preview'),
      backgroundColor: const Color(0xff242c61),
      foregroundColor: Colors.white,
    ),
    body: FutureBuilder<PublicDesignView>(
      future: _design,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return _Unavailable(onRetry: _retry);
        final view = snapshot.data!;
        final canvas = view.template.document.canvas;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                children: [
                  if (view.school.logoUrl != null) ...[
                    Image.network(
                      view.school.logoUrl!,
                      height: 64,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    view.school.schoolName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    view.template.name,
                    key: const Key('public-design-name'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Chip(
                    avatar: Icon(Icons.visibility_outlined, size: 18),
                    label: Text('Read-only sample preview'),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 4,
                    clipBehavior: Clip.antiAlias,
                    child: AspectRatio(
                      aspectRatio: canvas.width / canvas.height,
                      child: DesignDocumentView(
                        document: view.template.document,
                        student: _sampleStudent,
                        sessionName: '2026–27',
                        className: '10',
                        sectionName: 'A',
                        schoolName: view.school.schoolName,
                        schoolProfile: view.school,
                        logoUrl: view.school.logoUrl,
                        assetBaseUrl: widget.api.baseUrl,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This preview uses sample student details. No student records are shared.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
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
          const Icon(Icons.link_off_outlined, size: 48),
          const SizedBox(height: 12),
          const Text(
            'This design preview is unavailable.',
            key: Key('public-design-unavailable'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
