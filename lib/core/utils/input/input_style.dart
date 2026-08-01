import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/core/theme/app_text_styles.dart';
import 'package:vcroad/core/utils/responsive/responsive.dart';

class InputStyles {
  static const Color inputFillColor = AppColors.primary;
  static const Color focusedBorderColor = AppColors.primary;
  static const Color labelTextColor = Colors.white;
  static const double borderRadiusValue = 12.0;

  static const TextStyle labelStyle = AppTextStyles.label;

  static const OutlineInputBorder border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(borderRadiusValue)),
    borderSide: BorderSide(color: AppColors.border, width: 1),
  );

  static const OutlineInputBorder focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(borderRadiusValue)),
    borderSide: BorderSide(color: focusedBorderColor, width: 2),
  );

  static const OutlineInputBorder errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(borderRadiusValue)),
    borderSide: BorderSide(color: AppColors.error, width: 2),
  );

  static TextStyle labelStyleOf(BuildContext context) {
    final scaler = MediaQuery.of(context).textScaler;
    final fontSize = scaler.scale(14.0);
    return TextStyle(
      color: labelTextColor,
      fontWeight: FontWeight.w600,
      fontSize: fontSize,
    );
  }

  static const TextStyle fieldLabelStyle = AppTextStyles.labelLarge;

  static Widget fieldLabel(String text) => Text(text, style: fieldLabelStyle);

  static const InputDecoration baseDecoration = InputDecoration(
    filled: true,
    fillColor: inputFillColor,
    labelStyle: labelStyle,
    hintStyle: TextStyle(color: Colors.white70),
    helperStyle: TextStyle(color: Colors.white70, fontSize: 12),
    floatingLabelBehavior: FloatingLabelBehavior.never,
    border: border,
    enabledBorder: border,
    focusedBorder: focusedBorder,
    errorBorder: errorBorder,
    focusedErrorBorder: errorBorder,
    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    errorStyle: AppTextStyles.error,
  );

  // Reusable input decoration builder for overrides (avoids copying/manipulating const)
  static InputDecoration decoration({
    String? label,
    String? hint,
    String? helperText,
    Widget? prefix,
    Widget? suffix,
    Widget? suffixIcon,
    Widget? prefixIcon,
    bool filled = true,
    Color? fillColor,
    EdgeInsets? contentPadding,
    FloatingLabelBehavior? floatingLabelBehavior,
    TextStyle? labelTextStyle,
    bool isDense = false,
  }) {
    return baseDecoration.copyWith(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      prefix: prefix,
      suffix: suffix,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: filled,
      fillColor: fillColor ?? baseDecoration.fillColor,
      contentPadding: contentPadding ?? baseDecoration.contentPadding,
      floatingLabelBehavior:
          floatingLabelBehavior ?? baseDecoration.floatingLabelBehavior,
      labelStyle: labelTextStyle ?? baseDecoration.labelStyle,
      isDense: isDense,
    );
  }

  // Make input formatters static so they're not recreated per instance
  static final List<TextInputFormatter> phoneInputFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(11),
  ];

  // Helper to get responsive content padding if you use ResponsiveBuilder
  static EdgeInsets responsiveContentPadding(ResponsiveInfo info) {
    final horizontal = info.horizontalPadding / 2;
    final vertical = info.scale(12.0);
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }
}
