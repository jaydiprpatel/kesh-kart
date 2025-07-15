import 'package:flutter/material.dart';

Route slideUpRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 1000), // Adjust if needed
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0); // Start from bottom
      const end = Offset.zero; // End at normal position
      const curve = Curves.easeInOut;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var offsetAnimation = animation.drive(tween);

      return SlideTransition(position: offsetAnimation, child: child);
    },
  );
}

Widget socialLoginButton({
  required IconData icon,
  required String text,
  required Color color,
  required Color textColor,
}) {
  return Container(
    width: 250,
    padding: const EdgeInsets.symmetric(horizontal: 15),
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: () {
        // Handle Social Login
      },
      icon: Icon(icon, color: textColor),
      label: Text(text, style: TextStyle(fontSize: 16, color: textColor)),
    ),
  );
}

//Button with animated gradient border
