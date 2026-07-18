import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/presentation/providers/lesson.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/presentation/features/learning/widgets/lesson_management/stats_cards.dart';
import 'package:vcroad/presentation/features/learning/widgets/lesson_management/filter_bar.dart';
import 'package:vcroad/presentation/features/learning/widgets/lesson_management/chapter_list.dart';
import 'package:vcroad/presentation/features/learning/widgets/lesson_management/create_lesson_dialog.dart';
import 'package:vcroad/presentation/shared/dialogs/loading.dart';

class Lesson extends StatefulWidget {
  const Lesson({super.key});

  @override
  State<Lesson> createState() => _LessonState();
}

class _LessonState extends State<Lesson> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LessonProvider>().loadLessons();
    });
  }

  Future<void> _handleCreateLesson() async {
    final result = await showDialog<QuizMaterial>(
      context: context,
      builder: (_) => const CreateLessonDialog(),
    );

    if (result != null && mounted) {
      final provider = context.read<LessonProvider>();
      String? id;
      // Show loading dialog while creating lesson
      try {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const LoadingDialog(message: 'Creating lesson...'),
        );
        id = await provider.createLesson(result);
      } finally {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // close loading
        }
      }

      if (mounted) {
        if (id != null) {
          SnackbarUtils.showSuccess(context, 'Lesson created successfully');
        } else {
          SnackbarUtils.showError(
            context,
            provider.error ?? 'Failed to create lesson',
          );
        }
      }
    }
  }

  Future<void> _handleRefresh() async {
    await context.read<LessonProvider>().loadLessons(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final provider = context.watch<LessonProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001278),
        elevation: 0,
        title: Text(
          'Lesson Management',
          style: TextStyle(color: Colors.white, fontSize: info.scaleFont(18)),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: info.isDesktop ? 1100 : double.infinity,
          ),
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(info.scale(16)),
                      child: const LessonStatsCards(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: info.scale(16)),
                      child: const LessonFilterBar(),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: info.scale(16))),
                  if (provider.isLoading && provider.chapterGroups.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation(
                                Theme.of(context).primaryColor,
                              ),
                            ),
                            SizedBox(height: info.scale(16)),
                            Text(
                              'Loading lessons...',
                              style: TextStyle(
                                fontSize: info.scaleFont(14),
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (provider.error != null)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: info.scale(64),
                              color: Colors.red,
                            ),
                            SizedBox(height: info.scale(16)),
                            Text(
                              'Error loading lessons',
                              style: TextStyle(
                                fontSize: info.scaleFont(16),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: info.scale(8)),
                            Text(
                              provider.error!,
                              style: TextStyle(
                                fontSize: info.scaleFont(12),
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: info.scale(24)),
                            ElevatedButton.icon(
                              onPressed: _handleRefresh,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (provider.filteredChapterGroups.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: info.scale(64),
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: info.scale(16)),
                            Text(
                              provider.searchQuery.isNotEmpty ||
                                      provider.selectedCategory != null
                                  ? 'No lessons match your filters'
                                  : 'No lessons yet',
                              style: TextStyle(
                                fontSize: info.scaleFont(16),
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: info.scale(8)),
                            Text(
                              provider.searchQuery.isNotEmpty ||
                                      provider.selectedCategory != null
                                  ? 'Try adjusting your filters'
                                  : 'Create your first lesson to get started',
                              style: TextStyle(
                                fontSize: info.scaleFont(12),
                                color: Colors.grey[500],
                              ),
                            ),
                            if (provider.searchQuery.isEmpty &&
                                provider.selectedCategory == null) ...[
                              SizedBox(height: info.scale(24)),
                              ElevatedButton.icon(
                                onPressed: _handleCreateLesson,
                                icon: const Icon(Icons.add),
                                label: const Text('Create Lesson'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  else
                    ChapterListView(
                      chapterGroups: provider.filteredChapterGroups,
                    ),
                  SliverToBoxAdapter(child: SizedBox(height: info.scale(80))),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Builder(
        builder: (ctx) {
          // Responsive FAB: extended for desktop/tablet, regular for mobile
          if (info.isMobile) {
            return FloatingActionButton(
              heroTag: 'fab_create_lesson',
              onPressed: _handleCreateLesson,
              tooltip: 'Create Lesson',
              backgroundColor: const Color(0xFF001278),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            );
          }
          return FloatingActionButton.extended(
            heroTag: 'fab_create_lesson',
            onPressed: _handleCreateLesson,
            backgroundColor: const Color(0xFF001278),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text(
              'Create Lesson',
              style: TextStyle(color: Colors.white),
            ),
            tooltip: 'Create Lesson',
          );
        },
      ),
    );
  }
}
