import 'package:flutter/material.dart';

class StudentFormController {
  /// Form Key
  final formKey = GlobalKey<FormState>();

  // -----------------------------
  // Personal Information
  // -----------------------------

  final fullNameController = TextEditingController();
  final fatherNameController = TextEditingController();
  final motherNameController = TextEditingController();
  final dobController = TextEditingController();

  // -----------------------------
  // Academic Information
  // -----------------------------

  final admissionNoController = TextEditingController();
  final rollNoController = TextEditingController();
  final classController = TextEditingController();
  final sectionController = TextEditingController();
  final streamController = TextEditingController();
  final sessionController = TextEditingController();
  final houseController = TextEditingController();

  // -----------------------------
  // Contact Information
  // -----------------------------

  final mobileController = TextEditingController();
  final aadhaarController = TextEditingController();
  final addressController = TextEditingController();

  // -----------------------------
  // Dropdown Values
  // -----------------------------

  String? bloodGroup;

  // -----------------------------
  // Focus Nodes
  // -----------------------------

  final fullNameFocus = FocusNode();
  final fatherNameFocus = FocusNode();
  final motherNameFocus = FocusNode();
  final dobFocus = FocusNode();

  final admissionFocus = FocusNode();
  final rollFocus = FocusNode();
  final classFocus = FocusNode();
  final sectionFocus = FocusNode();
  final streamFocus = FocusNode();
  final sessionFocus = FocusNode();
  final houseFocus = FocusNode();

  final mobileFocus = FocusNode();
  final aadhaarFocus = FocusNode();
  final addressFocus = FocusNode();

  // -----------------------------
  // Validation
  // -----------------------------

  bool validate() {
    return formKey.currentState?.validate() ?? false;
  }

  // -----------------------------
  // Dispose
  // -----------------------------

  void dispose() {
    final controllers = [
      fullNameController,
      fatherNameController,
      motherNameController,
      dobController,
      admissionNoController,
      rollNoController,
      classController,
      sectionController,
      streamController,
      sessionController,
      houseController,
      mobileController,
      aadhaarController,
      addressController,
    ];

    for (final controller in controllers) {
      controller.dispose();
    }

    final focusNodes = [
      fullNameFocus,
      fatherNameFocus,
      motherNameFocus,
      dobFocus,
      admissionFocus,
      rollFocus,
      classFocus,
      sectionFocus,
      streamFocus,
      sessionFocus,
      houseFocus,
      mobileFocus,
      aadhaarFocus,
      addressFocus,
    ];

    for (final node in focusNodes) {
      node.dispose();
    }
  }
}
