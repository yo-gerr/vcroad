import 'package:vcroad_v2/shared/utils/search/search.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad_v2/shared/providers/lesson.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';

class LessonFilterBar extends StatefulWidget {
  const LessonFilterBar({super.key});

  @override
  State<LessonFilterBar> createState() => _LessonFilterBarState();
}

class _LessonFilterBarState extends State<LessonFilterBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<LessonProvider>();
    _searchController.text = provider.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchController.clear();
    context.read<LessonProvider>().clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final provider = context.watch<LessonProvider>();

    final hasActiveFilters =
        provider.searchQuery.isNotEmpty ||
        provider.selectedCategory != null ||
        provider.showPublishedOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search and Category Row
        if (info.isDesktop)
          Row(
            children: [
              Expanded(flex: 2, child: _buildSearchField(info)),
              SizedBox(width: info.scale(12)),
              Expanded(child: _buildCategoryDropdown(info, provider)),
              SizedBox(width: info.scale(12)),
              _buildPublishedFilter(info, provider),
              if (hasActiveFilters) ...[
                SizedBox(width: info.scale(12)),
                _buildClearButton(info),
              ],
            ],
          )
        else
          Column(
            children: [
              _buildSearchField(info),
              SizedBox(height: info.scale(12)),
              Row(
                children: [
                  Expanded(child: _buildCategoryDropdown(info, provider)),
                  SizedBox(width: info.scale(12)),
                  _buildPublishedFilter(info, provider),
                ],
              ),
              if (hasActiveFilters) ...[
                SizedBox(height: info.scale(12)),
                _buildClearButton(info),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildSearchField(ResponsiveInfo info) {
    return Search(
      controller: _searchController,
      hint: 'Search lessons...',
      debounceDuration: const Duration(milliseconds: 300),
      onSearch: (q) {
        // update provider search query (debounced inside AppSearchBar)
        context.read<LessonProvider>().setSearchQuery(q);
      },
      onClear: _clearFilters,
      fillColor: Colors.grey[100],
      prefixIcon: const Icon(Icons.search, color: Colors.grey),
    );
  }

  Widget _buildCategoryDropdown(ResponsiveInfo info, LessonProvider provider) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: info.scale(12)),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: provider.selectedCategory,
          hint: Text(
            'All Categories',
            style: TextStyle(fontSize: info.scaleFont(14)),
          ),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'All Categories',
                style: TextStyle(fontSize: info.scaleFont(14)),
              ),
            ),
            ...provider.categories.map((category) {
              return DropdownMenuItem<String?>(
                value: category,
                child: Text(
                  category,
                  style: TextStyle(fontSize: info.scaleFont(14)),
                ),
              );
            }),
          ],
          onChanged: (value) {
            provider.setSelectedCategory(value);
          },
        ),
      ),
    );
  }

  Widget _buildPublishedFilter(ResponsiveInfo info, LessonProvider provider) {
    return Semantics(
      button: true,
      label: 'Toggle published filter',
      child: FilterChip(
        label: Text(
          'Published',
          style: TextStyle(fontSize: info.scaleFont(12)),
        ),
        selected: provider.showPublishedOnly,
        onSelected: (_) => provider.togglePublishedOnly(),
        selectedColor: const Color(0xFF001278).withValues(alpha: 0.2),
        checkmarkColor: const Color(0xFF001278),
        side: BorderSide(
          color: provider.showPublishedOnly
              ? const Color(0xFF001278)
              : Colors.grey[300]!,
        ),
      ),
    );
  }

  Widget _buildClearButton(ResponsiveInfo info) {
    return Semantics(
      button: true,
      label: 'Clear all filters',
      child: TextButton.icon(
        onPressed: _clearFilters,
        icon: Icon(Icons.clear_all, size: info.scale(18)),
        label: Text(
          'Clear Filters',
          style: TextStyle(fontSize: info.scaleFont(12)),
        ),
        style: TextButton.styleFrom(foregroundColor: Colors.red),
      ),
    );
  }
}
