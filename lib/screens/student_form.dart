import 'package:flutter/material.dart';

import '../layouts/main_layout.dart';
import '../sections/personal_information_section.dart';

class StudentFormScreen extends StatelessWidget {
  const StudentFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainLayout(
      title: "Add Student",

      child: PersonalInformationSection(),
    );
  }
}
