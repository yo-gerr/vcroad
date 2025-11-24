import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';

class RegistrationConfirmation extends StatelessWidget {
  const RegistrationConfirmation({super.key});

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.horizontalPadding,
          vertical: responsive.verticalPadding,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success image instead of check icon
              SizedBox(
                height: responsive.scale(120),
                child: Image.asset(
                  'assets/images/success.webp', // Place your image here
                  fit: BoxFit.contain,
                  semanticLabel: 'Registration successful',
                ),
              ),
              SizedBox(height: responsive.scale(12)),
              Text(
                'Registration complete',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: responsive.scaleFont(20),
                ),
              ),
              SizedBox(height: responsive.scale(8)),
              Text(
                'Your account has been created. You can now access the app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: responsive.scaleFont(14),
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
