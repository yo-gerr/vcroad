import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive.dart';

class ResponsiveScope extends InheritedWidget {
  final ResponsiveInfo info;

  const ResponsiveScope({required this.info, required super.child, super.key});

  @override
  bool updateShouldNotify(covariant ResponsiveScope oldWidget) {
    // Only notify when relevant metrics change
    return oldWidget.info.screenWidth != info.screenWidth ||
        oldWidget.info.screenHeight != info.screenHeight ||
        oldWidget.info.orientation != info.orientation ||
        // Compare a numeric scale value from TextScaler (avoid comparing function objects)
        oldWidget.info.textScaler.scale(14.0) != info.textScaler.scale(14.0) ||
        oldWidget.info.viewPadding != info.viewPadding ||
        oldWidget.info.viewInsets != info.viewInsets;
  }

  static ResponsiveInfo of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ResponsiveScope>();
    if (scope != null) return scope.info;
    // Fallback to MediaQuery if widget not provided
    return ResponsiveInfo.fromMediaQuery(MediaQuery.of(context));
  }
}

// A small wrapper to compute ResponsiveInfo once using LayoutBuilder + MediaQuery
// Use high in the widget tree (e.g., above pages) to provide responsive values for children.
class ResponsiveBuilder extends StatelessWidget {
  final Widget child;

  const ResponsiveBuilder({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final info = ResponsiveInfo.fromMediaQuery(mq);
    return ResponsiveScope(info: info, child: child);
  }
}
