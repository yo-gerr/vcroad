class BadgeDefinition {
  final String id;
  final String name;
  final String description;

  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
  });

  static const List<BadgeDefinition> all = [
    BadgeDefinition(
      id: 'first_lesson',
      name: 'First Steps',
      description: 'Complete your first lesson',
    ),
    BadgeDefinition(
      id: 'perfect_score',
      name: 'Perfect Score',
      description: 'Get 100% on any lesson',
    ),
    BadgeDefinition(
      id: 'streak_3',
      name: 'On a Roll',
      description: 'Maintain a 3-day learning streak',
    ),
    BadgeDefinition(
      id: 'streak_7',
      name: 'Week Warrior',
      description: 'Maintain a 7-day learning streak',
    ),
    BadgeDefinition(
      id: 'all_chapters',
      name: 'Chapter Master',
      description: 'Complete all available chapters',
    ),
    BadgeDefinition(
      id: 'quick_learner',
      name: 'Quick Learner',
      description: 'Complete a lesson in under half the allotted time',
    ),
    BadgeDefinition(
      id: 'reporter',
      name: 'See It, Report It',
      description: 'Submit a report within 5 minutes of completing a lesson',
    ),
    BadgeDefinition(
      id: 'review_master',
      name: 'Review Master',
      description: 'Complete 5 spaced-repetition reviews',
    ),
  ];

  static BadgeDefinition? getById(String id) {
    try {
      return all.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }
}
