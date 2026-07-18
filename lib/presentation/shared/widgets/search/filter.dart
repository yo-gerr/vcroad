import 'package:flutter/material.dart';

class FilterChipButton extends StatelessWidget {
  final dynamic responsive;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;
  final Color? color;
  final String? tooltip;

  const FilterChipButton({
    super.key,
    required this.responsive,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    s(double v) => (responsive?.scale ?? (double x) => x)(v);
    sf(double v) => (responsive?.scaleFont ?? (double x) => x)(v);

    final Color base = color ?? Colors.grey;
    final double iconSize = s(18); // slightly larger icon
    final EdgeInsets padding = EdgeInsets.symmetric(
      horizontal: s(16),
      vertical: s(10),
    );

    final Widget child = OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize, color: selected ? base : base),
      label: Text(
        label,
        style: TextStyle(color: selected ? base : null, fontSize: sf(13)),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? base.withValues(alpha: 0.12)
            : Colors.transparent,
        side: BorderSide(
          color: selected ? base : Colors.grey.shade300,
          width: selected ? 1.6 : 1.0,
        ),
        padding: padding,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        // increased minimumSize for better tap target and visual presence
        minimumSize: Size(s(88), s(44)),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}
