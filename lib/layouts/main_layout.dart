import 'package:flutter/material.dart';

class MainLayout extends StatelessWidget {
  final String title;
  final Widget child;

  const MainLayout({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),

      body: Column(
        children: [
          // HEADER
          Container(
            height: 75,
            width: double.infinity,
            color: const Color(0xff1f2d50),

            padding: const EdgeInsets.symmetric(horizontal: 25),

            child: const Row(
              children: [
                Icon(Icons.badge, color: Colors.white, size: 28),

                SizedBox(width: 12),

                Text(
                  "ID Card Master",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // NAVIGATION
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(15),

            child: Row(
              children: [
                _navButton(Icons.dashboard, "Dashboard"),
                const SizedBox(width: 10),

                _navButton(Icons.people, "Students"),
                const SizedBox(width: 10),

                _navButton(Icons.add, "Add"),
                const SizedBox(width: 10),

                _navButton(Icons.palette, "Design"),
                const SizedBox(width: 10),

                _navButton(Icons.badge_outlined, "Cards"),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(25),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Center(
                    child: Container(
                      width: 900,

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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, String text) {
    return ElevatedButton.icon(
      onPressed: () {},

      icon: Icon(icon),

      label: Text(text),

      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.indigo,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
  }
}
