import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/utils/format/date_time.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';

class UserStats extends StatelessWidget {
  final String title;
  final int totalCount;
  final int verifiedCount;
  final int unverifiedCount;
  final VoidCallback? onBarangayTap;
  final Future<void> Function()? onExportBarangay;
  final DateTime timestamp;

  const UserStats({
    super.key,
    required this.title,
    required this.totalCount,
    required this.verifiedCount,
    required this.unverifiedCount,
    this.onBarangayTap,
    this.onExportBarangay,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final double ratio = totalCount > 0 ? verifiedCount / totalCount : 0.0;

    return Container(
      padding: EdgeInsets.all(info.scale(20)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: info.scaleFont(20),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: info.scale(16)),

          // Legend
          Row(
            children: [
              _buildLegendItem('Verified', const Color(0xFF64B5F6), info),
              SizedBox(width: info.scale(16)),
              _buildLegendItem('Unverified', const Color(0xFFE57373), info),
            ],
          ),
          SizedBox(height: info.scale(24)),

          // Count and Donut Chart
          Row(
            children: [
              // Total Count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: info.scaleFont(48),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: info.scale(12)),
                    if (onBarangayTap != null)
                      OutlinedButton(
                        onPressed: onBarangayTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Per Barangay',
                          style: TextStyle(fontSize: info.scaleFont(14)),
                        ),
                      )
                    else if (onExportBarangay != null)
                      OutlinedButton.icon(
                        onPressed: () => onExportBarangay!(),
                        icon: Icon(
                          Icons.download_outlined,
                          color: Colors.white,
                          size: info.scale(16),
                        ),
                        label: Text(
                          'Export',
                          style: TextStyle(
                            fontSize: info.scaleFont(14),
                            color: Colors.white,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Donut Chart (animated)
              SizedBox(
                width: info.scale(120),
                height: info.scale(120),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: info.scale(120),
                      height: info.scale(120),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: ratio),
                        duration: const Duration(milliseconds: 600),
                        builder: (context, animatedValue, child) {
                          return CircularProgressIndicator(
                            value: animatedValue,
                            strokeWidth: info.scale(12),
                            backgroundColor: const Color(0xFFE57373),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF64B5F6),
                            ),
                          );
                        },
                      ),
                    ),
                    // Animated verified count for smooth update
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Column(
                        key: ValueKey<int>(verifiedCount),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$verifiedCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: info.scaleFont(24),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: info.scale(4)),
                          Text(
                            'Verified',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: info.scaleFont(12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: info.scale(16)),

          // Timestamp
          Text(
            'as of ${DateFormatUtils.formatFriendly(timestamp)}',
            style: TextStyle(
              color: Colors.white70,
              fontSize: info.scaleFont(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, ResponsiveInfo info) {
    return Row(
      children: [
        Container(
          width: info.scale(12),
          height: info.scale(12),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: info.scale(6)),
        Text(
          label,
          style: TextStyle(color: Colors.white, fontSize: info.scaleFont(12)),
        ),
      ],
    );
  }
}
