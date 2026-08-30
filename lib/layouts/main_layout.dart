import 'package:flutter/material.dart';

import '../widgets/authenticated_app_bar.dart';

class MainLayout extends StatelessWidget {
  final String title;
  final Widget child;

  const MainLayout({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      appBar: AuthenticatedAppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Container(
                  width: double.infinity,

                  padding: const EdgeInsets.all(25),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),

                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
