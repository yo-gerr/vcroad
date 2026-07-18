import 'package:flutter/widgets.dart';

enum DeviceType { mobile, tablet, desktop }

class ResponsiveInfo {
  final DeviceType deviceType;
  final double screenWidth;
  final double screenHeight;
  final TextScaler textScaler;
  final EdgeInsets viewPadding;
  final EdgeInsets viewInsets;
  final Orientation orientation;

  const ResponsiveInfo({
    required this.deviceType,
    required this.screenWidth,
    required this.screenHeight,
    required this.textScaler,
    required this.viewPadding,
    required this.viewInsets,
    required this.orientation,
  });

  // Breakpoints (can be adjusted)
  static const double desktopBreakpoint = 1024;
  static const double tabletBreakpoint = 600;

  static DeviceType _getDeviceType(double width) {
    if (width >= desktopBreakpoint) return DeviceType.desktop;
    if (width >= tabletBreakpoint) return DeviceType.tablet;
    return DeviceType.mobile;
  }

  factory ResponsiveInfo.fromMediaQuery(MediaQueryData mq) {
    final w = mq.size.width;
    return ResponsiveInfo(
      deviceType: _getDeviceType(w),
      screenWidth: mq.size.width,
      screenHeight: mq.size.height,
      textScaler: mq.textScaler,
      viewPadding: mq.padding,
      viewInsets: mq.viewInsets,
      orientation: mq.orientation,
    );
  }

  bool get isMobile => deviceType == DeviceType.mobile;
  bool get isTablet => deviceType == DeviceType.tablet;
  bool get isDesktop => deviceType == DeviceType.desktop;

  double get horizontalPadding {
    switch (deviceType) {
      case DeviceType.desktop:
        return 64;
      case DeviceType.tablet:
        return 32;
      case DeviceType.mobile:
        return 16;
    }
  }

  double get verticalPadding {
    switch (deviceType) {
      case DeviceType.desktop:
        return 48;
      case DeviceType.tablet:
        return 32;
      case DeviceType.mobile:
        return 24;
    }
  }

  // Scales a base value by device type (keeps consistent UI across sizes)
  double scale(
    num baseValue, {
    double mobileFactor = 0.8,
    double tabletFactor = 0.9,
  }) {
    final base = baseValue.toDouble();
    if (isDesktop) return base;
    if (isTablet) return base * tabletFactor;
    return base * mobileFactor;
  }

  // Scale font size and respect the system textScaleFactor (but cap to avoid overflow)
  double scaleFont(num baseSize, {double cap = 1.25}) {
    final base = baseSize.toDouble();
    final deviceScaled = scale(base);
    final scaled = textScaler.scale(deviceScaled);
    final lower = (base * 0.8);
    final upper = (base * cap);
    return (scaled.clamp(lower, upper) as num).toDouble();
  }

  // Recommended logo size per device
  double get logoSize {
    switch (deviceType) {
      case DeviceType.desktop:
        return 300;
      case DeviceType.tablet:
        return ((screenWidth * 0.4).clamp(120, 400)).toDouble();
      case DeviceType.mobile:
        return ((screenWidth * 0.5).clamp(80, 220)).toDouble();
    }
  }

  // Marker size scale factor based on screen width (keeps markers visible on wide screens)
  double get markerScale {
    if (screenWidth >= 1600) return 1.5;
    if (screenWidth >= 1200) return 1.25;
    if (screenWidth >= 900) return 1.1;
    if (screenWidth >= 600) return 1.0;
    return 0.85;
  }

  // Max width for centered forms / dialogs
  double get maxFormWidth => isDesktop ? 600 : double.infinity;

  // Compute cacheWidth for asset images to reduce memory usage (use devicePixelRatio)
  int cacheWidthForImage(double desiredLogicalWidth, double devicePixelRatio) {
    return (desiredLogicalWidth * devicePixelRatio).round();
  }
}
