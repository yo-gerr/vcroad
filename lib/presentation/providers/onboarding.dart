import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingProvider extends ChangeNotifier {
  static const _tutorialKey = 'hasSeenAppTutorial_';
  static const _rationaleKey = 'location_rationale_shown';
  static const _bannerDateKey = 'last_reminder_banner_date';
  static const _coachMarkPrefix = 'coach_mark_';

  String _userId = '';

  OnboardingProvider();

  Future<void> setUserId(String id) {
    _userId = id;
    return load();
  }

  bool _tutorialSeen = false;
  bool _rationaleShown = false;
  DateTime? _lastBannerDate;
  final Set<String> _seenCoachMarks = {};

  bool get tutorialSeen => _tutorialSeen;
  bool get rationaleShown => _rationaleShown;
  DateTime? get lastBannerDate => _lastBannerDate;
  bool get isOnboardingComplete => _tutorialSeen;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _tutorialSeen = prefs.getBool('$_tutorialKey$_userId') ?? false;
    _rationaleShown = prefs.getBool(_rationaleKey) ?? false;
    final bannerStr = prefs.getString(_bannerDateKey);
    if (bannerStr != null) {
      _lastBannerDate = DateTime.tryParse(bannerStr);
    }
    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      if (key.startsWith(_coachMarkPrefix)) {
        _seenCoachMarks.add(key.substring(_coachMarkPrefix.length));
      }
    }
    notifyListeners();
  }

  Future<void> markTutorialSeen() async {
    _tutorialSeen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_tutorialKey$_userId', true);
    notifyListeners();
  }

  Future<void> markRationaleShown() async {
    _rationaleShown = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rationaleKey, true);
    notifyListeners();
  }

  bool hasSeenCoachMark(String feature) => _seenCoachMarks.contains(feature);

  Future<void> markCoachMarkSeen(String feature) async {
    _seenCoachMarks.add(feature);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_coachMarkPrefix$feature', true);
    notifyListeners();
  }

  bool get shouldShowBannerToday {
    if (_lastBannerDate == null) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(
      _lastBannerDate!.year,
      _lastBannerDate!.month,
      _lastBannerDate!.day,
    );
    return today.isAfter(last);
  }

  Future<void> markBannerShownToday() async {
    _lastBannerDate = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bannerDateKey, _lastBannerDate!.toIso8601String());
    notifyListeners();
  }
}
