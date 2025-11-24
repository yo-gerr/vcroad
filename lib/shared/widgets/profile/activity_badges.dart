import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/models/user.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';

class ActivityBadges extends StatelessWidget {
  final UserDetails user;
  final bool isWide;
  const ActivityBadges({required this.user, required this.isWide, super.key});

  @override
  Widget build(BuildContext context) {
    final itemWidth = isWide ? 220.0 : context.scale(160);
    final gap = context.scale(16);
    final badgeTextStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: const Color(0xFF052676),
      fontSize: context.scaleFont(13),
    );

    Widget buildBadge({
      required String title,
      required int count,
      required String assetPath,
      required Color color,
    }) {
      return SizedBox(
        width: itemWidth,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: Color(
                0xFF052676,
              ).withAlpha((0.6 * 255).round()), // avoid deprecated withOpacity
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.scale(14),
              vertical: context.scale(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  child: Image.asset(
                    assetPath,
                    width: context.scale(54),
                    height: context.scale(54),
                    filterQuality: FilterQuality.low,
                  ),
                ),
                const SizedBox(height: 8),
                Text(title, style: badgeTextStyle, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF052676),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: context.scaleFont(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: gap,
      runSpacing: gap,
      children: [
        buildBadge(
          title: 'Confirm Reacts',
          count: user.confirmReactionsCount,
          assetPath: 'assets/images/react.webp',
          color: Colors.red,
        ),
        buildBadge(
          title: 'Verified Reports',
          count: user.verifiedReportsCount,
          assetPath: 'assets/images/report.webp',
          color: Colors.amber,
        ),
        buildBadge(
          title: 'Lessons Done',
          count: user.lessonsFinishedCount,
          assetPath: 'assets/images/learn.webp',
          color: Colors.green,
        ),
      ],
    );
  }
}
