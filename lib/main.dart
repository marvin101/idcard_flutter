import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';

import 'screens/student_form.dart';

import 'providers/student_form_provider.dart';

import 'repositories/student_repository.dart';
import 'repositories/sqlite_student_repository.dart';

import 'services/sqlite_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        //---------------------------------------------------------
        // SQLite Service
        //---------------------------------------------------------
        Provider<SQLiteService>(create: (_) => SQLiteService()),

        //---------------------------------------------------------
        // Student Repository
        //---------------------------------------------------------
        Provider<StudentRepository>(
          create: (context) =>
              SqliteStudentRepository(context.read<SQLiteService>()),
        ),

        //---------------------------------------------------------
        // Student Form Provider
        //---------------------------------------------------------
        ChangeNotifierProvider<StudentFormProvider>(
          create: (context) => StudentFormProvider(
            repository: context.read<StudentRepository>(),
          ),
        ),
      ],

      child: MaterialApp(
        debugShowCheckedModeBanner: false,

        theme: AppTheme.lightTheme,

        home: const StudentFormScreen(),
      ),
    );
  }
}
