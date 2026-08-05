import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/core/utils/input/dropdown_style.dart';
import 'package:vcroad/core/utils/input/input_style.dart';
import 'package:vcroad/data/models/barangay.dart';
import 'package:vcroad/data/repositories/barangay.dart';

/// Reusable searchable, brand-styled Barangay dropdown with loading/error/retry,
/// normalized search, and a no-results affordance.
///
/// Loads candidates from [BarangayService] (cached names render instantly) and
/// reports load/error/retry states so the caller never shows a permanently
/// empty field.
class BarangayDropdownField extends StatefulWidget {
  final Barangay? value;
  final ValueChanged<Barangay?>? onChanged;
  final String? Function(Barangay?)? validator;
  final InputDecoration? decoration;
  final String hint;

  const BarangayDropdownField({
    super.key,
    this.value,
    this.onChanged,
    this.validator,
    this.decoration,
    this.hint = 'Select barangay',
  });

  @override
  State<BarangayDropdownField> createState() => _BarangayDropdownFieldState();
}

class _BarangayDropdownFieldState extends State<BarangayDropdownField> {
  final BarangayService _svc = BarangayService();
  final TextEditingController _searchController = TextEditingController();

  static final Barangay _sentinel = Barangay(name: '__no_results__');

  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceReload = false}) async {
    if (!_svc.namesReady) {
      setState(() => _failed = false);
    }
    try {
      await _svc.loadBarangays(forceReload: forceReload);
      if (!mounted) return;
      setState(() => _failed = false);
    } catch (_) {
      // If names came from cache but polygons failed, still show the dropdown.
      if (!mounted) return;
      if (!_svc.namesReady) setState(() => _failed = true);
    }
  }

  static String _normalized(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'^(barangay|brgy\.?)\s+'), '')
        .replaceAll('_', ' ')
        .trim();
  }

  bool _matches(Barangay b, String query) {
    final q = _normalized(query);
    if (q.isEmpty) return true;
    final name = _normalized(b.name);
    if (name.contains(q)) return true;
    final district = _normalized(b.district ?? '');
    return district.isNotEmpty && district.contains(q);
  }

  bool _showSentinel(String query) =>
      !_svc.candidates.any((b) => _matches(b, query));

  @override
  Widget build(BuildContext context) {
    if (_failed) return _buildErrorState();

    if (!_svc.namesReady) return _buildLoadingState();

    return Semantics(
      label: 'Barangay',
      container: true,
      child: DropdownButtonFormField2<Barangay>(
        value: widget.value,
        decoration:
            widget.decoration ??
            InputStyles.baseDecoration.copyWith(hintText: widget.hint),
        style: DropdownStyles.itemTextStyle,
        isExpanded: true,
        hint: Text(widget.hint, style: DropdownStyles.hintTextStyle),
        items: [
          ..._svc.candidates.map(
            (b) => DropdownMenuItem<Barangay>(
              value: b,
              child: Container(
                height: DropdownStyles.dropdownItemHeight,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                color: DropdownStyles.dropdownBackgroundColor,
                child: DefaultTextStyle(
                  style: DropdownStyles.itemTextStyle.copyWith(
                    color: DropdownStyles.dropdownItemTextColor,
                  ),
                  child: Text(
                    b.name.replaceAll('_', ' '),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
          DropdownMenuItem<Barangay>(
            value: _sentinel,
            enabled: false,
            child: Container(
              height: DropdownStyles.dropdownItemHeight,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: DropdownStyles.dropdownBackgroundColor,
              child: Text(
                'No barangay found',
                style: DropdownStyles.itemTextStyle.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
        onChanged: (b) {
          if (b == null || identical(b, _sentinel)) return;
          widget.onChanged?.call(b);
        },
        validator:
            widget.validator ??
            (b) => (b == null || b.name.trim().isEmpty)
                ? 'Barangay is required'
                : null,
        dropdownSearchData: DropdownSearchData<Barangay>(
          searchController: _searchController,
          searchInnerWidgetHeight: 50,
          searchInnerWidget: Container(
            height: 50,
            padding: const EdgeInsets.all(8),
            child: TextFormField(
              controller: _searchController,
              style: DropdownStyles.itemTextStyle.copyWith(
                color: DropdownStyles.dropdownItemTextColor,
              ),
              decoration: DropdownStyles.searchDecoration,
            ),
          ),
          searchMatchFn: (item, searchValue) {
            final b = item.value;
            if (b == null) return false;
            if (identical(b, _sentinel)) return _showSentinel(searchValue);
            return _matches(b, searchValue);
          },
        ),
        menuItemStyleData: const MenuItemStyleData(
          height: DropdownStyles.dropdownItemHeight,
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight:
              DropdownStyles.dropdownItemHeight *
              DropdownStyles.visibleItemCount,
          decoration: DropdownStyles.dropdownDecoration,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: DropdownStyles.dropdownItemHeight,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(
          DropdownStyles.dropdownBorderRadius,
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(
          DropdownStyles.dropdownBorderRadius,
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "Couldn't load barangays.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => _load(forceReload: true),
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
