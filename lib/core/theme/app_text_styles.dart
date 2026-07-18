import 'package:flutter/material.dart';

class AppTextStyles {
  static const String _font = 'Poppins';

  // Display / Headings
  static const displayLarge = TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: _font);
  static const displayMedium = TextStyle(fontSize: 26, fontWeight: FontWeight.w700, fontFamily: _font);
  static const heading1 = TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: _font);
  static const heading2 = TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: _font);
  static const heading3 = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, fontFamily: _font);
  static const heading4 = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: _font);

  // Body
  static const bodyLarge = TextStyle(fontSize: 16, fontWeight: FontWeight.normal, fontFamily: _font);
  static const body = TextStyle(fontSize: 15, fontWeight: FontWeight.normal, fontFamily: _font);
  static const bodySmall = TextStyle(fontSize: 14, fontWeight: FontWeight.normal, fontFamily: _font);

  // Labels
  static const labelLarge = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: _font);
  static const label = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: _font);
  static const labelSmall = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: _font);

  // Button
  static const button = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: _font);

  // Caption / Helper
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.normal, fontFamily: _font);
  static const error = TextStyle(fontSize: 12, color: Colors.red, fontFamily: _font);
}
