import 'package:flutter/material.dart';

import '../models/api_student.dart';
import '../models/card_template.dart';
import '../models/school_profile.dart';
import '../models/design_bindings.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'template_card.dart';

class IdCardPreview extends StatelessWidget {
  const IdCardPreview({
    super.key,
    required this.student,
    required this.schoolName,
    required this.api,
    required this.template,
    this.sessionName,
    this.className,
    this.sectionName,
    this.logoUrl,
    this.schoolProfile,
    this.onEdit,
    this.onPrint,
    this.onMarkPrinted,
  });

  final ApiStudent student;
  final String schoolName;
  final ApiService api;
  final CardTemplate template;
  static const actionsHeight = 38.0;
  final String? sessionName, className, sectionName, logoUrl;
  final SchoolProfile? schoolProfile;
  final VoidCallback? onEdit;
  final VoidCallback? onPrint;
  final VoidCallback? onMarkPrinted;

  String? get _photoUrl =>
      resolveDesignAssetUrl(student.photoPath, api.baseUrl);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      // Do not crop saved document corners to the surrounding UI card shape.
      clipBehavior: Clip.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xffd9dee8)),
      ),
      child: Column(
        children: [
          TemplateCard(
            student: student,
            template: template,
            sessionName: sessionName,
            photoUrl: _photoUrl,
            className: className,
            sectionName: sectionName,
            logoUrl: logoUrl,
            schoolName: schoolName,
            schoolProfile: schoolProfile,
            assetBaseUrl: api.baseUrl,
          ),
          SizedBox(
            height: actionsHeight,
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPrint,
                    icon: const Icon(Icons.print_outlined, size: 17),
                    label: const Text('Print'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: Color(0xffcbd3df)),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('mark-printed-${student.uuid}'),
                    onPressed: onMarkPrinted,
                    icon: const Icon(Icons.done_all, size: 17),
                    label: Text(
                      student.isPrinted
                          ? 'Reprint (${student.printCount})'
                          : 'Mark Printed',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: Color(0xffcbd3df)),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: Color(0xffcbd3df)),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
