import 'package:flutter/material.dart';

import '../layouts/main_layout.dart';
import '../models/api_personnel.dart';
import '../services/api_service.dart';

class PersonnelFormScreen extends StatefulWidget {
  const PersonnelFormScreen({
    super.key,
    required this.schoolUuid,
    required this.api,
    required this.personnelType,
    this.personnel,
  });

  final String schoolUuid;
  final ApiService api;
  final PersonnelType personnelType;
  final ApiPersonnel? personnel;

  @override
  State<PersonnelFormScreen> createState() => _PersonnelFormScreenState();
}

class _PersonnelFormScreenState extends State<PersonnelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _employeeNo;
  late final TextEditingController _fullName;
  late final TextEditingController _designation;
  late final TextEditingController _department;
  late final TextEditingController _mobile;
  late final TextEditingController _email;
  late final TextEditingController _address;
  DateTime? _dob;
  String? _gender;
  String? _bloodGroup;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final value = widget.personnel;
    _employeeNo = TextEditingController(text: value?.employeeNo);
    _fullName = TextEditingController(text: value?.fullName);
    _designation = TextEditingController(text: value?.designation);
    _department = TextEditingController(text: value?.department);
    _mobile = TextEditingController(text: value?.mobile);
    _email = TextEditingController(text: value?.email);
    _address = TextEditingController(text: value?.address);
    _dob = value?.dob;
    _gender = value?.gender;
    _bloodGroup = value?.bloodGroup;
  }

  @override
  void dispose() {
    for (final controller in [
      _employeeNo,
      _fullName,
      _designation,
      _department,
      _mobile,
      _email,
      _address,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final existing = widget.personnel;
      if (existing == null) {
        await widget.api.createPersonnel(
          schoolUuid: widget.schoolUuid,
          personnelType: widget.personnelType,
          employeeNo: _employeeNo.text.trim(),
          fullName: _fullName.text.trim(),
          designation: _optional(_designation),
          department: _optional(_department),
          dob: _dob,
          gender: _gender,
          bloodGroup: _bloodGroup,
          mobile: _optional(_mobile),
          email: _optional(_email),
          address: _optional(_address),
        );
      } else {
        await widget.api.updatePersonnel(
          schoolUuid: widget.schoolUuid,
          personnelUuid: existing.uuid,
          personnelType: widget.personnelType,
          employeeNo: _employeeNo.text.trim(),
          fullName: _fullName.text.trim(),
          designation: _optional(_designation),
          department: _optional(_department),
          dob: _dob,
          gender: _gender,
          bloodGroup: _bloodGroup,
          mobile: _optional(_mobile),
          email: _optional(_email),
          address: _optional(_address),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.personnelType.label} ${existing == null ? 'created' : 'updated'} successfully.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDob() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (selected != null) setState(() => _dob = selected);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.personnel != null;
    return MainLayout(
      title: '${editing ? 'Edit' : 'Add'} ${widget.personnelType.label}',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.personnelType.label} identity record',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _field(
                  controller: _employeeNo,
                  label: 'Employee number',
                  required: true,
                ),
                _field(
                  controller: _fullName,
                  label: 'Full name',
                  required: true,
                ),
                _field(controller: _designation, label: 'Designation'),
                _field(controller: _department, label: 'Department'),
                SizedBox(
                  width: 320,
                  child: DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) => setState(() => _gender = value),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: DropdownButtonFormField<String>(
                    initialValue: _bloodGroup,
                    decoration: const InputDecoration(
                      labelText: 'Blood group',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => setState(() => _bloodGroup = value),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of birth',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _dob == null
                                ? 'Not set'
                                : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                          ),
                        ),
                        IconButton(
                          onPressed: _pickDob,
                          icon: const Icon(Icons.calendar_month_outlined),
                        ),
                        if (_dob != null)
                          IconButton(
                            onPressed: () => setState(() => _dob = null),
                            icon: const Icon(Icons.clear),
                          ),
                      ],
                    ),
                  ),
                ),
                _field(controller: _mobile, label: 'Mobile'),
                _field(controller: _email, label: 'Email'),
                SizedBox(
                  width: 656,
                  child: TextFormField(
                    controller: _address,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _saving ? 'Saving...' : 'Save ${widget.personnelType.label}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool required = false,
  }) => SizedBox(
    width: 320,
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (value) =>
                value?.trim().isEmpty == true ? '$label is required' : null
          : null,
    ),
  );
}
