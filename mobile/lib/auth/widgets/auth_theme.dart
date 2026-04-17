import 'package:flutter/material.dart';

abstract final class AuthTheme {
  static const Color deepMint = Color(0xFF17A2A2);
  static const Color mint = Color(0xFF90EE90);
  static const Color pageBg = Color(0xFFF6FFFA);

  static BoxDecoration pageGradientDecoration() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          pageBg,
          Color(0xFFE9FFF1),
          Color(0xFFD8FBE2),
        ],
      ),
    );
  }
}
