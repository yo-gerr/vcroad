import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vcroad_v2/shared/services/permission.dart';

class PermissionRationaleDialog extends StatelessWidget {
  final Map<AppPermission, PermissionStatus> statuses;
  final VoidCallback? onRetry;
  final VoidCallback onOpenSettings;
  final VoidCallback onCancel;

  const PermissionRationaleDialog({
    super.key,
    required this.statuses,
    this.onRetry,
    required this.onOpenSettings,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final permanentlyDenied = statuses.entries
        .where((e) => e.value.isPermanentlyDenied)
        .toList();
    final denied = statuses.entries
        .where((e) => !e.value.isGranted && !e.value.isPermanentlyDenied)
        .toList();

    return AlertDialog(
      title: const Text('Permissions Required'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (denied.isNotEmpty) ...[
              const Text(
                'Denied (can be requested again):',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ...denied.map(
                (e) => _line(e.key.label, e.key.rationale, Icons.info_outline),
              ),
              const SizedBox(height: 12),
            ],
            if (permanentlyDenied.isNotEmpty) ...[
              const Text(
                'Blocked (open settings to enable):',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ...permanentlyDenied.map(
                (e) => _line(e.key.label, e.key.rationale, Icons.lock),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'Please grant the required permissions to continue.',
              style: TextStyle(color: Colors.black87),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
        if (permanentlyDenied.isNotEmpty)
          TextButton(
            onPressed: onOpenSettings,
            child: const Text('Open Settings'),
          ),
        if (denied.isNotEmpty && onRetry != null)
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }

  Widget _line(String title, String rationale, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: rationale),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
