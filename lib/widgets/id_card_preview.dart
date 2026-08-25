import 'package:flutter/material.dart';

import '../models/api_student.dart';
import '../models/card_template.dart';
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
    this.onEdit,
    this.onPrint,
  });

  final ApiStudent student;
  final String schoolName;
  final ApiService api;
  final CardTemplate template;
  final String? sessionName;
  final VoidCallback? onEdit;
  final VoidCallback? onPrint;

  String? get _photoUrl {
    final path = student.photoPath?.trim();

    if (path == null || path.isEmpty) {
      return null;
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    return path.startsWith('/')
        ? '${api.baseUrl}$path'
        : '${api.baseUrl}/$path';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
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
          ),
          SizedBox(
            height: 38,
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

  // ignore: unused_element
  Widget _buildCardBody(BuildContext context) {
    final photoUrl = _photoUrl;

    final name = student.fullName.trim().isEmpty
        ? 'Student'
        : student.fullName.trim();

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(9, 8, 9, 5),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            children: [
              // ------------------------------------------------------------
              // SCHOOL NAME
              // ------------------------------------------------------------
              Text(
                schoolName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  height: 1.0,
                ),
              ),

              const SizedBox(height: 2),

              // ------------------------------------------------------------
              // CARD TITLE
              // ------------------------------------------------------------
              const Text(
                'STUDENT ID CARD',
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 6),

              // ------------------------------------------------------------
              // PHOTO + BASIC INFORMATION
              // ------------------------------------------------------------
              SizedBox(
                height: 96,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 76,
                      height: 96,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xffeef2f7),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: photoUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 40,
                              color: AppColors.textSecondary,
                            )
                          : Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: AppColors.textSecondary,
                                );
                              },
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) {
                                  return child;
                                }

                                return const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    const SizedBox(width: 7),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              height: 1.05,
                            ),
                          ),

                          const SizedBox(height: 4),

                          _field('Adm. No.', student.admissionNo),

                          _field('Roll No.', student.rollNo),

                          _field('Stream', student.stream),

                          _field('Blood', student.bloodGroup),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 5),

              const Divider(height: 1, thickness: 1, color: Color(0xffd7dce5)),

              const SizedBox(height: 4),

              // ------------------------------------------------------------
              // PERSONAL INFORMATION
              // ------------------------------------------------------------
              SizedBox(
                height: 38,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _field('Father', student.fatherName),
                          _field('Mother', student.motherName),
                          _field('DOB', _formatDate(student.dob)),
                        ],
                      ),
                    ),

                    const SizedBox(width: 5),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _field('Mobile', student.mobile),
                          _field('Aadhaar', student.aadhaar),
                          _field('Address', student.address),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // IMPORTANT:
              // This pushes the signature/session area to the bottom
              // of the fixed card body.
              const Spacer(),

              // ------------------------------------------------------------
              // PRINCIPAL SIGNATURE PLACEHOLDER
              // ------------------------------------------------------------
              SizedBox(
                height: 27,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 88,
                      height: 25,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xffb8bec9),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: -7,
                            left: 4,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: Colors.white),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 3),
                                child: Text(
                                  "Principal's Signature",
                                  style: TextStyle(
                                    fontSize: 5.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xff555b66),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 2),

              // ------------------------------------------------------------
              // SESSION
              // ------------------------------------------------------------
              SizedBox(
                height: 21,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: AppColors.primary),
                  child: Center(
                    child: Text(
                      'Session: ${sessionName ?? 'Not specified'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // --------------------------------------------------------------
        // PENDING STATUS
        // --------------------------------------------------------------
        Positioned(
          top: 7,
          right: 7,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xfffff4cf),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 6, color: Color(0xffe2a800)),
                SizedBox(width: 3),
                Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Color(0xffb57d00),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, String? value, {int maxLines = 1}) {
    final text = value?.trim();

    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: RichText(
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: const TextStyle(
            fontSize: 8.2,
            color: Color(0xff303641),
            height: 1.08,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }

  String? _formatDate(DateTime? value) {
    if (value == null) {
      return null;
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');

    return '$day/$month/${value.year}';
  }
}
