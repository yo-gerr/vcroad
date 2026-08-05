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
    // In dark mode the passed accent colors can be too dim to read on a dark
    // surface, so brighten them toward white to keep ~3:1 contrast.
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = isDark ? Color.lerp(base, Colors.white, 0.35)! : base;
    final double iconSize = s(18); // slightly larger icon
    final EdgeInsets padding = EdgeInsets.symmetric(
      horizontal: s(16),
      vertical: s(10),
    );

    final Widget chip = Semantics(
      selected: selected,
      button: true,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize, color: accent),
        label: Text(
          label,
          style: TextStyle(color: selected ? accent : null, fontSize: sf(13)),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected
              ? accent.withValues(alpha: 0.15)
              : Colors.transparent,
          side: BorderSide(
            color: selected
                ? accent
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 1.6 : 1.0,
          ),
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          // increased minimumSize for better tap target and visual presence
          minimumSize: Size(s(88), s(44)),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: chip);
    }
    return chip;
  }
}
