import 'package:flutter/material.dart';
import 'package:vcroad/core/constants/badge_definitions.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class ReviewResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  final String lessonTitle;

  const ReviewResultScreen({
    super.key,
    required this.result,
    required this.lessonTitle,
  });

  @override
  State<ReviewResultScreen> createState() => _ReviewResultScreenState();
}

class _ReviewResultScreenState extends State<ReviewResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  final List<BadgeDefinition> _earnedBadgeDefs = [];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    final badgeIds =
        (widget.result['earnedBadges'] as List?)?.cast<String>() ?? [];
    for (final id in badgeIds) {
      final def = BadgeDefinition.all.where((b) => b.id == id).firstOrNull;
      if (def != null) _earnedBadgeDefs.add(def);
    }

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  int get _xpEarned => (widget.result['xpEarned'] as num?)?.toInt() ?? 0;
  int get _correct => (widget.result['questionsCorrect'] as num?)?.toInt() ?? 0;
  int get _total => (widget.result['questionsAnswered'] as num?)?.toInt() ?? 0;
  double get _score => _total > 0 ? (_correct / _total) * 100 : 0.0;
  DateTime? get _nextReviewAt => widget.result['nextReviewAt'] as DateTime?;

  String get _nextReviewLabel {
    final next = _nextReviewAt;
    if (next == null) return 'No questions scheduled yet';
    final now = DateTime.now();
    final diff = next.difference(now);
    final minutes = diff.inMinutes;
    if (minutes < 60) return 'Next review in $minutes min';
    final hours = diff.inHours;
    if (hours < 24) return 'Next review in $hours h';
    final days = diff.inDays;
    if (days == 1) return 'Next review tomorrow';
    return 'Next review in $days days';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
              Theme.of(context).scaffoldBackgroundColor,
            ],
            stops: const [0, 0.4, 1],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(context.scale(24)),
                child: Column(
                  children: [
                    SizedBox(height: context.scale(20)),
                    _buildScoreCircle(context),
                    SizedBox(height: context.scale(24)),
                    Text(
                      'Review Complete!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.scaleFont(26),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: context.scale(4)),
                    Text(
                      widget.lessonTitle,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: context.scaleFont(15),
                      ),
                    ),
                    SizedBox(height: context.scale(32)),
                    _buildXpCard(context),
                    SizedBox(height: context.scale(16)),
                    _buildNextReviewCard(context),
                    if (_earnedBadgeDefs.isNotEmpty) ...[
                      SizedBox(height: context.scale(16)),
                      _buildBadgeSection(context),
                    ],
                    SizedBox(height: context.scale(32)),
                    _buildBackButton(context),
                    SizedBox(height: context.scale(24)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCircle(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _score / 100),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (_, value, _) {
        return SizedBox(
          width: context.scale(140),
          height: context.scale(140),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: context.scale(140),
                height: context.scale(140),
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(_score * value).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: context.scaleFont(32),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$_correct/$_total',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: context.scaleFont(14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildXpCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(context.scale(20)),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.scale(12)),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.autorenew,
                color: Theme.of(context).colorScheme.primary,
                size: context.scale(28),
              ),
            ),
            SizedBox(width: context.scale(16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'XP Earned',
                    style: TextStyle(
                      fontSize: context.scaleFont(14),
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: context.scale(4)),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: _xpEarned),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOut,
                    builder: (_, value, _) => Text(
                      '+$value XP',
                      style: TextStyle(
                        fontSize: context.scaleFont(24),
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryAdaptive(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextReviewCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: EdgeInsets.all(context.scale(16)),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.scale(10)),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.schedule,
                color: Colors.orange.shade800,
                size: context.scale(24),
              ),
            ),
            SizedBox(width: context.scale(12)),
            Expanded(
              child: Text(
                _nextReviewLabel,
                style: TextStyle(
                  fontSize: context.scaleFont(14),
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeSection(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(context.scale(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Badges Earned',
              style: TextStyle(fontSize: context.scaleFont(16), fontWeight: FontWeight.bold),
            ),
            SizedBox(height: context.scale(12)),
            ..._earnedBadgeDefs.map((badge) {
              return Padding(
                padding: EdgeInsets.only(bottom: context.scale(10)),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.scale(8)),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.autorenew,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: context.scale(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            badge.name,
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: context.scaleFont(14)),
                          ),
                          Text(
                            badge.description,
                            style: TextStyle(
                              fontSize: context.scaleFont(12),
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.check_circle, color: Colors.green, size: context.scale(20)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: EdgeInsets.symmetric(vertical: context.scale(14)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          'Back to Lessons',
          style: TextStyle(fontSize: context.scaleFont(16), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
