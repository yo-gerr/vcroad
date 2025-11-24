import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/widgets/home/category.dart';
import 'package:vcroad_v2/shared/services/place.dart';
import 'package:vcroad_v2/shared/utils/debouncer/debouncer.dart';

/// Reusable map search bar with autocomplete overlay and category toggle.
///
/// Place this widget anywhere. For map-overlay behavior, put it inside a Stack
/// and position it as needed (e.g. Positioned(top:16, left:16, right:16, child: MapSearchBar(...))).
class MapSearch extends StatefulWidget {
  final MapCategory? selectedCategory; // now optional
  // made optional to allow embedding the search bar without category toggle callbacks
  final ValueChanged<MapCategory>? onCategoryChanged;
  final Function(PlaceSuggestion) onSuggestionSelected;
  // vertical spacing before the search bar (useful when overlaying on map)
  final double topSpacing;
  // horizontal padding from screen edges (left/right)
  final double horizontalPadding;
  final String hintText;
  final double elevation;
  final double borderRadius;
  final bool showCategoryToggle;
  final int maxSuggestions;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  const MapSearch({
    super.key,
    this.selectedCategory,
    this.onCategoryChanged,
    required this.onSuggestionSelected,
    this.topSpacing = 16.0,
    this.horizontalPadding = 16.0,
    this.hintText = 'Search places',
    this.elevation = 12,
    this.borderRadius = 12,
    this.showCategoryToggle = true,
    this.maxSuggestions = 10,
    this.controller,
    this.focusNode,
  });

  @override
  State<MapSearch> createState() => _MapSearchState();
}

class _MapSearchState extends State<MapSearch> {
  late final TextEditingController _searchCtrl;
  late final FocusNode _searchFocus;
  final Debouncer _searchDebouncer = Debouncer();
  String? _placesSessionToken;
  List<PlaceSuggestion> _suggestions = const [];
  OverlayEntry? _autocompleteOverlay;
  final GlobalKey _searchKey = GlobalKey();
  List<PlaceSuggestion> _prevSuggestions = const [];
  bool _isTapInProgress = false; // <-- Add this flag

  @override
  void initState() {
    super.initState();
    _searchCtrl = widget.controller ?? TextEditingController();
    _searchFocus = widget.focusNode ?? FocusNode();
    _searchFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _removeAutocompleteOverlay();
    _searchDebouncer.dispose();
    if (widget.controller == null) _searchCtrl.dispose();
    if (widget.focusNode == null) _searchFocus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_searchFocus.hasFocus) {
      // Don't remove overlay if a tap is in progress
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!_searchFocus.hasFocus && mounted && !_isTapInProgress) {
          _removeAutocompleteOverlay();
        }
      });
    } else {
      _updateAutocompleteOverlay();
    }
  }

  void _onSearchChanged(String q) {
    _searchDebouncer.runOnce(() async {
      if (!mounted) return;
      if (q.trim().isEmpty) {
        setState(() => _suggestions = const []);
        _updateAutocompleteOverlay();
        return;
      }
      _placesSessionToken ??= DateTime.now().microsecondsSinceEpoch.toString();
      final results = await PlaceService.instance.autocomplete(
        q,
        sessionToken: _placesSessionToken,
      );
      if (!mounted) return;
      setState(
        () => _suggestions = results.take(widget.maxSuggestions).toList(),
      );
      _updateAutocompleteOverlay();
    });
  }

  void _removeAutocompleteOverlay() {
    _prevSuggestions = const [];
    _autocompleteOverlay?.remove();
    _autocompleteOverlay = null;
  }

  void _updateAutocompleteOverlay() {
    if (!mounted || _suggestions.isEmpty || !_searchFocus.hasFocus) {
      _removeAutocompleteOverlay();
      return;
    }
    // Only rebuild overlay if suggestions actually changed
    if (_autocompleteOverlay != null &&
        listEquals(_prevSuggestions, _suggestions)) {
      return;
    }
    _prevSuggestions = List<PlaceSuggestion>.from(_suggestions);
    _autocompleteOverlay?.remove();
    _autocompleteOverlay = _createAutocompleteOverlay();
    // Use rootOverlay: false to keep overlay within current Navigator context
    Overlay.of(context, rootOverlay: false).insert(_autocompleteOverlay!);
  }

  OverlayEntry _createAutocompleteOverlay() {
    final renderBox =
        _searchKey.currentContext?.findRenderObject() as RenderBox?;
    final fallbackHorizontal =
        (MediaQuery.of(context).size.width - (widget.horizontalPadding * 2))
            .clamp(120.0, MediaQuery.of(context).size.width);
    final size = renderBox?.size ?? Size(fallbackHorizontal, 48);
    final offset =
        renderBox?.localToGlobal(Offset.zero) ??
        Offset(widget.horizontalPadding, 100);

    return OverlayEntry(
      builder: (context) {
        return Positioned(
          left: offset.dx,
          top: offset.dy + size.height + 8,
          width: size.width,
          child: Material(
            elevation: widget.elevation,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final s = _suggestions[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.place, color: Colors.grey.shade700),
                    title: Text(
                      s.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    onTap: () async {
                      _isTapInProgress = true; // <-- Set flag before processing
                      _removeAutocompleteOverlay();
                      widget.onSuggestionSelected(s);
                      if (mounted) {
                        setState(() => _suggestions = const []);
                      }
                      _searchFocus.unfocus();
                      // Reset flag after a short delay
                      await Future.delayed(const Duration(milliseconds: 100));
                      _isTapInProgress = false;
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // external top spacing so parent doesn't need to wrap/position
        SizedBox(height: widget.topSpacing),
        // Horizontal padding so the search bar has space from left/right edges
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
          child:
              // Search box
              Container(
                key: _searchKey,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          border: InputBorder.none,
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.zero,
                          hintStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                        ),
                        style: const TextStyle(fontSize: 14),
                        onChanged: _onSearchChanged,
                        onSubmitted: (txt) {
                          if (_suggestions.isNotEmpty) {
                            _removeAutocompleteOverlay();
                            widget.onSuggestionSelected(_suggestions.first);
                          }
                        },
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _suggestions = const []);
                          _removeAutocompleteOverlay();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
        ),

        const SizedBox(height: 8),

        // Optional category toggle aligned to right.
        // Only show when caller enabled the toggle AND provided a handler.
        // show toggle only when handler provided; use fallback category when not specified
        if (widget.showCategoryToggle && widget.onCategoryChanged != null)
          Align(
            alignment: Alignment.centerRight,
            child: CategoryToggle(
              selectedCategory: widget.selectedCategory ?? MapCategory.all,
              onCategoryChanged: widget.onCategoryChanged!,
            ),
          ),
      ],
    );
  }
}
