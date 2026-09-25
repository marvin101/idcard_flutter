import 'package:flutter/material.dart';

import '../widgets/authenticated_app_bar.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({
    super.key,
    required this.title,
    required this.child,
    this.compactMobile = false,
    this.mobileBreakpoint = 700,
  });

  final String title;
  final Widget child;

  /// Enables the compact phone layout for screens that explicitly opt in.
  ///
  /// Desktop/tablet behavior remains unchanged.
  final bool compactMobile;

  final double mobileBreakpoint;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    final useCompactMobileLayout =
        compactMobile && screenWidth < mobileBreakpoint;

    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),

      appBar: AuthenticatedAppBar(
        title: Text(title),
        compact: useCompactMobileLayout,
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: useCompactMobileLayout
                ? EdgeInsets.zero
                : const EdgeInsets.all(25),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Container(
                  width: double.infinity,

                  padding: useCompactMobileLayout
                      ? EdgeInsets.zero
                      : const EdgeInsets.all(25),

                  decoration: useCompactMobileLayout
                      ? null
                      : BoxDecoration(
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
          );
        },
      ),
    );
  }
}
