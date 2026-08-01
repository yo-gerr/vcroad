import 'package:flutter/material.dart';
import 'package:vcroad/core/constants/xp_constants.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class XpPreview extends StatefulWidget {
  const XpPreview({super.key});

  @override
  State<XpPreview> createState() => _XpPreviewState();
}

class _XpPreviewState extends State<XpPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _xpFill;
  late Animation<int> _xpCount;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _xpFill = Tween<double>(begin: 0, end: 0.67).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _xpCount = IntTween(begin: 0, end: 100).animate(_ctrl);
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
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final levelTitle = XpConstants.getLevelTitle(_xpCount.value);
        return Container(
          width: s(260),
          padding: EdgeInsets.all(s(20)),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(s(16)),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber.shade600, size: s(36)),
              SizedBox(height: s(12)),
              Text('${_xpCount.value} XP', style: TextStyle(fontSize: s(26), fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
              SizedBox(height: s(4)),
              Text(levelTitle, style: TextStyle(fontSize: s(15), color: Colors.amber.shade700, fontWeight: FontWeight.w600)),
              SizedBox(height: s(12)),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _xpFill.value,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                  minHeight: 10,
                ),
              ),
              SizedBox(height: s(4)),
              Text('Complete lessons & reports to earn more XP!', style: TextStyle(fontSize: s(12), color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        );
      },
    );
  }
}
