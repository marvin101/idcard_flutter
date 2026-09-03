import 'package:flutter/material.dart';

import '../models/api_student.dart';
import '../models/card_template.dart';
import 'design_document_view.dart';

class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.student,
    required this.template,
    required this.sessionName,
    this.className,
    this.sectionName,
    this.photoUrl,
    this.logoUrl,
  });
  final ApiStudent student;
  final CardTemplate template;
  final String? sessionName, className, sectionName, photoUrl, logoUrl;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xffcfd4dc)),
      boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 8)],
    ),
    child: DesignDocumentView(
      document: template.document,
      student: student,
      sessionName: sessionName,
      className: className,
      sectionName: sectionName,
      photoUrl: photoUrl,
      logoUrl: logoUrl,
    ),
  );
}
