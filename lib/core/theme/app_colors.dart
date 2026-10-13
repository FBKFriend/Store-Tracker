import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Light mode
  static const lightPrimary = Color(0xFF2563EB);
  static const lightAccent = Color(0xFFF59E0B);
  static const lightBackground = Color(0xFFF8FAFC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF0F172A);
  static const lightError = Color(0xFFDC2626);

  // Dark mode
  static const darkPrimary = Color(0xFF60A5FA);
  static const darkAccent = Color(0xFFFBBF24);
  static const darkBackground = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF111A2E);
  static const darkText = Color(0xFFE2E8F0);
  static const darkError = Color(0xFFF87171);

  // Status colors (used for stock levels, debt, etc. later)
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
}
