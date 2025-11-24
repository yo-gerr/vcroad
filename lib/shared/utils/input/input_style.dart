import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive.dart';

class InputStyles {
  // Colors
  static const Color inputFillColor = Color(0xFF001278);
  static const Color focusedBorderColor = Color(0xFF001278);
  static const Color labelTextColor = Colors.white;
  static const double borderRadiusValue = 12.0;

  // Const label style used for baseDecoration (non-responsive fallback)
  static const TextStyle labelStyle = TextStyle(
    color: labelTextColor,
    fontWeight: FontWeight.w600,
    fontSize: 14,
  );

  // Borders (const-friendly)
  static const OutlineInputBorder border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(borderRadiusValue)),
    borderSide: BorderSide(color: Color(0xFFBDBDBD), width: 1),
  );

  static const OutlineInputBorder focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(borderRadiusValue)),
    borderSide: BorderSide(color: focusedBorderColor, width: 2),
  );

  static const OutlineInputBorder errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(borderRadiusValue)),
    borderSide: BorderSide(color: Colors.red, width: 2),
  );

  // Label / text styles (responsive helper)
  static TextStyle labelStyleOf(BuildContext context) {
    final scaler = MediaQuery.of(context).textScaler;
    // TextScaler.scale is a function: call it with the base font size
    final fontSize = scaler.scale(14.0);
    return TextStyle(
      color: labelTextColor,
      fontWeight: FontWeight.w600,
      fontSize: fontSize,
    );
  }

  static const TextStyle fieldLabelStyle = TextStyle(
    color: Colors.black,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  // Provide a function (not const) to build a field label widget
  static Widget fieldLabel(String text) => Text(text, style: fieldLabelStyle);

  // Base decoration (const where possible)
  static const InputDecoration baseDecoration = InputDecoration(
    filled: true,
    fillColor: inputFillColor,
    labelStyle: labelStyle,
    hintStyle: TextStyle(color: Colors.white70), // <- added
    floatingLabelBehavior: FloatingLabelBehavior.never,
    border: border,
    enabledBorder: border,
    focusedBorder: focusedBorder,
    errorBorder: errorBorder,
    focusedErrorBorder: errorBorder,
    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    errorStyle: TextStyle(color: Colors.red, fontSize: 12),
  );

  // Reusable input decoration builder for overrides (avoids copying/manipulating const)
  static InputDecoration decoration({
    String? label,
    String? hint,
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
