import 'package:flutter/foundation.dart';
import 'package:vcroad/data/models/lesson.dart';
import 'package:vcroad/data/repositories/lesson.dart';

class LessonProvider with ChangeNotifier {
  final LessonService _service = LessonService.instance;

  List<ChapterGroup> _chapterGroups = [];
  List<QuizMaterial> _allLessons = [];
  List<String> _categories = [];

  bool _isLoading = false;
  String? _error;

  // Filters
  String? _selectedCategory;
  bool _showPublishedOnly = false;
  String _searchQuery = '';

  // Getters
  List<ChapterGroup> get chapterGroups => _chapterGroups;
  List<QuizMaterial> get allLessons => _allLessons;
  List<String> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  bool get showPublishedOnly => _showPublishedOnly;
  String get searchQuery => _searchQuery;

  // Filtered lessons based on current filters
  List<ChapterGroup> get filteredChapterGroups {
    if (_searchQuery.isEmpty && _selectedCategory == null) {
      return _chapterGroups;
    }

    final filtered = <ChapterGroup>[];
    for (final group in _chapterGroups) {
      if (_selectedCategory != null && group.category != _selectedCategory) {
        continue;
      }

      final matchingLessons = group.lessons.where((lesson) {
        if (_searchQuery.isEmpty) return true;
        final query = _searchQuery.toLowerCase();
        return lesson.title.toLowerCase().contains(query) ||
            lesson.description.toLowerCase().contains(query) ||
            lesson.chapterCategory.toLowerCase().contains(query) ||
            lesson.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();

      if (matchingLessons.isNotEmpty) {
        filtered.add(
          ChapterGroup(category: group.category, lessons: matchingLessons),
        );
      }
    }

    return filtered;
  }

  int get totalLessons => _allLessons.length;
  int get totalQuestions =>
      _allLessons.fold(0, (sum, l) => sum + l.questionCount);
  int get publishedCount => _allLessons.where((l) => l.isPublished).length;
  int get draftCount => _allLessons.where((l) => !l.isPublished).length;

  // Load all lessons
  Future<void> loadLessons({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _chapterGroups = await _service.getLessonsGroupedByChapter(
        publishedOnly: _showPublishedOnly ? true : null,
      );

      _allLessons = _chapterGroups.expand((group) => group.lessons).toList();

      // Derive categories from loaded lessons to avoid extra Firestore call
      final categorySet = <String>{};
      for (final g in _chapterGroups) {
        categorySet.add(g.category);
      }
      _categories = categorySet.toList()..sort();

      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('LessonProvider.loadLessons error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set filter: category
  void setSelectedCategory(String? category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    notifyListeners();
  }

  // Toggle published filter
  void togglePublishedOnly() {
    _showPublishedOnly = !_showPublishedOnly;
    loadLessons(forceRefresh: true);
  }

  // Set search query
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  // Clear all filters
  void clearFilters() {
    _selectedCategory = null;
    _searchQuery = '';
    _showPublishedOnly = false;
    notifyListeners();
  }

  // Create lesson
  Future<String?> createLesson(QuizMaterial lesson) async {
    try {
      final id = await _service.createLesson(lesson);
      await loadLessons(forceRefresh: true);
      return id;
    } catch (e) {
      _error = e.toString();
      debugPrint('LessonProvider.createLesson error: $e');
      notifyListeners();
      return null;
    }
  }

  // Update lesson
  Future<bool> updateLesson(QuizMaterial lesson) async {
    try {
      await _service.updateLesson(lesson);

      // Update local cache
      final index = _allLessons.indexWhere((l) => l.id == lesson.id);
      if (index != -1) {
        _allLessons[index] = lesson;

        // Update in chapter groups
        for (final group in _chapterGroups) {
          final lessonIndex = group.lessons.indexWhere(
            (l) => l.id == lesson.id,
          );
          if (lessonIndex != -1) {
            group.lessons[lessonIndex] = lesson;
            break;
          }
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('LessonProvider.updateLesson error: $e');
      notifyListeners();
      return false;
    }
  }

  // Delete lesson
  Future<bool> deleteLesson(String lessonId) async {
    try {
      await _service.deleteLesson(lessonId);
      await loadLessons(forceRefresh: true);
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('LessonProvider.deleteLesson error: $e');
      notifyListeners();
      return false;
    }
  }

  // Reorder lessons
  Future<bool> reorderLessons(List<QuizMaterial> lessons) async {
    try {
      await _service.reorderLessons(lessons);
      await loadLessons(forceRefresh: true);
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('LessonProvider.reorderLessons error: $e');
      notifyListeners();
      return false;
    }
  }

  // Toggle publish status
  Future<bool> togglePublishStatus(String lessonId, bool publish) async {
    try {
      await _service.togglePublishStatus(lessonId, publish);

      // Update local cache
      final index = _allLessons.indexWhere((l) => l.id == lessonId);
      if (index != -1) {
        _allLessons[index] = _allLessons[index].copyWith(isPublished: publish);

        // Update in chapter groups
        for (final group in _chapterGroups) {
          final lessonIndex = group.lessons.indexWhere((l) => l.id == lessonId);
          if (lessonIndex != -1) {
            group.lessons[lessonIndex] = group.lessons[lessonIndex].copyWith(
              isPublished: publish,
            );
            break;
          }
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('LessonProvider.togglePublishStatus error: $e');
      notifyListeners();
      return false;
    }
  }

  // Get lesson by ID
  QuizMaterial? getLessonById(String id) {
    try {
      return _allLessons.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Get chapter info list for UI
  Future<List<ChapterInfo>> getChapterInfoList() async {
    try {
      return await _service.getChapterInfoList();
    } catch (e) {
      debugPrint('LessonProvider.getChapterInfoList error: $e');
      return [];
    }
  }

  // Get metadata for a specific category (or new category)
  Future<ChapterMetadata> getChapterMetadata(String category) async {
    try {
      return await _service.getChapterMetadata(category);
    } catch (e) {
      debugPrint('LessonProvider.getChapterMetadata error: $e');
      return ChapterMetadata(
        category: category,
        chapterOrder: 0,
        nextLessonNumber: 1,
        exists: false,
      );
    }
  }
}
