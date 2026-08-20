import 'package:flutter/material.dart';

import '../models/api_student.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class IdCardPreview extends StatelessWidget {
  const IdCardPreview({
    super.key,
    required this.student,
    required this.schoolName,
    required this.api,
    this.sessionName,
    this.onEdit,
  });

  final ApiStudent student;
  final String schoolName;
  final ApiService api;
  final String? sessionName;
  final VoidCallback? onEdit;

  String? get _photoUrl {
    final path = student.photoPath?.trim();
    if (path == null || path.isEmpty) return null;
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
          Expanded(child: _buildCardBody(context)),
          SizedBox(
            height: 42,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Student'),
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
    );
  }

  Widget _buildCardBody(BuildContext context) {
    final photoUrl = _photoUrl;
    final name = student.fullName.trim().isEmpty ? 'Student' : student.fullName;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            children: [
              Text(
                schoolName.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'STUDENT ID CARD',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 90,
                    height: 112,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xffeef2f7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: photoUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 42,
                            color: AppColors.textSecondary,
                          )
                        : Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.person,
                              size: 42,
                              color: AppColors.textSecondary,
                            ),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        _field('Adm. No.', student.admissionNo),
                        _field('Roll No.', student.rollNo),
                        _field('Stream', student.stream),
                        _field('Blood', student.bloodGroup),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 5),
              _field('Father', student.fatherName),
              _field('Mother', student.motherName),
              _field('DOB', _formatDate(student.dob)),
              _field('Mobile', student.mobile),
              _field('Aadhaar', student.aadhaar),
              _field('Address', student.address, maxLines: 2),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xffe4e8f0))),
                ),
                child: Text(
                  'Session: ${sessionName ?? 'Not specified'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xfffff4cf),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 7, color: Color(0xffe2a800)),
                SizedBox(width: 4),
                Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 10,
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
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xff303641),
            height: 1.25,
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
    if (value == null) return null;
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}
