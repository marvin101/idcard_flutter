import 'package:flutter/material.dart';

import '../models/api_student.dart';
import '../models/card_template.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/template_card.dart';

class CardDesignerScreen extends StatefulWidget {
  const CardDesignerScreen({
    super.key,
    required this.schoolUuid,
    required this.api,
    required this.initialTemplate,
  });

  final String schoolUuid;
  final ApiService api;
  final CardTemplate initialTemplate;

  @override
  State<CardDesignerScreen> createState() => _CardDesignerScreenState();
}

class _CardDesignerScreenState extends State<CardDesignerScreen> {
  late CardTemplate _template;
  late final TextEditingController _name;
  late final TextEditingController _schoolTitle;
  late final TextEditingController _schoolSubtitle;
  bool _saving = false;

  static final _sampleStudent = ApiStudent(
    uuid: 'preview',
    sessionUuid: 'preview',
    classUuid: 'preview',
    sectionUuid: 'preview',
    admissionNo: 'COM/52',
    rollNo: '18',
    stream: 'COMMERCE',
    fullName: 'Piyush Kumar Verma',
    fatherName: 'Tirath Verma',
    motherName: 'Dewanti Devi',
    dob: DateTime(2006, 6, 30),
    bloodGroup: 'A+',
    mobile: '9693836200',
    aadhaar: '216232301889',
    address: 'Basai Toli, Sundi, Ranchi',
    isActive: true,
  );

  @override
  void initState() {
    super.initState();
    _template = widget.initialTemplate;
    _name = TextEditingController(text: _template.name);
    _schoolTitle = TextEditingController(text: _template.schoolTitle);
    _schoolSubtitle = TextEditingController(text: _template.schoolSubtitle);
  }

  @override
  void dispose() {
    _name.dispose();
    _schoolTitle.dispose();
    _schoolSubtitle.dispose();
    super.dispose();
  }

  void _syncText() {
    _template = _template.copyWith(
      name: _name.text.trim(),
      schoolTitle: _schoolTitle.text.trim(),
      schoolSubtitle: _schoolSubtitle.text.trim(),
    );
    setState(() {});
  }

  Future<void> _save() async {
    _syncText();
    if (_template.name.isEmpty || _template.schoolTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template and school names are required.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await widget.api.saveCardTemplate(
        widget.schoolUuid,
        _template,
      );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save template: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff5f7fb),
    appBar: AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      title: const Text('Card designer'),
      actions: [
        TextButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Save'),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final controls = _controls();
        final preview = _preview();
        return constraints.maxWidth >= 900
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 390, child: controls),
                  Expanded(child: preview),
                ],
              )
            : ListView(
                children: [
                  SizedBox(height: 380, child: preview),
                  controls,
                ],
              );
      },
    ),
  );

  Widget _preview() => Container(
    color: const Color(0xffe7ebf1),
    padding: const EdgeInsets.all(32),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: TemplateCard(
          student: _sampleStudent,
          template: _template,
          sessionName: '2026-2028',
        ),
      ),
    ),
  );

  Widget _controls() => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      Text('Template settings', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      const Text(
        'This first test template follows the uploaded blue school-card design.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 20),
      _textField(_name, 'Template name'),
      _textField(_schoolTitle, 'School title'),
      _textField(_schoolSubtitle, 'School subtitle'),
      const SizedBox(height: 8),
      _palette('Header colour', _template.primaryColor, (value) {
        setState(() => _template = _template.copyWith(primaryColor: value));
      }),
      _palette('Heading colour', _template.accentColor, (value) {
        setState(() => _template = _template.copyWith(accentColor: value));
      }),
      _palette('Photo border', _template.photoBorderColor, (value) {
        setState(() => _template = _template.copyWith(photoBorderColor: value));
      }),
      const Divider(height: 28),
      _toggle(
        'Show stream',
        _template.showStream,
        (v) => _template = _template.copyWith(showStream: v),
      ),
      _toggle(
        'Show blood group',
        _template.showBloodGroup,
        (v) => _template = _template.copyWith(showBloodGroup: v),
      ),
      _toggle(
        'Show mobile number',
        _template.showMobile,
        (v) => _template = _template.copyWith(showMobile: v),
      ),
      _toggle(
        'Show address',
        _template.showAddress,
        (v) => _template = _template.copyWith(showAddress: v),
      ),
      _toggle(
        'Mask Aadhaar except last four digits',
        _template.maskAadhaar,
        (v) => _template = _template.copyWith(maskAadhaar: v),
      ),
      _toggle(
        'Rounded photo frame',
        _template.roundedPhoto,
        (v) => _template = _template.copyWith(roundedPhoto: v),
      ),
    ],
  );

  Widget _textField(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      onChanged: (_) => _syncText(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _palette(String label, Color selected, ValueChanged<Color> onChanged) {
    const colors = [
      Color(0xff242c61),
      Color(0xff005b96),
      Color(0xff00695c),
      Color(0xff7b1f32),
      Color(0xffffe000),
      Color(0xffe52b24),
      Color(0xff00aee8),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: colors
                .map(
                  (color) => InkWell(
                    onTap: () => onChanged(color),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == selected
                              ? Colors.black
                              : Colors.white,
                          width: color == selected ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> apply) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: (next) => setState(() => apply(next)),
      );
}
