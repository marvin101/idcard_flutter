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
  static const actionsHeight = 42.0;
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
          _TwoSidedTemplateCard(
            student: student,
            template: template,
            sessionName: sessionName,
            photoUrl: _photoUrl,
            className: className,
            sectionName: sectionName,
            logoUrl: logoUrl,
            schoolName: schoolName,
            schoolProfile: schoolProfile,
            api: api,
          ),
          SizedBox(
            height: actionsHeight,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Card previews can be very narrow for portrait designs.
                // Full labels only make sense when each action has enough horizontal room.
                final showLabels = constraints.maxWidth >= 360;

                Widget action({
                  required String tooltip,
                  required IconData icon,
                  required VoidCallback? onPressed,
                  String? label,
                  Key? key,
                }) {
                  final style = OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: Color(0xffcbd3df)),
                    padding: showLabels
                        ? const EdgeInsets.symmetric(horizontal: 8)
                        : EdgeInsets.zero,
                    minimumSize: const Size(0, actionsHeight),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  );

                  if (showLabels) {
                    return Tooltip(
                      message: tooltip,
                      child: OutlinedButton.icon(
                        key: key,
                        onPressed: onPressed,
                        icon: Icon(icon, size: 17),
                        label: Text(
                          label ?? tooltip,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: style,
                      ),
                    );
                  }

                  return Tooltip(
                    message: tooltip,
                    child: OutlinedButton(
                      key: key,
                      onPressed: onPressed,
                      style: style,
                      child: Icon(icon, size: 18),
                    ),
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: action(
                        tooltip: 'Print card',
                        label: 'Print',
                        icon: Icons.print_outlined,
                        onPressed: onPrint,
                      ),
                    ),
                    Expanded(
                      child: action(
                        key: Key('mark-printed-${student.uuid}'),
                        tooltip: student.isPrinted
                            ? 'Record reprint (${student.printCount})'
                            : 'Mark printed',
                        label: student.isPrinted
                            ? 'Reprint (${student.printCount})'
                            : 'Mark Printed',
                        icon: Icons.done_all,
                        onPressed: onMarkPrinted,
                      ),
                    ),
                    Expanded(
                      child: action(
                        tooltip: 'Edit student',
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        onPressed: onEdit,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TwoSidedTemplateCard extends StatefulWidget {
  const _TwoSidedTemplateCard({
    required this.student,
    required this.schoolName,
    required this.api,
    required this.template,
    this.sessionName,
    this.className,
    this.sectionName,
    this.photoUrl,
    this.logoUrl,
    this.schoolProfile,
  });

  final ApiStudent student;
  final String schoolName;
  final ApiService api;
  final CardTemplate template;
  final String? sessionName, className, sectionName, photoUrl, logoUrl;
  final SchoolProfile? schoolProfile;

  @override
  State<_TwoSidedTemplateCard> createState() => _TwoSidedTemplateCardState();
}

class _TwoSidedTemplateCardState extends State<_TwoSidedTemplateCard> {
  bool _showBack = false;

  @override
  void didUpdateWidget(covariant _TwoSidedTemplateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.template.hasBackDesign) _showBack = false;
  }

  @override
  Widget build(BuildContext context) {
    final visibleTemplate = _showBack
        ? widget.template.copyWith(document: widget.template.backDocument)
        : widget.template;
    return Stack(
      children: [
        TemplateCard(
          student: widget.student,
          template: visibleTemplate,
          sessionName: widget.sessionName,
          photoUrl: widget.photoUrl,
          className: widget.className,
          sectionName: widget.sectionName,
          logoUrl: widget.logoUrl,
          schoolName: widget.schoolName,
          schoolProfile: widget.schoolProfile,
          assetBaseUrl: widget.api.baseUrl,
        ),
        if (widget.template.hasBackDesign)
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.white.withValues(alpha: .9),
              shape: const CircleBorder(),
              elevation: 1,
              child: IconButton(
                key: Key('preview-side-toggle-${widget.student.uuid}'),
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                tooltip: _showBack ? 'Show front' : 'Show back',
                onPressed: () => setState(() => _showBack = !_showBack),
                icon: Icon(
                  _showBack
                      ? Icons.flip_to_front_outlined
                      : Icons.flip_to_back_outlined,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
