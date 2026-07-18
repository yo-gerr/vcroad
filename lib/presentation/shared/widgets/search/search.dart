import 'package:flutter/material.dart';
import 'package:vcroad/core/utils/debouncer/debouncer.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

/// Reusable search bar used across app (Account, Advisory, Lesson, etc.)
/// - Debounces input (default 300ms)
/// - Shows a clear button when text exists
/// - Can accept external controller or create one internally
/// - Calls [onSearch] with the latest value after debounce or immediately on clear
class Search extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final String hint;
  final Duration debounceDuration;
  final TextEditingController? controller;
  final bool autofocus;
  final VoidCallback? onClear;
  final Icon? prefixIcon;
  final Color? fillColor;
  final TextInputType keyboardType;

  const Search({
    required this.onSearch,
    this.hint = 'Search...',
    this.debounceDuration = const Duration(milliseconds: 300),
    this.controller,
    this.autofocus = false,
    this.onClear,
    this.prefixIcon,
    this.fillColor,
    this.keyboardType = TextInputType.text,
    super.key,
  });

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  late final TextEditingController _internalController;
  late final bool _ownsController;
  late final Debouncer _debouncer;

  TextEditingController get _ctrl => widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _internalController = widget.controller ?? TextEditingController();
    _debouncer = Debouncer(widget.debounceDuration);
  }

  @override
  void dispose() {
    _debouncer.dispose();
    if (_ownsController) _internalController.dispose();
    super.dispose();
  }

  void _clear() {
    _ctrl.clear();
    _debouncer.cancel();
    widget.onClear?.call();
    // Immediately notify caller that search is cleared
    widget.onSearch('');
    // keep focus for quick retype
    FocusScope.of(context).requestFocus(FocusNode());
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final fill = widget.fillColor ?? Colors.grey.shade50;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _ctrl,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;
        return TextField(
          controller: _ctrl,
          autofocus: widget.autofocus,
          keyboardType: widget.keyboardType,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon ?? const Icon(Icons.search),
            suffixIcon: hasText
                ? IconButton(icon: const Icon(Icons.clear), onPressed: _clear)
                : null,
            filled: true,
            fillColor: fill,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: info.scale(12),
              vertical: info.scale(12),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          style: TextStyle(fontSize: info.scaleFont(14)),
          onChanged: (q) {
            _debouncer.call(() {
              if (!mounted) return;
              widget.onSearch(q);
            });
          },
        );
      },
    );
  }
}
