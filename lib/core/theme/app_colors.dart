import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const primary = Color(0xFF001278);
  static const primaryAlt = Color(0xFF052676);
  static const primaryDark = Color(0xFF003049);
  static const primaryLight = Color(0x33001278);

  // Light palette
  static const background = Color(0xFFF7F5FA);
  static const surface = Colors.white;
  static const surfaceVariant = Color(0xFFF2F4F8);
  static const border = Color(0xFFBDBDBD);

  // Dark palette
  static const darkBackground = Color(0xFF081021);
  static const darkSurface = Color(0xFF111B2F);
  static const darkSurfaceVariant = Color(0xFF1A2743);
  static const darkBorder = Color(0xFF2D4A7A);
  static const darkTextSecondary = Color(0xFFB8C7E8);

  // Text
  static const textPrimary = Colors.black;
  static const textOnPrimary = Colors.white;
  static const textSecondary = Colors.white70;

  // Semantic
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFFFA726);
  static const error = Color(0xFFD32F2F);
  static const info = Color(0xFF1976D2);

  // Advisory categories (used by widget UIs; the category definitions
  // live in AdvisoryCategory model which references its own colors)
  static const advisoryRoadClosure = Color(0xFFD32F2F);
  static const advisoryStopAndGo = Color(0xFFFFA726);
  static const advisoryOneWay = Color(0xFF1976D2);
  static const advisoryConstruction = Color(0xFFF57C00);
  static const advisoryPartialLane = Color(0xFFFDD835);
  static const advisoryEvent = Color(0xFF7B1FA2);

  // Export-specific (advisory_export.dart)
  static const exportRed = Color(0xFFCC2B2B);
  static const exportRedLine = Color(0xFFCC0000);
  static const exportBlue = Color(0xFF0066CC);
  static const exportNearBlack = Color(0xFF111111);

  static Color primaryAdaptive(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? Colors.white : primary;
}
