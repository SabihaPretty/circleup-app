import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xff4f46e5);
  static const Color secondary = Color(0xff9333ea);
  static const Color accent = Color(0xffec4899);
  static const Color sky = Color(0xff06b6d4);
  static const Color success = Color(0xff22c55e);
  static const Color warning = Color(0xfff59e0b);
  static const Color dark = Color(0xff111827);
  static const Color softBg = Color(0xfff6f7fb);

  static LinearGradient mainGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xff4f46e5),
      Color(0xff7c3aed),
      Color(0xffec4899),
    ],
  );

  static LinearGradient darkGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xff111827),
      Color(0xff312e81),
      Color(0xff581c87),
    ],
  );

  static BoxDecoration premiumCardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(28),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.08),
        blurRadius: 22,
        offset: const Offset(0, 12),
      ),
    ],
  );
}
