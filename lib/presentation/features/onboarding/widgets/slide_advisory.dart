import 'package:flutter/material.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class SlideAdvisory extends StatefulWidget {
  const SlideAdvisory({super.key});

  @override
  State<SlideAdvisory> createState() => _SlideAdvisoryState();
}

class _SlideAdvisoryState extends State<SlideAdvisory>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide1;
  late Animation<Offset> _slide2;
  late Animation<Offset> _slide3;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _slide1 = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.3, curve: Curves.easeOutCubic)),
    );
    _slide2 = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.2, 0.5, curve: Curves.easeOutCubic)),
    );
    _slide3 = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 0.7, curve: Curves.easeOutCubic)),
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
          SlideTransition(
            position: _slide1,
            child: _card(context, Icons.warning_amber_rounded, Colors.red.shade700, 'Road Closure', 'McArthur Hwy — until 6 PM'),
          ),
          SizedBox(height: s(10)),
          SlideTransition(
            position: _slide2,
            child: _card(context, Icons.construction, Colors.orange.shade700, 'Construction', 'Fatima Ave — lane closed'),
          ),
          SizedBox(height: s(10)),
          SlideTransition(
            position: _slide3,
            child: _card(context, Icons.event, Colors.purple.shade600, 'Event', 'Plaza Rizal — road re-routing'),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, IconData icon, Color iconColor, String title, String desc) {
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
          Icon(icon, size: s(28), color: iconColor),
          SizedBox(width: s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: s(14), fontWeight: FontWeight.w600)),
                SizedBox(height: s(2)),
                Text(desc, style: TextStyle(fontSize: s(12), color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: s(20), color: Theme.of(context).colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
