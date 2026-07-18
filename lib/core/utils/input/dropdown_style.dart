import 'package:flutter/material.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/core/theme/app_text_styles.dart';

class DropdownStyles {
  static const Color dropdownBackgroundColor = AppColors.primary;
  static const Color dropdownItemTextColor = Colors.white;
  static const double dropdownItemHeight = 48.0;
  static const double dropdownBorderRadius = 8.0;
  static const int visibleItemCount = 4;

  static const TextStyle itemTextStyle = AppTextStyles.label;

  static const TextStyle hintTextStyle = AppTextStyles.label;

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
