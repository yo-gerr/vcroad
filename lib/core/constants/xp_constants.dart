class XpConstants {
  XpConstants._();

  static const int xpPerLessonComplete = 50;
  static const int xpBonusPerfectScore = 25;
  static const int xpPerStreakDay = 10;
  static const int xpFirstReportAfterLesson = 15;
  static const int xpPerReview = 5;

  static const List<XpLevel> levels = [
    XpLevel(level: 1, minXp: 0, title: 'Student Driver'),
    XpLevel(level: 2, minXp: 100, title: 'Road Observer'),
    XpLevel(level: 3, minXp: 300, title: 'Safety Aware'),
    XpLevel(level: 4, minXp: 700, title: 'Defensive Thinker'),
    XpLevel(level: 5, minXp: 1500, title: 'Road Master'),
  ];

  static int getLevel(int xp) {
    int level = 1;
    for (final lvl in levels.reversed) {
      if (xp >= lvl.minXp) {
        level = lvl.level;
        break;
      }
    }
    return level;
  }

  static String getLevelTitle(int xp) {
    final level = getLevel(xp);
    return levels.firstWhere((l) => l.level == level).title;
  }

  static int getXpForNextLevel(int xp) {
    final currentLevel = getLevel(xp);
    final nextIndex = levels.indexWhere((l) => l.level == currentLevel) + 1;
    if (nextIndex >= levels.length) return -1;
    return levels[nextIndex].minXp - xp;
  }
}

class XpLevel {
  final int level;
  final int minXp;
  final String title;

  const XpLevel({
    required this.level,
    required this.minXp,
    required this.title,
  });
}
