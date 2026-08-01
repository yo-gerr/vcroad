import 'package:flutter/material.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class SlideTrack extends StatefulWidget {
  const SlideTrack({super.key});

  @override
  State<SlideTrack> createState() => _SlideTrackState();
}

class _SlideTrackState extends State<SlideTrack>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _bar;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _bar = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.scale;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statusBadge(context),
          SizedBox(height: s(24)),
          _reportRow(context, 'Pothole on Macarthur Hwy', _bar.value.clamp(0, 0.4) / 0.4, Icons.construction, Colors.orange),
          SizedBox(height: s(12)),
          _reportRow(context, 'Broken street light', _bar.value.clamp(0.2, 0.7) / 0.5, Icons.lightbulb, Colors.blue),
          SizedBox(height: s(12)),
          _reportRow(context, 'Flooded underpass', _bar.value.clamp(0.5, 1) / 0.5, Icons.water_drop, Colors.green),
        ],
      ),
    );
  }

  Widget _statusBadge(BuildContext context) {
    final s = context.scale;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: s(14), vertical: s(6)),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(s(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.checklist, size: s(18), color: Theme.of(context).colorScheme.primary),
          SizedBox(width: s(8)),
          Text('3 Active Reports', style: TextStyle(fontWeight: FontWeight.w600, fontSize: s(13), color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }

  Widget _reportRow(BuildContext context, String label, double value, IconData icon, Color color) {
    final s = context.scale;
    return Container(
      width: s(260),
      padding: EdgeInsets.all(s(12)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(s(10)),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: s(22), color: color),
          SizedBox(width: s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: s(12), fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: s(6)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
