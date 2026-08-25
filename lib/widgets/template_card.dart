import 'package:flutter/material.dart';

import '../models/api_student.dart';
import '../models/card_template.dart';

class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.student,
    required this.template,
    required this.sessionName,
    this.photoUrl,
  });

  final ApiStudent student;
  final CardTemplate template;
  final String? sessionName;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 85.6 / 53.98,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffcfd4dc)),
        boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 8)],
      ),
      child: ClipRect(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(7, 5, 7, 4),
                child: Column(
                  children: [
                    Expanded(flex: 6, child: _identityRow()),
                    const SizedBox(height: 3),
                    Expanded(flex: 4, child: _details()),
                  ],
                ),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    ),
  );

  Widget _header() => Container(
    width: double.infinity,
    color: template.primaryColor,
    padding: const EdgeInsets.fromLTRB(6, 4, 6, 3),
    child: Column(
      children: [
        Text(
          template.schoolTitle.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: template.accentColor,
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          template.schoolSubtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 5.5, height: 1),
        ),
      ],
    ),
  );

  Widget _identityRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        width: 35,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 35,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school, color: template.primaryColor, size: 22),
                if (template.showStream) ...[
                  const SizedBox(height: 3),
                  _micro('Stream', student.stream),
                ],
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Column(
          children: [
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xffedf1f5),
                  border: Border.all(
                    color: template.photoBorderColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(
                    template.roundedPhoto ? 8 : 0,
                  ),
                ),
                child: photoUrl == null
                    ? const Center(
                        child: Icon(Icons.person, size: 40, color: Colors.grey),
                      )
                    : Image.network(
                        photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              student.fullName.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xffe52b24),
                fontSize: 7.5,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 4),
      SizedBox(
        width: 38,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 38,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (template.showBloodGroup) ...[
                  const Icon(
                    Icons.water_drop,
                    color: Color(0xffe52b24),
                    size: 20,
                  ),
                  _micro('Blood', student.bloodGroup),
                  const SizedBox(height: 4),
                ],
                _micro('Session', sessionName),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _details() {
    final aadhaar = template.maskAadhaar
        ? maskAadhaarValue(student.aadhaar)
        : student.aadhaar;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xfffafafa), Color(0xffedf0f2)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: LayoutBuilder(
          builder: (context, constraints) => FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: constraints.maxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line('F. Name', student.fatherName),
                  _line('M. Name', student.motherName),
                  _line('Dob', _date(student.dob)),
                  _line('Adm No.', student.admissionNo),
                  _line('Aadhaar No.', aadhaar),
                  if (template.showMobile) _line('Mob No.', student.mobile),
                  if (template.showAddress)
                    _line('Address', student.address, maxLines: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer() => Container(
    height: 11,
    color: template.primaryColor,
    padding: const EdgeInsets.symmetric(horizontal: 5),
    alignment: Alignment.centerRight,
    child: const Text(
      'Principal Sig.',
      style: TextStyle(color: Colors.white, fontSize: 4.5, height: 1),
    ),
  );

  Widget _line(String label, String? value, {int maxLines = 1}) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  : ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: text),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 5.8,
        height: 1.05,
        color: Color(0xff222222),
      ),
    );
  }

  Widget _micro(String label, String? value) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 4.5, fontWeight: FontWeight.w700),
      ),
      Text(
        value?.trim().isNotEmpty == true ? value!.trim() : '-',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 5,
          fontWeight: FontWeight.w900,
          color: Color(0xffe52b24),
        ),
      ),
    ],
  );

  String? _date(DateTime? value) => value == null
      ? null
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
