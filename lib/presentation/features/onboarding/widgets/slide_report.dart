import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class SlideReport extends StatefulWidget {
  const SlideReport({super.key});

  @override
  State<SlideReport> createState() => _SlideReportState();
}

class _SlideReportState extends State<SlideReport>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pinDrop;
  late Animation<double> _cardSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pinDrop = Tween<double>(begin: -1, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.4, curve: Curves.bounceOut)),
    );
    _cardSlide = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic)),
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
          SizedBox(
            height: s(160),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: s(140),
                  height: s(140),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(s(20)),
                  ),
                  child: CustomPaint(
                    painter: _SimpleMapPainter(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, _pinDrop.value * s(60)),
                  child: Icon(Icons.location_on, color: Colors.red, size: s(44)),
                ),
              ],
            ),
          ),
          SizedBox(height: s(16)),
          Transform.translate(
            offset: Offset(0, _cardSlide.value * s(40)),
            child: Container(
              width: s(220),
              padding: EdgeInsets.all(s(12)),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(s(10)),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: s(36), height: s(36),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(s(8)),
                    ),
                    child: Icon(Icons.construction, color: Colors.orange.shade700, size: s(20)),
                  ),
                  SizedBox(width: s(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(height: 8, width: s(80), decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4))),
                        SizedBox(height: s(4)),
                        Container(height: 6, width: s(120), decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleMapPainter extends CustomPainter {
  final Color color;
  _SimpleMapPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    final w = size.width;
    final h = size.height;
    final rng = Random(42);
    final points = List.generate(6, (_) => Offset(rng.nextDouble() * w, rng.nextDouble() * h));
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
