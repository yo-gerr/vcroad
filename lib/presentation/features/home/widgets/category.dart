import 'package:flutter/material.dart';
import 'package:vcroad/core/utils/responsive/responsive.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

enum MapCategory { all, report, advisory }

class CategoryToggle extends StatelessWidget {
  final MapCategory selectedCategory;
  final ValueChanged<MapCategory> onCategoryChanged;

  const CategoryToggle({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;

    return Container(
      padding: EdgeInsets.all(info.scale(4)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(context, 'All', MapCategory.all, info),
          SizedBox(width: info.scale(4)),
          _buildToggleButton(context, 'Report', MapCategory.report, info),
          SizedBox(width: info.scale(4)),
          _buildToggleButton(context, 'Advisory', MapCategory.advisory, info),
        ],
      ),
    );
  }

  Widget _buildToggleButton(
    BuildContext context,
    String label,
    MapCategory category,
    ResponsiveInfo info,
  ) {
    final isSelected = selectedCategory == category;

    return GestureDetector(
      onTap: () => onCategoryChanged(category),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: info.scale(20),
          vertical: info.scale(10),
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1565C0) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontSize: info.scaleFont(14),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
