# VCRoad

[![Flutter](https://img.shields.io/badge/Flutter-3.12+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12+-0175C2?logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Spark-FFCA28?logo=firebase)](https://firebase.google.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Website](https://img.shields.io/badge/Web-vcroad.app-001278)](https://vcroad.app)

**Local road incident reporting & traffic advisory management for Valenzuela City, Philippines.**

VCRoad is a cross-platform mobile and web application that empowers citizens to report road incidents (accidents, potholes, floods, debris) and stay informed with real-time traffic advisories. Built for Valenzuela City, the app replaces paper-based reporting with a digital, map-driven experience — integrating incident reports, traffic advisories, road safety education, and role-based administration into a single platform.

---

## Features

<details>
<summary><b>🗺️ Map Dashboard</b></summary>

- Real-time map view of all reported incidents and active advisories using OpenStreetMap
- Interactive markers with category-based icons and color coding
- Barangay-level filtering and statistics
- "Center on me" GPS location with permission-gated access
- Marker clustering with responsive sizing across devices
</details>

<details>
<summary><b>📝 Incident Reporting</b></summary>

- Multi-step wizard: category selection → location pinning → media capture → review & submit
- Image upload with client-side validation (size, resolution, content heuristics)
- GPS-assisted barangay auto-detection
- Report history with status tracking
- Email verification required before first report
</details>

<details>
<summary><b>🚦 Traffic Advisories</b></summary>

- Create and publish advisories (road closures, stop-and-go, one-way, construction, etc.)
- Map-based route plotting with OSRM road snapping
- Configurable severity levels and affected areas
- Real-time updates pushed to all users
- **Enhanced data model** — advisories carry a stable `barangayId` (from the GeoJSON `id`), a Firestore `GeoPoint` `center` plus `boundsNE`/`boundsSW` for geo-queryability, denormalized lowercase `searchKeywords` for indexed `array-contains` search, `createdByUid`/`updatedByUid` audit fields, a capped `versionHistory` audit trail, and `statusUpdatedAt`/`nextStatusAt` timestamps
- **Optimistic locking** — edits increment `version` inside a Firestore transaction and fail with a refresh prompt on conflict; security rules enforce the `version + 1` bump and protect immutable fields (`advisoryId`, `createdAt`, `createdBy`, `createdByUid`)
- **Single consolidated stream** — regular users share one realtime stream (active + scheduled, all barangays) that powers the home map, the advisory list, and the new-advisory alert popups (derived from new additions after the session baseline, with mute/dedupe/self-notification guards); the map always plots only active advisories and barangay selection on the advisory screen is a client-side filter. The admin/sysadmin all-statuses stream is capped at the 200 latest advisories for performance.
- **Shared advisory UI** — status badges render through one `AdvisoryStatusBadge` widget and category icons through `AdvisoryCategory.iconFor` (labels/colors/icons come from the model, so cards, detail dialogs, and the wizard never drift apart). Desktop/wide screens show the advisory list as a 2-column card grid, and empty states offer an admin Create CTA. The advisory screen is split into testable widgets (`AdvisoryCard`, `AdvisoryListView`) so the list body can be exercised without Firebase.
- **Quick status toggle** — admins can Activate/Deactivate any advisory directly from its card (re-saves with the persisted status and a bumped `version`; no manual re-save needed). The advisory list also supports Newest / Oldest / Recently-updated sorting.
- **UI/UX & layout (ISO 25010-aligned)** — the advisory screen surfaces the active sort as a labeled control, the top stat cards (admin/sysadmin only) are a read-only summary (filtering is done through the single chip row below), and pull-to-refresh (mobile) or a refresh action (desktop) re-subscribe the stream. Contextual empty states distinguish "no data yet" from "no results for your search/filters" (with a Clear search & filters action). The whole surface is theme-aware — stat cards, filter chips, the card grid, and the details dialog all use `Theme.colorScheme` + `AppColors.primaryAdaptive` tokens (darker accents brightened in dark mode for ~3:1 contrast) while the brand-navy AppBar/FAB stay fixed; category icons pick dark or light ink from the chip color's luminance (e.g. the yellow partial-lane chip gets a dark icon) to keep WCAG contrast. Desktop uses a lazy 2-column masonry grid with each card isolated in a `RepaintBoundary` so scrolling doesn't repaint off-screen cards, and card action rows wrap instead of overflowing on narrow screens. The advisory details dialog shows a read-only mini map that auto-fits the entire affected + alternate route plot (padded, zoomed out one level, with a graceful fallback for single-point routes), and its image preview uses a stable hero tag. Screen-reader users get `selected`/button semantics on filters, a labeled sort control, and a semantically labeled card.
- **Inline wizard validation & save safety** — validation errors in the create/edit wizard surface as a persistent inline banner above the navigation bar (not just a transient snackbar), the Details step shows live inline hints on the reason and contractor fields as you type, and an advisory photo (validated client-side: 5 MB cap, JPG/PNG) uploads to Supabase Storage at `advisories/{id}/image.jpg` with the superseded image cleaned up on edit. Save failures surface in the same inline banner with the real error, and leaving the wizard with unsaved changes triggers a discard confirmation via `PopScope` (with `mounted` guards on async saves).
- **Status lifecycle (deferred)** — statuses (`active` / `inactive` / `expired` / `scheduled`) are currently set on save (client-side). `nextStatusAt` records *when* each status should next change (one-time `startDate`/`endDate` or the next recurring window boundary), so a future scheduled job or client evaluator can auto-transition by querying `status` + `nextStatusAt`. Until such a job exists, a status only changes when an admin re-saves the advisory.
</details>

<details>
<summary><b>📚 Road Safety Education</b></summary>

- Interactive lessons with 4 question types: multiple choice, true/false, identification, matching type
- Question images supported across all types (e.g., road-signage photos): question-level images for identification/true-false, per-option images for multiple choice, and image→meaning pairs for matching type
- Admin question editor lets you attach images to any question or option (uploaded and compressed on save) — ideal for signage identification drills
- **Learn dashboard** — stats header with level badge & title (Student Driver → Road Master), XP progress bar, day streak, lessons completed X/Y, overall completion %, and a tappable due-review counter that jumps to the first lesson scheduled for review
- **Per-chapter progress** — expandable chapter headers show completed/total lesson counts with green progress bars
- **Progressive unlocking** — only the first lesson and each chapter's opener start unlocked (locked cards are greyed out); scoring **70% or higher** completes a lesson and unlocks the next one
- **Retake flow** — scores below 70% show a "Keep Going!" result with a pass-hint card and a **Retake Lesson** button that resets the lesson's progress for another attempt
- **Spaced-repetition reviews** — completed lessons open a dedicated review screen: due questions by default (intervals double on correct answers, reset on wrong), an "All caught up!" state with a next-review countdown and a **Review all questions anyway** option, +5 XP per completed review, and a result screen showing the next review countdown
- **Preview mode** — admin/sysadmin-only toggle on the Learn page that unlocks every lesson card for browsing; regular users always follow the locked progression. Opening an unlocked-but-not-completed lesson in preview is a placeholder ("coming soon"), while completed lessons open normally.
- **XP system** with 5 levels (Student Driver → Road Master), streak tracking, and streak bonuses
- **8 achievement badges** (First Steps, Perfect Score, On a Roll, Week Warrior, Chapter Master, Quick Learner, See It — Report It, Review Master) — 7 are earnable today; "See It, Report It" awaits the report-flow link-up
- Animated XP preview as final onboarding slide — shows level progression before entering the app
- Rich lesson result screen with animated score circle, XP counter, level-up indicator, and badge awards (plus a dedicated retake state when the pass threshold isn't met)
- "Report It" prompt after lesson completion — encourages filing a road report tied to what was learned (placeholder: the report link-up is not yet wired)
- Admin/sysadmin lesson management: create, edit, delete, publish/unpublish, and per-lesson question editor (lessons are auto-numbered; chapters and questions are drag-reorderable) — the lesson list adds search, summary chips (N Chapters / N Lessons / N Published), and pull-to-refresh, and the question editor guards against losing unsaved changes. Lessons auto-sum per-question points into their total, and per-answer analytics (`timesAnswered` / `timesCorrect`) are tracked in Firestore.
- Chapter manager with drag-to-reorder chapters
- Role-aware tutorial with animated widget previews (users: 5 slides including XP preview; admins: 3 slides with dashboard overview)
- Location permission requested contextually at point of need (center-on-map or first report), not during onboarding
</details>

<details>
<summary><b>👤 User Roles & Administration</b></summary>

- Three roles: `user`, `admin`, `sysadmin` enforced at both UI and Firestore rules level
- Admin panel for user management, bans, and role elevation
- Account search scans the whole `users` collection (bounded scan loop over createdAt-ordered pages) so matches are found regardless of where they sit — no paid search service (Algolia) or Cloud Functions involved; pagination is cursor-based and compositely indexed in `firestore.indexes.json`
- Registration flow with identity verification (valid ID + selfie capture)
- Reusable searchable Barangay dropdown (register, profile details, and create-admin) with instant cached names, normalized/prefixed search, load error + Retry, and a no-results state
- Profile details page: view/edit contact & address (phone, street, house number, barangay dropdown), read-only name & email, role/verification badges, selfie display, and an unsaved-changes guard when leaving while editing
- Profile management with appearance settings (theme toggle)
</details>

<details>
<summary><b>🔐 Security & Session Management</b></summary>

- Firestore-based role verification in security rules (no self-elevation)
- Brute force protection: Firestore-based per-email lockout (5 failed attempts → 15-min block) + local SharedPreferences cache
- Single-device session enforcement: on login from a new device, the old device is notified and signed out
- Persistent login via Firebase Auth local persistence
- Password reset via email link with rate-limited resends (45s cooldown) and anti-enumeration messaging
</details>

<details>
<summary><b>🌙 Theme System</b></summary>

- Light and dark themes with a navy-based dark palette
- Persistent theme toggle via SharedPreferences (Light / Dark / System)
- Accessible from Profile → Appearance → Theme
- Full dark-mode coverage, including the profile details page — surface cards, text, dividers, and outlined buttons adapt to the active theme while brand-blue header and input fields stay consistent
</details>

---

## Technology Stack

<details>
<summary><b>📱 Framework & Language</b></summary>

| Component | Technology |
|-----------|-----------|
| Framework | Flutter ^3.12.2 |
| Language | Dart ^3.12.2 |
| Platforms | Android, iOS, Web, Windows, macOS, Linux |
</details>

<details>
<summary><b>🗄️ Backend & Database</b></summary>

| Service | Status | Details |
|---------|--------|---------|
| Firebase Authentication | ✅ Active | Email/password, Spark free tier (unlimited) |
| Cloud Firestore | ✅ Active | Primary database, Spark free tier (50K reads/day) |
| Supabase Storage | ✅ Active | Image uploads for advisories, reports & lessons (1 GB free tier) |
| Firebase Storage | ⏸️ Parked | Not used — Supabase Storage is the live backend |
| Cloud Functions | ⏸️ Parked | Login tracking migrated to Firestore directly |
</details>

<details>
<summary><b>🗺️ Maps & Location</b></summary>

| Service | Replacement For | Status |
|---------|----------------|--------|
| OpenStreetMap via `flutter_map` | Google Maps SDK | ✅ Active |
| Nominatim (OSM geocoding) | Google Places API | ✅ Active |
| OSRM Nearest API (road snapping) | Google Roads API | ✅ Active |
| Client-side image validation | Google Cloud Vision | ✅ Active |
| OSM tile rendering via Canvas | Static map generation | ✅ Active |
</details>

<details>
<summary><b>📦 Key Packages</b></summary>

| Category | Packages |
|----------|---------|
| State Management | `provider` |
| Routing | `go_router`, `url_strategy` |
| Firebase | `firebase_core`, `firebase_auth`, `cloud_firestore` |
| Maps & Location | `flutter_map`, `latlong2`, `geolocator`, `permission_handler` |
| HTTP & APIs | `http` |
| UI Components | `lottie`, `carousel_slider`, `introduction_screen`, `cached_network_image` |
| Media | `image_picker`, `file_picker`, `image`, `flutter_image_compress`, `video_player`, `video_thumbnail` |
| Utilities | `shared_preferences`, `uuid`, `device_info_plus`, `intl`, `url_launcher` |
| Fonts | Poppins (Regular + Bold) |
</details>

---

## Architecture

VCRoad follows **Clean Architecture** with **feature-first** organization, aligned with **ISO 25010** quality standards.

### Data Flow

```
┌──────────────────────────────────────────────────────────┐
│                   Presentation Layer                      │
│  Screens ↔ Providers (ChangeNotifier) ↔ Shared Widgets   │
└────────────────────────┬─────────────────────────────────┘
                         │ calls
┌────────────────────────▼─────────────────────────────────┐
│                   Repository Layer                        │
│  AuthRepo │ ReportRepo │ AdvisoryRepo │ LessonRepo ...    │
└──────┬──────────────────────┬────────────────────────────┘
       │                      │
┌──────▼──────────┐   ┌──────▼──────────────────────────┐
│  Firebase        │   │  Free APIs / Client-Side         │
│  (Spark tier)    │   │  ┌──────────────────────────┐    │
│  ┌──────────┐    │   │  │ Nominatim (geocoding) ✅ │    │
│  │ Auth ✅  │    │   │  │ OSRM (road snap)      ✅ │    │
│  │ Firestore✅│   │   │  │ Client vision heuristics✅│    │
│  └──────────┘    │   │  │ OSM tiles (static map) ✅ │    │
│                  │   │  │ CSV export             ✅ │    │
│                  │   │  └──────────────────────────┘    │
└──────────────────┘   └─────────────────────────────────┘
```

### ISO 25010 Quality Mapping

| Quality | How the Structure Addresses It |
|---------|-------------------------------|
| **Maintainability** | Feature modules encapsulate related UI, state, and logic. Clear dependency direction (→ presentation → data → core). |
| **Portability** | Repository pattern abstracts data sources. Platform-specific code isolated via conditional exports. |
| **Modularity** | Feature-first grouping makes it easy to add/remove/modify features without affecting others. |
| **Analyzability** | File names reflect their purpose (e.g., `login_screen.dart`, `auth_service.dart`). |
| **Testability** | Repositories can be mocked independently. Providers decoupled from UI. Domain logic testable without Flutter dependencies. |
| **Reusability** | Shared widgets used across features. Utility functions are pure Dart with no UI coupling. |
| **Replaceability** | External services isolated behind repository interfaces, swappable without touching UI code. |

---

## Installation

<details>
<summary><b>Prerequisites</b></summary>

- Flutter SDK ^3.12.2
- Dart SDK ^3.12.2
- Firebase project (configured with Authentication and Firestore)
- A code editor (VS Code, Android Studio, or IntelliJ)
</details>

<details>
<summary><b>Setup</b></summary>

```bash
# Clone the repository
git clone https://github.com/yo-gerr/vcroad.git
cd vcroad

# Configure environment variables
cp .env.example .env
#  -> Edit .env and fill in your Supabase project URL and anon/publishable key.

# Install dependencies
flutter pub get

# Run on your preferred platform
flutter run -d chrome     # Web
flutter run -d android    # Android
flutter run -d ios        # iOS (macOS only)

# Generate launcher icons (if needed)
flutter pub run flutter_launcher_icons
```

> **Note:** `.env` is gitignored and holds the Supabase credentials. The anon/publishable
> key is **public by design** (it ships in the client binary), so production data security
> relies on **Supabase RLS / storage-bucket policies**, not on keeping the key secret.
</details>

<details>
<summary><b>Firebase Configuration</b></summary>

The app uses Firebase for authentication and data storage. Configuration files are included:

- `lib/firebase_options.dart` — auto-generated by FlutterFire CLI
- `android/app/google-services.json` — Android Firebase config
- `ios/Runner/GoogleService-Info.plist` — iOS Firebase config (if present)

To use your own Firebase project, run:

```bash
flutter pub add firebase_core
flutterfire configure
```

This regenerates `firebase_options.dart` and the platform-specific config files.
</details>

<details>
<summary><b>Lint & Analyze</b></summary>

```bash
flutter analyze
```
</details>

---

## Folder Structure

```
lib/
├── main.dart                         # Entry point, provider setup, GoRouter
├── core/                             # Cross-cutting concerns
│   ├── constants/                    # App-wide constants (config, password policy)
│   ├── errors/                       # Error types and handling
│   ├── theme/                        # AppColors, AppTextStyles, AppTheme
│   └── utils/                        # Pure utility modules (no UI)
│       ├── debouncer/                # Debounce utility
│       ├── exception/                # try/catch helpers
│       ├── format/                   # Date/text formatting
│       ├── input/                    # Input validation, styling
│       ├── map/                      # Map configuration
│       ├── responsive/               # Responsive breakpoint helpers
│       ├── routing/                  # Role-based routing config
│       └── web/                      # Web-specific stubs
├── data/                             # Data layer
│   ├── models/                       # Data models (DTOs, JSON serde)
│   └── repositories/                 # Repository/service implementations
└── presentation/                     # UI layer
    ├── app/                          # App shell, splash screen
    ├── providers/                    # 9 ChangeNotifier state managers
    ├── shared/                       # Shared dialogs, snackbar, widgets (banner, location prompt, coach marks)
    └── features/                     # Feature modules
        ├── auth/                     # Login, Register, Reset Password
        ├── onboarding/               # Role-aware tutorial with animated slides
        ├── home/                     # Map dashboard
        ├── reports/                  # Incident reporting wizard
        ├── advisories/               # Advisory management wizard
        ├── lesson/                   # Quiz/lesson system
        ├── admin/                    # User/account administration
        └── profile/                  # User profile & settings

assets/
├── fonts/                            # Poppins (Regular, Bold)
├── icons/                            # Map markers, app icons (.webp)
├── images/                           # Feature illustrations, user content
├── lottie/                           # Lottie animation files
├── json/                             # Static configuration
├── texts/                            # Agreement text (EN + Tagalog)
├── barangays/                        # Barangay boundary GeoJSON
├── database/                         # Archived Firestore snapshots (reference only)
└── downloads/                        # Downloadable content
```

---

## Security Model

Role-based access control is enforced at the **database level** via `firestore.rules`, not just the client UI.

| Role | Read | Write | Elevation |
|------|------|-------|-----------|
| `user` | Own data, public reports, advisories | Own profile, own reports (if verified, not banned) | Self-registration sets `role: user` only |
| `admin` | All users, reports, advisories, settings | User profiles (non-admin), reports, advisories, settings | Cannot self-promote to `sysadmin` |
| `sysadmin` | Everything | Everything | Full access |

### Key Rules

- **No self-elevation** — role changes denied unless performed by admin/sysadmin on another user
- **Report integrity** — `userId` and `reportedBy` must match the authenticated user
- **Verification gating** — only verified users can create reports
- **Deny-all fallback** — `match /{document=**}` at the bottom rejects anything not explicitly allowed

### Deploy Rules & Indexes

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

> ⚠️ Firestore may prompt you to accept the composite indexes added in
> `firestore.indexes.json` (advisories `status`/`barangay`/`barangayId`
> + `createdAt`, and `status` + `nextStatusAt`) before queries using them work.

### Migrate Existing Advisories

After deploying rules + indexes, backfill existing advisory documents with the
new schema (idempotent, dry-run by default):

```bash
node scripts/migrate_advisories.js            # preview what will change
node scripts/migrate_advisories.js --run      # apply the backfill
```

---

## Testing

Pure-Dart and widget tests (no Firebase required):

```bash
flutter test
```

- `test/advisory_model_test.dart` — model units: status labels/colors, category
  lookup + icon fallback, `buildSearchKeywords`, `computeCenter`/`computeBounds`,
  `computeNextStatusAt` (one-time + recurring + wrap-around), and tolerant
  `fromJson`/`toJson` round-trips.
- `test/widget_test.dart` — widget tests for the shared advisory UI:
  `AdvisoryStatusBadge` labels/colors and `AdvisoryCard` content, admin-action
  visibility, callback wiring, recurring-schedule rendering, the lazy desktop
  masonry grid, and the filtered-empty state's clear-filters action.

---

## Future Improvements

<details>
<summary><b>Planned Enhancements</b></summary>

| Priority | Feature | Notes |
|----------|---------|-------|
| 🔴 High | Add Firebase App Check | Protects API keys from unauthorized use |
| 🟡 Medium | Storage quota & image optimization | Uploads already run on Supabase Storage (1 GB free tier); add a compression/cleanup pipeline for larger media |
| 🟡 Medium | Cloud Functions integration | Login tracking migrated; remaining functions pending Blaze |
| 🟡 Medium | End-to-end testing suite | Provider-based architecture primed for integration tests |
| 🟡 Medium | CI/CD pipeline | GitHub Actions for lint → test → build |
| 🟢 Low | Push notifications | Real-time alerting for new advisories |
| 🟢 Low | Offline-first support | Firestore persistence + local sync |
| 🟢 Low | Accessibility (a11y) audit | Screen reader labels, contrast, keyboard navigation |
| 🟢 Low | Localization expansion | Beyond English/Tagalog |
</details>

---

## Contributing

Contributions are welcome. This project does not yet have a formal `CONTRIBUTING.md` — for now, please open an issue or pull request on GitHub. Basic guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

---

## License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for more information.

*MIT is recommended for open-source Flutter projects — it's permissive, allows commercial use, and is the most widely adopted license in the Flutter ecosystem.*

---

## Links

- **Website:** [https://vcroad-a76a1.web.app](https://vcroad-a76a1.web.app)
- **Repository:** [https://github.com/yo-gerr/vcroad](https://github.com/yo-gerr/vcroad)
- **Issue Tracker:** [GitHub Issues](https://github.com/yo-gerr/vcroad/issues)

---

*Built with Flutter. Backend on Firebase Spark free tier. Maps powered by OpenStreetMap and contributors. Architecture restructured July 2026.*
