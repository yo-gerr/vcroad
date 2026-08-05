import 'package:flutter/material.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/data/models/advisory.dart';
import 'package:vcroad/presentation/features/advisories/widgets/create_advisory.dart';

class CategoryPage extends StatelessWidget {
  final AdvisoryFormData formData;
  final dynamic responsive;

  const CategoryPage({
    super.key,
    required this.formData,
    required this.responsive,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: formData,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(responsive.scale(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Select Advisory Type',
                style: TextStyle(
                  fontSize: responsive.scaleFont(22),
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryAdaptive(context),
                ),
              ),
              SizedBox(height: responsive.scale(8)),
              Text(
                'Choose the type of traffic advisory you want to create',
                style: TextStyle(
                  fontSize: responsive.scaleFont(13),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: responsive.scale(20)),

              // Category Cards Grid
              _buildCategoryGrid(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryGrid(BuildContext context) {
    final isDesktop = responsive.isDesktop;
    final isTablet = responsive.isTablet;

    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    // provide slightly more vertical space so large icons fit comfortably
    final childAspectRatio = isDesktop ? 1.2 : (isTablet ? 1.1 : 1.02);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: responsive.scale(12),
        mainAxisSpacing: responsive.scale(12),
        childAspectRatio: childAspectRatio,
      ),
      itemCount: advisoryCategories.length,
      itemBuilder: (context, index) {
        final category = advisoryCategories[index];
        final isSelected = formData.selectedCategory?.id == category.id;

        return _CategoryCard(
          category: category,
          isSelected: isSelected,
          onTap: () {
            formData.selectedCategory = category;
            formData.markChanged();
          },
          responsive: responsive,
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final AdvisoryCategory category;
  final bool isSelected;
  final VoidCallback onTap;
  final dynamic responsive;

  const _CategoryCard({
    required this.category,
    required this.isSelected,
    required this.onTap,
    required this.responsive,
  });

  @override
  Widget build(BuildContext context) {
    final double cardPadding = responsive.scale(6);
    final double iconContainerSize = responsive.isDesktop
        ? responsive.scale(160)
        : (responsive.isTablet ? responsive.scale(140) : responsive.scale(120));
    final double iconSize = (iconContainerSize * 0.75).clamp(56.0, 120.0);

    return RepaintBoundary(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '${category.title} advisory',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    curve: Curves.easeInOut,
    padding: EdgeInsets.all(cardPadding),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outlineVariant,
        width: isSelected ? 1.8 : 1.0,
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: iconContainerSize,
          width: iconContainerSize,
          child: Center(
            child: Tooltip(
              message: category.title,
              child: category.iconPath.isNotEmpty
                  ? Image.asset(
                      category.iconPath,
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                    )
                  : Icon(
                      AdvisoryCategory.iconFor(category.id),
                      size: iconSize,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
            ),
          ),
        ),
        SizedBox(height: responsive.scale(8)),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: responsive.scale(6),
          ),
          child: Text(
            category.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: responsive.scaleFont(16),
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
                // Removed the check icon - highlight border is used to indicate selection
              ],
            ),
          ),
        ),
      ),
    );
  }
}
