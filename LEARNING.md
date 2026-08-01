# Learning & Lessons Feature — Build Plan v2

## Purpose
Interactive road safety education integrated into VCRoad's incident-reporting ecosystem. Users learn traffic rules, road signs, and safe practices, then apply that knowledge by reporting violations they now recognize.

---

## Core Philosophy (ISO 25010)

| Quality | How We Address It |
|---------|-------------------|
| **Functional Suitability** | Complete lesson creation/taking flow with 4 question types, unlock progression, spaced repetition, XP/badges, post-lesson report linking |
| **Performance Efficiency** | Snapshot listeners for real-time UI, cursor-based question pagination, FieldValue.increment for counters, batch writes, lazy image loading, offline persistence |
| **Compatibility** | Works alongside existing collections (reports, advisories, users). Supabase Storage bucket shared via prefix `lessons/`. No conflicting rules |
| **Usability** | 4 question types (MCQ, T/F, ID, Matching), progress bars, lock/unlock animation, per-question feedback with explanations, responsive nav (mobile bottom/tablet rail/desktop drawer), preview-before-quiz mode |
| **Reliability** | All writes use Firestore transactions. Offline persistence enables full lesson-taking without connectivity. Server-side time-expiry check. Idempotent per-question best-score logic |
| **Security** | Rules: lessons/questions read=any auth, write=sysadmin. lesson_progress read=any auth, write=matching userId. No PII in lesson content |
| **Maintainability** | DI-ready services (injectable Firestore + Auth). Single-responsibility providers. Question as separate collection (no 1MB doc limit). Consistent naming |
| **Portability** | Pure Dart/Flutter + Firestore + Supabase. No platform-specific code. Builds on existing app shell |

---

## Data Model (Firestore)

```
lessons/{lessonId}
  - title: string
  - description: string
  - chapterId: string (-> chapters)
  - lessonNumber: int
  - isPublished: bool
  - durationMinutes: int (0 = no limit)
  - thumbnailUrl: string? (Supabase)
  - pointsAvailable: int (computed on save)
  - createdAt, createdBy, updatedAt, updatedBy: Timestamp

questions/{questionId}
  - lessonId: string
  - type: enum(multipleChoice|trueFalse|identification|matchingType)
  - questionText: string
  - options: string[]?             (MCQ)
  - correctIndex: int?             (MCQ)
  - optionImageUrls: string[]?     (Supabase)
  - correctBool: bool?             (T/F)
  - correctAnswer: string?         (ID)
  - matchingPairs: MatchingPair[]? (inline map)
  - questionImageUrl: string?      (Supabase)
  - points: int
  - explanation: string?
  - order: int
  # Analytics (auto-updated)
  - timesAnswered: int (default 0)
  - timesCorrect: int (default 0)

chapters/{chapterId}
  - name: string
  - order: int
  - description: string?
  - lessonCount: int (aggregated)

users/{userId}
  # ...existing fields...
  learningStats: {
    completedLessons: int
    totalPointsEarned: int
    totalPointsAvailable: int
    currentStreak: int
    longestStreak: int
    lastActivityDate: Timestamp?
    xp: int
    level: int
  }

lesson_progress/{userId}_{lessonId}
  - userId, lessonId, chapterId, lessonNumber
  - isCompleted: bool
  - isLocked: bool
  - score: double (0-100)
  - attempts: QuestionAttempt[]
  - attemptCount: int
  - questionsAnswered: int
  - questionsCorrect: int
  - pointsEarned: int
  - startedAt, completedAt, lastAccessedAt: Timestamp
  # Spaced repetition
  - nextReviewAt: Timestamp?
  # Badges (earned flags)
  - badges: string[]
```

---

## Questions Collection (Not Nested)

Questions live in their own collection (not as a lessons sub-array). Why:

| Problem with nested array | Solution with separate collection |
|---------------------------|-----------------------------------|
| 1MB doc limit per lesson | Unlimited questions |
| Must fetch all questions even for list view | `getLessons()` never fetches questions |
| Can't paginate | Cursor-based fetch 10-at-a-time |
| Can't query across lessons | Future: "most missed questions" analytics |
| Hard to reuse | Future: question bank |

