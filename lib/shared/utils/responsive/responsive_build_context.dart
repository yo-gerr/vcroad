import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_scope.dart';

extension ResponsiveBuildContext on BuildContext {
  ResponsiveInfo get responsive => ResponsiveScope.of(this);

  bool get isMobile => responsive.isMobile;
  bool get isTablet => responsive.isTablet;
  bool get isDesktop => responsive.isDesktop;

  double scale(
    double value, {
    double mobileFactor = 0.8,
    double tabletFactor = 0.9,
  }) => responsive.scale(
    value,
    mobileFactor: mobileFactor,
    tabletFactor: tabletFactor,
  );

  double scaleFont(double baseSize, {double cap = 1.25}) =>
      responsive.scaleFont(baseSize, cap: cap);

  double get horizontalPadding => responsive.horizontalPadding;
  double get verticalPadding => responsive.verticalPadding;

  double get logoSize => responsive.logoSize;
  double get maxFormWidth => responsive.maxFormWidth;

  int cacheWidthForImage(double desiredLogicalWidth) {
    final dpr = MediaQuery.of(this).devicePixelRatio;
    return responsive.cacheWidthForImage(desiredLogicalWidth, dpr);
  }
}
