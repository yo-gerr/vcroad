import 'package:flutter/material.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class SlideLearn extends StatefulWidget {
  final bool isAdmin;
  const SlideLearn({super.key, this.isAdmin = false});

  @override
  State<SlideLearn> createState() => _SlideLearnState();
}

class _SlideLearnState extends State<SlideLearn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _xpFill;
  late Animation<double> _badgeScale;
  late Animation<Offset> _lessonSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _xpFill = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.5, curve: Curves.easeOutCubic)),
    );
    _badgeScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 0.7, curve: Curves.elasticOut)),
    );
    _lessonSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 0.9, curve: Curves.easeOutCubic)),
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
    if (widget.isAdmin) {
      return _adminPanel(context);
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _xpBar(context),
          SizedBox(height: s(20)),
          Transform.scale(
            scale: _badgeScale.value,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: s(14), vertical: s(8)),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(s(20)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events, size: s(20), color: Colors.amber.shade700),
                  SizedBox(width: s(6)),
                  Text('Road Observer', style: TextStyle(fontSize: s(14), fontWeight: FontWeight.w600, color: Colors.amber.shade800)),
                ],
              ),
            ),
          ),
          SizedBox(height: s(20)),
          SlideTransition(
            position: _lessonSlide,
            child: _lessonCard(context, 'Road Signs 101', 0.66, false),
          ),
          SizedBox(height: s(8)),
          SlideTransition(
            position: _lessonSlide,
            child: _lessonCard(context, 'Intersection Rules', 0.33, true),
          ),
        ],
      ),
    );
  }

  Widget _xpBar(BuildContext context) {
    final s = context.scale;
    return Container(
      width: s(240),
      padding: EdgeInsets.all(s(12)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(s(12)),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('XP', style: TextStyle(fontWeight: FontWeight.w600, fontSize: s(13), color: Theme.of(context).colorScheme.primary)),
              Text('${(150 * _xpFill.value).toInt()}/150', style: TextStyle(fontSize: s(12), color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          SizedBox(height: s(6)),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _xpFill.value,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lessonCard(BuildContext context, String title, double progress, bool locked) {
    final s = context.scale;
    return Container(
      width: s(240),
      padding: EdgeInsets.all(s(12)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(s(10)),
        border: Border.all(color: locked ? Theme.of(context).colorScheme.outlineVariant : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(locked ? Icons.lock : Icons.play_circle_filled, size: s(24),
            color: locked ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.primary),
          SizedBox(width: s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: s(13), fontWeight: FontWeight.w500)),
                SizedBox(height: s(4)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminPanel(BuildContext context) {
    final s = context.scale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: s(240),
          padding: EdgeInsets.all(s(12)),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(s(10)),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.bar_chart, size: s(28), color: Theme.of(context).colorScheme.primary),
              SizedBox(width: s(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Reports Overview', style: TextStyle(fontSize: s(14), fontWeight: FontWeight.w600)),
                    SizedBox(height: s(4)),
                    Text('12 pending · 8 resolved this week', style: TextStyle(fontSize: s(12), color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: s(12)),
        Container(
          width: s(240),
          padding: EdgeInsets.all(s(12)),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(s(10)),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.people, size: s(28), color: Theme.of(context).colorScheme.primary),
              SizedBox(width: s(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Barangay Dashboard', style: TextStyle(fontSize: s(14), fontWeight: FontWeight.w600)),
                    SizedBox(height: s(4)),
                    Text('Assign & track field workers', style: TextStyle(fontSize: s(12), color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