Each `questions/{questionId}` stores `lessonId` to link back. Order is maintained by the `order` field. Queries use a composite index: `lessonId ASC, order ASC`.

---

## Feature: Spaced Repetition

Each `question_attempt` inside `lesson_progress` records `nextReviewAt`.

**How it works:**
- Correct answer → nextReviewAt = now + 1 day (doubles each subsequent correct: 1d → 2d → 4d → 7d)
- Wrong answer → nextReviewAt = now + 1 hour (resets the interval)
- On `initialize()`, the provider queries: `progresses where nextReviewAt < now and isCompleted == true`
- These appear in a "Review Due" section at the top of the lesson list

**Implementation:**
- Add `interval: int` (hours) to `question_attempt`
- On `submitAnswer`, compute new `nextReviewAt` in the transaction
- `LearnProvider` has a `dueReviews` getter that filters `_progressList`

---

## Feature: Post-Lesson "Report It" Prompt

When a user completes a lesson (LessonResult screen), show a card:

> **"See this on the road? Report it."**
> [Report a Violation] button → deep-links to `ReportScreen` with `category` pre-filled based on lesson tags

**Implementation:**
- Each lesson has optional `tags: string[]` like `["pedestrian", "crossing"]`
- LessonResult screen checks tags and maps to a report category
- Navigation: `context.go('/roaduser')` → switch tab to Report index

---

## Feature: XP & Levels

| XP Range | Level | Title |
|----------|-------|-------|
| 0-99 | 1 | Student Driver |
| 100-299 | 2 | Road Observer |
| 300-699 | 3 | Safety Aware |
| 700-1499 | 4 | Defensive Thinker |
| 1500+ | 5 | Road Master |

**Earning XP:**
- Complete a lesson: +50 XP
- Perfect score (100%): +25 XP bonus
- Streak day (daily login + lesson): +10 XP per day × streak length
- First report after learning: +15 XP

**Storage:** `users/{userId}.learningStats.xp` and `.learningStats.level` — counters only, no new collection.

---

## Feature: Badges

Badges are string flags stored on `lesson_progress.badges[]` and aggregated into `users/{userId}.badges[]` for profile display.

| Badge ID | Trigger |
|----------|---------|
| `first_lesson` | Complete first lesson |
| `perfect_score` | Get 100% on any lesson |
| `streak_3` | 3-day streak |
| `streak_7` | 7-day streak |
| `all_chapters` | Complete all current chapters |
| `quick_learner` | Complete a lesson in <50% of allotted time |
| `reporter` | Submit a report within 5 min of completing a lesson |
| `review_master` | Complete 5 spaced-repetition reviews |

---

## Feature: Preview Before Quiz

The lesson card has two states:

- **Start Lesson** (first time or locked) — opens quiz immediately
- **Review Material** (always available) — opens a read-only scrollable view of lesson content + questions (without answer input)

This is just a `LessonPreview` screen that renders the same UI as the quiz but without input fields and without starting the timer.

---

## Feature: Onboarding Overlay for Learn Tab

First time a user taps the Learn tab, show a 3-step overlay:

1. "Complete lessons in order to unlock the next chapter."
2. "Earn XP, badges, and track your streak."
3. "Use what you learn — report violations you spot on the road."

**Implementation:** `shared_preferences` key `hasSeenLearnOnboarding_{userId}`. Checked in `LearnScreen.initState()`. Can dismiss.

---

## Firestore Security Rules

```
match /lessons/{lessonId} {
  allow read: if isAuthenticated();
  allow create: if isSysAdmin();
  allow update: if isSysAdmin();
  allow delete: if isSysAdmin();
}

match /questions/{questionId} {
  allow read: if isAuthenticated();
  allow create: if isSysAdmin();
  allow update: if isSysAdmin();
  allow delete: if isSysAdmin();
}

match /chapters/{chapterId} {
  allow read: if isAuthenticated();
  allow write: if isSysAdmin();
}

match /lesson_progress/{docId} {
  allow read: if isAuthenticated();
  allow create: if isOwner(request.resource.data.userId);
  allow update: if isOwner(resource.data.userId);
  allow delete: if false;
}
```

Note: `questions` uses its own top-level collection (not subcollection) to keep rules simple and indexes manageable.

---

## Firestore Indexes

