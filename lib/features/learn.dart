import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vcroad_v2/shared/providers/learning.dart';
import 'package:vcroad_v2/shared/providers/user.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/widgets/learn/stats_header.dart';
import 'package:vcroad_v2/shared/widgets/learn/lesson_list.dart';
import 'package:vcroad_v2/shared/widgets/learn/lesson_viewer.dart';

class Learn extends StatefulWidget {
  const Learn({super.key});

  @override
  State<Learn> createState() => _LearnState();
}

class _LearnState extends State<Learn> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserProvider>().user;
      if (user != null) {
        context.read<LearningProvider>().initialize(user.userId);
      }
    });
  }

  Future<void> _handleRefresh() async {
    await context.read<LearningProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final learningProvider = context.watch<LearningProvider>();

    // If a lesson is active, show the lesson viewer
    if (learningProvider.currentLesson != null) {
      return const LessonViewer();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001278),
        elevation: 0,
        title: Text(
          'Learn',
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
              child: learningProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : learningProvider.error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                            learningProvider.error!,
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
                    )
                  : CustomScrollView(
                      slivers: [
                        const SliverToBoxAdapter(child: LearningStatsHeader()),
                        SliverToBoxAdapter(
                          child: SizedBox(height: info.scale(16)),
                        ),
                        const LessonList(),
                        SliverToBoxAdapter(
                          child: SizedBox(height: info.scale(80)),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
