import 'package:flutter/material.dart';

class DropdownStyles {
  static const Color dropdownBackgroundColor = Color(0xFF001278);
  static const Color dropdownItemTextColor = Colors.white;
  static const double dropdownItemHeight = 48.0;
  static const double dropdownBorderRadius = 8.0;
  static const int visibleItemCount = 4;

  static const TextStyle itemTextStyle = TextStyle(
    color: dropdownItemTextColor,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    fontFamily: 'Poppins',
  );

  static const TextStyle hintTextStyle = TextStyle(
    color: dropdownItemTextColor,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    fontFamily: 'Poppins',
  );

  static BoxDecoration dropdownDecoration = BoxDecoration(
    color: dropdownBackgroundColor,
    borderRadius: BorderRadius.circular(dropdownBorderRadius),
  );

  static InputDecoration searchDecoration = InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    hintText: 'Search barangay...',
    hintStyle: const TextStyle(color: Colors.white70),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(dropdownBorderRadius)),
      borderSide: const BorderSide(color: Colors.white, width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(dropdownBorderRadius)),
      borderSide: const BorderSide(color: Colors.white, width: 2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(dropdownBorderRadius)),
      borderSide: const BorderSide(color: Colors.white, width: 2),
    ),
  );
}
