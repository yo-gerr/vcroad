import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/widgets/register/agreement.dart';
import 'package:vcroad_v2/shared/widgets/login/faq.dart';
import 'package:vcroad_v2/shared/widgets/login/support.dart';

/// Footer used on the login page.
/// Layout:
///  - Centered: "© 2025 VCRoad"
///  - Below: FAQ | End-User License Agreement | Supports
///
/// Buttons currently navigate to placeholder pages (SizedBox.shrink) — replace with real pages later.
class Footer extends StatelessWidget {
  final EdgeInsetsGeometry? padding;
  final Color? textColor;
  final double spacing;

  const Footer({super.key, this.padding, this.textColor, this.spacing = 12.0});

  void _openPlaceholder(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()));
  }

  Widget _actionButton(BuildContext context, String label) {
    final color = textColor ?? Colors.white;

    return TextButton(
      onPressed: () {
        if (label == 'FAQ') {
          Navigator.of(context).push(FAQ.route());
          return;
        }
        if (label == 'End-User License Agreement') {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const UserAgreement(showConfirmButton: false),
            ),
          );
          return;
        }
        if (label == 'Supports' || label == 'Support') {
          Navigator.of(context).push(SupportScreen.route());
          return;
        }
        // other actions remain placeholders for now
        _openPlaceholder(context);
      },
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(80, 40),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          decoration: TextDecoration.underline,
          decorationThickness: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? Colors.white;

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '© 2025 VCRoad',
            style: TextStyle(color: color, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Wrap so buttons flow on narrow screens
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: spacing,
            runSpacing: 8,
            children: [
              _actionButton(context, 'FAQ'),
              _actionButton(context, 'Support'),
              _actionButton(context, 'End-User License Agreement'),
            ],
          ),
        ],
      ),
    );
  }
}
