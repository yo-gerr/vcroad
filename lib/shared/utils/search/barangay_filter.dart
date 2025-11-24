import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/models/barangay.dart';
import 'package:vcroad_v2/shared/services/barangay.dart';
import 'package:vcroad_v2/shared/utils/search/search.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';

typedef BarangayCallback = FutureOr<void> Function(Barangay? barangay);

class BarangayFilter extends StatefulWidget {
  final Barangay? selected;
  final BarangayService? barangayService;
  final BarangayCallback onChanged;
  final String selectLabel;
  final bool showClear;

  const BarangayFilter({
    super.key,
    required this.onChanged,
    this.selected,
    this.barangayService,
    this.selectLabel = 'Select Barangay',
    this.showClear = true,
  });

  @override
  State<BarangayFilter> createState() => _BarangayFilterState();
}

class _BarangayFilterState extends State<BarangayFilter> {
  late final BarangayService _service;
  List<Barangay> _barangays = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.barangayService ?? BarangayService();
    _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    try {
      await _service.loadBarangays();
      if (!mounted) return;
      setState(() {
        _barangays = _service.barangays;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _barangays = [];
        _loading = false;
      });
    }
  }

  Future<void> _openSelector() async {
    // Ensure barangays are loaded before opening the selector so the dialog
    // has data immediately (prevents "No barangays found" race).
    await _ensureLoaded();
    if (!mounted) return;
    final responsive = context.responsive;
    Barangay? result;
    List<Barangay> filtered = List.from(_barangays);

    Widget content(StateSetter setState) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Barangay',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Search(
              hint: 'Search barangay...',
              onSearch: (q) {
                setState(() {
                  filtered = _service.search(q);
                });
              },
              onClear: () {
                setState(() {
                  filtered = List<Barangay>.from(_barangays);
                });
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No barangays found'))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final b = filtered[i];
                      return ListTile(
                        title: Text(b.name.replaceAll('_', ' ')),
                        leading: const Icon(Icons.location_on),
                        selected: widget.selected?.name == b.name,
                        onTap: () => Navigator.of(context).pop(b),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear selection'),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (responsive.isMobile) {
      result = await showModalBottomSheet<Barangay?>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        builder: (_) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: StatefulBuilder(builder: (_, s) => content(s)),
          ),
        ),
      );
    } else {
      result = await showDialog<Barangay?>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
            child: StatefulBuilder(builder: (_, s) => content(s)),
          ),
        ),
      );
    }

    if (!mounted) return;
    await widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: _loading ? null : _openSelector,
          icon: Icon(Icons.location_on, size: responsive.scale(14)),
          label: Text(
            widget.selected?.name.replaceAll('_', ' ') ?? widget.selectLabel,
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.scale(12),
              vertical: responsive.scale(8),
            ),
          ),
        ),
      ],
    );
  }
}
