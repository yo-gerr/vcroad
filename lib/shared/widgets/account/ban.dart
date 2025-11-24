import 'package:flutter/material.dart';

class BanAction {
  final bool confirm;
  final bool isPermanent;
  final int? days; // null for permanent
  final String reason;

  BanAction({
    required this.confirm,
    required this.isPermanent,
    required this.days,
    required this.reason,
  });
}

enum BanDurationOption { oneWeek, oneMonth, threeMonths, permanent, custom }

/// Shows a dialog where admin selects ban duration and enters a reason.
/// Returns a [BanAction] if confirmed, or null if cancelled.
Future<BanAction?> showBanDialog(
  BuildContext context, {
  String? initialReason,
}) {
  return showDialog<BanAction>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      BanDurationOption selected = BanDurationOption.oneWeek;
      final reasonCtrl = TextEditingController(text: initialReason ?? '');
      final customDaysCtrl = TextEditingController();
      String? reasonError;
      String? daysError;

      String? selectedDays() {
        switch (selected) {
          case BanDurationOption.oneWeek:
            return '7';
          case BanDurationOption.oneMonth:
            return '30';
          case BanDurationOption.threeMonths:
            return '90';
          case BanDurationOption.custom:
            return customDaysCtrl.text.trim();
          case BanDurationOption.permanent:
            return null;
        }
      }

      return StatefulBuilder(
        builder: (context, setState) {
          void validate() {
            setState(() {
              reasonError = (reasonCtrl.text.trim().isEmpty)
                  ? 'Please enter a reason'
                  : null;
              if (selected == BanDurationOption.custom) {
                final v = int.tryParse(customDaysCtrl.text.trim());
                daysError = (v == null || v <= 0) ? 'Enter days > 0' : null;
              } else {
                daysError = null;
              }
            });
          }

          final canConfirm =
              (reasonCtrl.text.trim().isNotEmpty) &&
              (selected != BanDurationOption.custom ||
                  (int.tryParse(customDaysCtrl.text.trim()) != null &&
                      int.parse(customDaysCtrl.text.trim()) > 0));

          Widget durationChips() {
            Widget chip(String label, BanDurationOption value) {
              final bool active = selected == value;
              return ChoiceChip(
                label: Text(label),
                selected: active,
                onSelected: (_) => setState(() {
                  selected = value;
                  validate();
                }),
                selectedColor: Theme.of(context).colorScheme.primary,
                backgroundColor: Colors.grey.shade100,
                labelStyle: TextStyle(
                  color: active ? Colors.white : Colors.black87,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              );
            }

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                chip('1 week', BanDurationOption.oneWeek),
                chip('1 month', BanDurationOption.oneMonth),
                chip('3 months', BanDurationOption.threeMonths),
                chip('Permanent', BanDurationOption.permanent),
                chip('Custom', BanDurationOption.custom),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Ban user'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select duration',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  durationChips(),
                  if (selected == BanDurationOption.custom) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 160,
                        child: TextField(
                          controller: customDaysCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Days (e.g. 14)',
                            errorText: daysError,
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (_) => validate(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Reason',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter ban reason (required)',
                      errorText: reasonError,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) => validate(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop(null);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: canConfirm
                    ? () {
                        validate();
                        if (reasonError != null || daysError != null) return;
                        final daysStr = selectedDays();
                        final days = daysStr == null
                            ? null
                            : int.tryParse(daysStr);
                        Navigator.of(ctx).pop(
                          BanAction(
                            confirm: true,
                            isPermanent:
                                selected == BanDurationOption.permanent,
                            days: days,
                            reason: reasonCtrl.text.trim(),
                          ),
                        );
                      }
                    : null,
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );
    },
  );
}
