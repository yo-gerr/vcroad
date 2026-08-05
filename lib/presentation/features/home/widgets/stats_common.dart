import 'package:flutter/material.dart';
import 'package:vcroad/core/utils/debouncer/debouncer.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/presentation/shared/dialogs/confirmation.dart';
import 'package:vcroad/presentation/shared/dialogs/loading.dart';

/// Semantic accent colors shared by the per-barangay stats dashboards.
/// Mid-tone colors that stay legible on both light and dark surfaces.
const kVerifiedColor = Color(0xFF64B5F6);
const kUnverifiedColor = Color(0xFFE57373);
const kResolvedColor = Color(0xFF2E7D32);
const kFlaggedColor = Color(0xFFFFA726);
const kPendingColor = Color(0xFF9E9E9E);

/// Theme-aware search field with a debounced [onChanged] callback and a
/// clear button. Shared by the user and report per-barangay dashboards.
class StatsSearchField extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onChanged;

  const StatsSearchField({
    super.key,
    this.hintText = 'Search barangay',
    required this.onChanged,
  });

  @override
  State<StatsSearchField> createState() => _StatsSearchFieldState();
}

class _StatsSearchFieldState extends State<StatsSearchField> {
  final Debouncer _debouncer = Debouncer(const Duration(milliseconds: 250));
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText && mounted) {
      setState(() => _hasText = hasText);
    }
  }

  void _clear() {
    _controller.clear();
    _debouncer.call(() {
      if (mounted) widget.onChanged('');
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
        hintText: widget.hintText,
        isDense: true,
        filled: true,
        fillColor: colorScheme.surface,
        suffixIcon: _hasText
            ? IconButton(
                tooltip: 'Clear search',
                icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                onPressed: _clear,
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (q) {
        _debouncer.call(() {
          if (mounted) widget.onChanged(q);
        });
      },
    );
  }
}

/// Legend row of colored dots, shared by the per-barangay dashboards.
class StatsLegend extends StatelessWidget {
  final List<(String, Color)> items;

  const StatsLegend({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: info.scale(12)),
          Row(
            children: [
              Container(
                width: info.scale(12),
                height: info.scale(12),
                decoration: BoxDecoration(
                  color: items[i].$2,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: info.scale(6)),
              Text(items[i].$1, style: TextStyle(fontSize: info.scaleFont(12))),
            ],
          ),
        ],
        const Spacer(),
      ],
    );
  }
}

/// Shared confirmation gate for stats exports.
Future<bool> confirmStatsExport({
  required BuildContext context,
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => ConfirmationDialog(
      title: title,
      message: message,
      confirmText: 'Export',
      cancelText: 'Cancel',
    ),
  );
  return confirmed == true;
}

/// Shared non-dismissible loading overlay for exports.
void showExportLoading(BuildContext context, String message) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => LoadingDialog(message: message),
  );
}
