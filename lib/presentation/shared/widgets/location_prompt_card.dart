import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class LocationPromptCard extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onGranted;
  final VoidCallback onDismiss;

  const LocationPromptCard({
    super.key,
    required this.title,
    required this.body,
    required this.onGranted,
    required this.onDismiss,
  });

  Future<void> _requestAndNotify() async {
    final status = await Geolocator.requestPermission();
    if (status == LocationPermission.always ||
        status == LocationPermission.whileInUse) {
      onGranted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.scale;
    return Card(
      margin: EdgeInsets.all(s(16)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(s(12)),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(s(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_rounded,
                    size: s(24), color: Theme.of(context).colorScheme.primary),
                SizedBox(width: s(8)),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: s(15), fontWeight: FontWeight.w600)),
                ),
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(Icons.close,
                      size: s(18),
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            SizedBox(height: s(8)),
            Text(body,
                style: TextStyle(
                    fontSize: s(13),
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            SizedBox(height: s(16)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDismiss,
                  child: const Text('Not Now'),
                ),
                SizedBox(width: s(8)),
                ElevatedButton(
                  onPressed: _requestAndNotify,
                  child: const Text('Grant Location'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
