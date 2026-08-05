import 'package:flutter/material.dart';
import 'package:vcroad/data/models/advisory.dart';
import 'package:vcroad/presentation/features/advisories/widgets/advisory_card.dart';

/// Handles the full advisory list body: loading, error + retry, contextual
/// empty states (with an admin Create CTA), the lazy desktop 2-column masonry
/// grid, and the mobile list. Supports pull-to-refresh on all states.
///
/// Pure presentation — all navigation/actions flow through callbacks, keeping
/// the screen state (and this widget) easy to unit test.
class AdvisoryListView extends StatelessWidget {
  final dynamic responsive;
  final bool isLoading;
  final String? error;
  final List<Advisory> advisories;
  final bool canEdit;
  final bool showCreateCta;
  final VoidCallback? onRetry;
  final VoidCallback? onCreate;
  final ValueChanged<Advisory> onShowDetails;
  final ValueChanged<Advisory> onDelete;
  final ValueChanged<Advisory> onDownload;
  final ValueChanged<Advisory> onEdit;
  final ValueChanged<Advisory> onToggleStatus;

  /// Manual reload (pull-to-refresh / desktop refresh). Completes when the
  /// stream's first snapshot arrives so the spinner behaves correctly.
  final Future<void> Function()? onRefresh;

  /// Whether any advisories exist at all (outside the current filters). Used to
  /// distinguish "no data yet" from "no results for your filters".
  final bool hasAnyData;

  /// Whether search / barangay / status filters are active.
  final bool hasActiveFilters;

  /// Current search query text (for the "no results" message).
  final String searchQuery;

  /// Clears search + filters (shown on the filtered-empty state).
  final VoidCallback? onClearFilters;

  const AdvisoryListView({
    super.key,
    required this.responsive,
    required this.isLoading,
    required this.error,
    required this.advisories,
    this.canEdit = false,
    this.showCreateCta = false,
    this.onRetry,
    this.onCreate,
    required this.onShowDetails,
    required this.onDelete,
    required this.onDownload,
    required this.onEdit,
    required this.onToggleStatus,
    this.onRefresh,
    this.hasAnyData = false,
    this.hasActiveFilters = false,
    this.searchQuery = '',
    this.onClearFilters,
  });

  Future<void> _handleRefresh() async {
    await onRefresh?.call();
  }

  /// Makes any content pull-to-refreshable by hosting it in a scrollable.
  Widget _wrapRefresh(Widget child) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double? height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : null;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: height,
                child: Align(alignment: Alignment.center, child: child),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return _wrapRefresh(_buildErrorState(context));
    }

    if (advisories.isEmpty) {
      return _wrapRefresh(_buildEmptyState(context));
    }

    // Wide screens: lazy 2-column masonry grid (variable card heights).
    if (responsive.isDesktop) {
      return _buildGrid(context);
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(responsive.scale(16)),
        itemCount: advisories.length,
        separatorBuilder: (_, _) => SizedBox(height: responsive.scale(12)),
        itemBuilder: (context, index) => _buildCard(context, advisories[index]),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 64, color: scheme.error),
        SizedBox(height: responsive.scale(16)),
        Text(
          'Error loading advisories',
          style: TextStyle(
            fontSize: responsive.scaleFont(16),
            color: scheme.onSurface,
          ),
        ),
        SizedBox(height: responsive.scale(8)),
        Text(
          error!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: responsive.scaleFont(12),
            color: scheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: responsive.scale(16)),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Filtered-empty vs truly-empty: with any data or active filters, explain
    // that the query simply had no matches instead of implying no data exists.
    final bool filteredEmpty = hasAnyData || hasActiveFilters;
    final String query = searchQuery.trim();

    if (!filteredEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: scheme.outlineVariant,
          ),
          SizedBox(height: responsive.scale(16)),
          Text(
            'No advisories found',
            style: TextStyle(
              fontSize: responsive.scaleFont(16),
              color: scheme.onSurface,
            ),
          ),
          if (showCreateCta) ...[
            SizedBox(height: responsive.scale(16)),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Advisory'),
            ),
          ] else ...[
            SizedBox(height: responsive.scale(8)),
            Text(
              'Check back later for new road advisories.',
              style: TextStyle(
                fontSize: responsive.scaleFont(13),
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search_off_outlined, size: 64, color: scheme.outlineVariant),
        SizedBox(height: responsive.scale(16)),
        Text(
          'No results found',
          style: TextStyle(
            fontSize: responsive.scaleFont(16),
            color: scheme.onSurface,
          ),
        ),
        SizedBox(height: responsive.scale(8)),
        Text(
          query.isNotEmpty
              ? 'No advisories match "$query".'
              : 'No advisories match the current filters.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: responsive.scaleFont(13),
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (onClearFilters != null) ...[
          SizedBox(height: responsive.scale(16)),
          TextButton.icon(
            onPressed: onClearFilters,
            icon: const Icon(Icons.filter_alt_off),
            label: const Text('Clear search & filters'),
          ),
        ],
      ],
    );
  }

  Widget _buildGrid(BuildContext context) {
    final left = <Advisory>[];
    final right = <Advisory>[];
    for (var i = 0; i < advisories.length; i++) {
      (i.isEven ? left : right).add(advisories[i]);
    }
    final gutter = responsive.scale(12);

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(responsive.scale(16)),
            sliver: SliverCrossAxisGroup(
              slivers: [
                SliverCrossAxisExpanded(
                  flex: 1,
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: EdgeInsets.only(
                          right: gutter / 2,
                          bottom: gutter,
                        ),
                        child: _buildCard(context, left[index]),
                      ),
                      childCount: left.length,
                    ),
                  ),
                ),
                SliverCrossAxisExpanded(
                  flex: 1,
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: EdgeInsets.only(
                          left: gutter / 2,
                          bottom: gutter,
                        ),
                        child: _buildCard(context, right[index]),
                      ),
                      childCount: right.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, Advisory advisory) {
    // Isolate each card's paint so scrolling a long list doesn't repaint
    // off-screen cards.
    return RepaintBoundary(
      child: AdvisoryCard(
        advisory: advisory,
        responsive: responsive,
        canEdit: canEdit,
        onTap: () => onShowDetails(advisory),
        onDelete: () => onDelete(advisory),
        onDownload: () => onDownload(advisory),
        onEdit: () => onEdit(advisory),
        onToggleStatus: () => onToggleStatus(advisory),
      ),
    );
  }
}
