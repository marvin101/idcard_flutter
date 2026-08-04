import 'package:flutter/material.dart';
import '../layouts/main_layout.dart';
import '../widgets/dob_input.dart';

class StudentFormScreen extends StatelessWidget {
  const StudentFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: "Add Student",

      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: "Full Name",
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 20),

          TextField(
            decoration: InputDecoration(
              labelText: "Father Name",
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 20),

          TextField(
            decoration: InputDecoration(
              labelText: "Mother Name",
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 20),

          TextField(
            decoration: InputDecoration(
              labelText: "Address",
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 20),

          TextField(
            decoration: InputDecoration(
              labelText: "Mobile Number",
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 20),

          DobInput(label: "Date of Birth"),

          SizedBox(height: 20),

          TextField(
            decoration: InputDecoration(
              labelText: "Class",
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 20),

          TextField(
            decoration: InputDecoration(
              labelText: "Section",
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 20),

          TextField(
            decoration: InputDecoration(
              labelText: "Roll Number",
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 20),

          TextField(
            decoration: InputDecoration(
              labelText: "Admission Number",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
