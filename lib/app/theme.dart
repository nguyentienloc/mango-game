import 'package:flutter/material.dart';

class IceColors {
  static const sky = Color(0xFFE6F6FF);
  static const ice = Color(0xFFBDE7FF);
  static const frost = Color(0xFF8FD3FF);
  static const deep = Color(0xFF1E5AA8);
  static const glow = Color(0xFFFFF59D);
}

ThemeData buildTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: IceColors.deep),
      scaffoldBackgroundColor: IceColors.sky,
      useMaterial3: true,
    );