```
// lessons list (sorted)
lessons: chapterId ASC, lessonNumber ASC

// published lessons only
lessons: isPublished ASC, chapterId ASC, lessonNumber ASC

// questions by lesson
questions: lessonId ASC, order ASC

// user progress (sorted + filtered)
lesson_progress: userId ASC, chapterId ASC, lessonNumber ASC
lesson_progress: userId ASC, isLocked ASC, chapterId ASC, lessonNumber ASC

// spaced repetition reviews
lesson_progress: userId ASC, nextReviewAt ASC
```

---

## Supabase Storage Bucket

- Bucket: `vcroad` (shared with other features)
- Prefix: `lessons/{lessonId}/`
- Naming: `{type}_{questionId}_{uuid}.{ext}`
  - Types: `question`, `option_0..N`, `pair_0..N`, `thumbnail`
- Compression: 85% quality, max 1200px (question images), 400px (option images)
- Access: Public (Supabase bucket public)

---

## File Structure

```
lib/
  data/
    models/
      lesson.dart
      lesson_progress.dart
      question.dart
    repositories/
      lesson.dart
      lesson_progress.dart
      lesson_image.dart
      badge_service.dart       # Badge award logic
      xp_service.dart          # XP computation
  presentation/
    providers/
      lesson_admin.dart
      learn.dart
    features/
      learning/
        screens/
          learn_screen.dart
          lesson_taking_screen.dart
          lesson_preview_screen.dart
          lesson_management_screen.dart
        widgets/
          lesson_list.dart
          lesson_card.dart
          stats_header.dart
          lesson_viewer.dart
          lesson_result.dart
          report_prompt_card.dart
          question_widgets/
            question_display.dart
            multiple_choice_question.dart
            true_false_question.dart
            identification_question.dart
            matching_question.dart
          lesson_management/
            stats_cards.dart
            filter_bar.dart
            chapter_list.dart
            lesson_card.dart
            create_lesson_dialog.dart
            edit_lesson_dialog.dart
            reorder_dialog.dart
            question_editor.dart
            question_editors/
              multiple_choice_editor.dart
              true_false_editor.dart
              identification_editor.dart
              matching_type_editor.dart
  core/
    constants/
      xp_constants.dart       # XP thresholds, reward amounts
      badge_definitions.dart  # Badge IDs, names, trigger checks
```

---

## Phase Implementation Order

| Phase | What | Why First |
|-------|------|-----------|
| **P1** | Data models + `LessonService` + `LessonProgressService` + Firestore rules + indexes + Supabase image service | Foundation — everything else depends on data layer |
| **P2** | XP service, Badge service, Spaced repetition logic | Core gameplay mechanics; cheap to implement once data layer exists (just counter logic) |
| **P3** | Admin lesson CRUD (create/edit/delete lessons + question editor + chapter management) | Need content before users can consume it |
| **P4** | User lesson browser (LearnScreen with progress bars, lock/unlock, due-reviews section, preview mode, onboarding overlay) | Core navigation UX |
| **P5** | Lesson-taking flow (question display UI, answer submission, timer, navigation) | Core interactive experience |
| **P6** | Completion flow (LessonResult, XP summary, badge awards, "Report It" prompt, unlock next) | Polish, retention, and mission integration |

---

## Key Design Decisions (vs the old feature)

| Old Approach | New Approach | Why |
|---|---|---|
| Questions nested in lesson doc | Questions in separate collection | No 1MB limit, pagination, analytics, reuse |
| No `chapters` collection | `chapters` collection exists from day one | Clean metadata queries, no full-scan |
| `getUserStats` scanned all progress docs | Aggregated counters on `users/{id}.learningStats` | Fast reads, no collection scan |
| `submitAnswer` did read+write outside transaction | Transaction-based with idempotent best-points logic | Atomicity, no race conditions |
| No offline persistence | Firestore persistence enabled | Works offline |
| `getChapterCategories` scanned all lessons | Query `chapters` collection | 1 read vs N reads |
| No spaced repetition | Per-question `nextReviewAt` with exponential intervals | Proven retention improvement |
| No app integration | "Report It" deep-link after each lesson | Connects learning to app mission |
| No XP/badges | XP + level + badge system | User retention, motivation |
| No preview mode | Lessons previewable without starting quiz | Browsing engagement |
