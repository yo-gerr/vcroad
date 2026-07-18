import 'package:flutter/material.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/data/models/report.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class CategoryStep extends StatelessWidget {
  final ReportCategory? selectedCategory;
  final ValueChanged<ReportCategory> onCategorySelected;
  final VoidCallback onNext;

  const CategoryStep({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select a category',
          style: TextStyle(
            fontSize: info.scaleFont(18),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: info.isMobile ? 2 : 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: ReportCategory.values.length,
            itemBuilder: (context, index) {
              final category = ReportCategory.values[index];
              final isSelected = selectedCategory == category;
              return GestureDetector(
                onTap: () => onCategorySelected(category),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        category.asset,
                        width: info.scale(40),
                        height: info.scale(40),
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: info.scaleFont(13),
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: selectedCategory == null ? null : onNext,
          child: const Text('Next'),
        ),
      ],
    );
  }
}
