import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/public_form.dart';
import '../services/api_service.dart';

class PublicStudentFormScreen extends StatefulWidget {
  const PublicStudentFormScreen({
    super.key,
    required this.token,
    required this.api,
    this.pickPhoto,
  });
  final String token;
  final ApiService api;
  final Future<XFile?> Function()? pickPhoto;

  @override
  State<PublicStudentFormScreen> createState() =>
      _PublicStudentFormScreenState();
}

class _PublicStudentFormScreenState extends State<PublicStudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _selected = {};
  PublicFormView? _form;
  XFile? _photo;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final form = await widget.api.getPublicForm(widget.token);
      for (final field in form.fields) {
        if (field.dataType != 'select') {
          _controllers[field.key] = TextEditingController();
        }
      }
      _form = form;
    } catch (error) {
      _error = error.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<Map<String, String>> _options(PublicFormField field) {
    if (field.key != 'section_uuid') return field.options;
    final classUuid = _selected['class_uuid'];
    return field.options
        .where((item) => item['parent_uuid'] == classUuid)
        .toList();
  }

  Widget _field(PublicFormField field) {
    final label = '${field.label}${field.required ? ' *' : ''}';
    if (field.dataType == 'select') {
      final options = _options(field);
      return DropdownButtonFormField<String>(
        key: Key('public-field-${field.key}'),
        initialValue: _selected[field.key],
        decoration: InputDecoration(labelText: label),
        items: options
            .map(
              (item) => DropdownMenuItem(
                value: item['value'],
                child: Text(item['label'] ?? ''),
              ),
            )
            .toList(),
        validator: (value) => field.required && (value == null || value.isEmpty)
            ? '${field.label} is required'
            : null,
        onChanged: (value) => setState(() {
          _selected[field.key] = value;
          if (field.key == 'class_uuid') _selected.remove('section_uuid');
        }),
      );
    }
    final controller = _controllers[field.key]!;
    final multiline = field.dataType == 'multiline';
    return TextFormField(
      key: Key('public-field-${field.key}'),
      controller: controller,
      readOnly: field.dataType == 'date',
      maxLines: multiline ? 4 : 1,
      keyboardType: field.dataType == 'number'
          ? const TextInputType.numberWithOptions(decimal: true)
          : field.dataType == 'phone'
          ? TextInputType.phone
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: field.dataType == 'date'
            ? const Icon(Icons.calendar_month)
            : null,
      ),
      validator: (value) =>
          field.required && (value == null || value.trim().isEmpty)
          ? '${field.label} is required'
          : null,
      onTap: field.dataType == 'date'
          ? () async {
              final value = await showDatePicker(
                context: context,
                firstDate: DateTime(1900),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                initialDate: DateTime(2010),
              );
              if (value != null) {
                controller.text = value.toIso8601String().split('T').first;
              }
            }
          : null,
    );
  }

  Future<void> _pickPhoto() async {
    final photo =
        await (widget.pickPhoto?.call() ??
            ImagePicker().pickImage(source: ImageSource.gallery));
    if (photo == null) return;
    if (await photo.length() > _form!.maxPhotoSizeBytes) {
      setState(
        () => _error =
            'Photo exceeds the ${(_form!.maxPhotoSizeBytes / 1024 / 1024).round()} MB limit.',
      );
      return;
    }
    final name = photo.name.toLowerCase();
    if (!name.endsWith('.jpg') &&
        !name.endsWith('.jpeg') &&
        !name.endsWith('.png') &&
        !name.endsWith('.webp')) {
      setState(() => _error = 'Choose a JPEG, PNG, or WebP image.');
      return;
    }
    setState(() {
      _photo = photo;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_form!.photoRequired && _photo == null) {
      setState(() => _error = 'Photo is required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final data = <String, dynamic>{};
    final custom = <Map<String, dynamic>>[];
    for (final field in _form!.fields) {
      final value = field.dataType == 'select'
          ? _selected[field.key]
          : _controllers[field.key]!.text.trim();
      if (value == null || value.isEmpty) continue;
      if (field.kind == 'custom') {
        custom.add({'field_uuid': field.fieldUuid, 'value': value});
      } else {
        data[field.key] = value;
      }
    }
    data['custom_fields'] = custom;
    try {
      _success = await widget.api.submitPublicForm(
        token: widget.token,
        studentData: data,
        photo: _photo,
      );
    } catch (error) {
      _error = error.toString();
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_form == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off, size: 52),
                const SizedBox(height: 12),
                const Text(
                  'This form is unavailable.',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'The link may be inactive or expired.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_success != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  _success!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('Your details are Pending review by the school.'),
              ],
            ),
          ),
        ),
      );
    }

    final form = _form!;
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (form.schoolLogoUrl != null)
                          Center(
                            child: Image.network(
                              form.schoolLogoUrl!,
                              height: 80,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        Text(
                          form.schoolName,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          form.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (form.instructions?.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          Text(form.instructions!, textAlign: TextAlign.center),
                        ],
                        const SizedBox(height: 24),
                        for (final field in form.fields) ...[
                          _field(field),
                          const SizedBox(height: 14),
                        ],
                        if (form.allowPhoto)
                          OutlinedButton.icon(
                            key: const Key('public-photo-picker'),
                            onPressed: _pickPhoto,
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: Text(
                              _photo == null
                                  ? 'Choose student photo${form.photoRequired ? ' *' : ''}'
                                  : _photo!.name,
                            ),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        const SizedBox(height: 8),
                        FilledButton(
                          key: const Key('submit-public-form'),
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Submit for review'),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your submission will be Pending until reviewed by the school.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
