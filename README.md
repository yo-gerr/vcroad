# VCRoad v2

Local road incident reporting & traffic advisory management for Valenzuela City, Philippines.

---

## Architecture (ISO 25010-Aligned)

The project follows **Clean Architecture** with **feature-first** organization, designed for **maintainability**, **portability**, and **testability** per ISO 25010.

### Directory Structure

```
lib/
├── main.dart                          # Entry point, provider setup, GoRouter
├── firebase_options.dart              # ⚠ Transitional — will be removed
│
├── core/                              # Cross-cutting concerns
│   ├── constants/                     # App-wide constants (password policy, etc.)
│   ├── errors/                        # Error types and handling
│   ├── theme/                         # (reserved for theme extensions)
│   └── utils/                         # Pure utility modules (no UI)
│       ├── debouncer/                 # Debounce utility
│       ├── exception/                 # try/catch helpers
│       ├── format/                    # Date/text formatting
│       ├── input/                     # Input validation, styling
│       ├── map/                       # Map configuration, controls
│       ├── responsive/                # Responsive breakpoint helpers
│       ├── routing/                   # Role-based routing config
│       └── web/                       # Web-specific stubs
│
├── data/                              # Data layer
│   ├── local/                         # (reserved for local data sources)
│   │   └── database/                  # (reserved for SQLite setup)
│   ├── models/                        # Data models (DTOs, JSON serialization)
│   └── repositories/                  # Repository/service implementations
│
└── presentation/                      # UI layer
    ├── app/                           # App shell, splash screen
    │   ├── app_shell.dart             # Root authenticated screen
    │   └── splash_screen.dart         # Splash with Lottie + precache
    ├── providers/                     # ChangeNotifier state management
    │   ├── theme.dart                 #   ThemeMode toggle (Light/Dark/System) persisted via SharedPreferences
    ├── shared/                        # Shared UI components
    │   ├── dialogs/                   # Reusable dialogs
    │   ├── snackbar/                  # Snackbar utilities
    │   └── widgets/                   # Shared widgets (image, search, stats, video)
        └── features/                      # Feature modules
            ├── auth/                      # Login, Register, Reset Password
            │   ├── screens/               # Feature screens
            │   └── widgets/               # Feature-specific widgets
            ├── onboarding/                # First-time onboarding flow
            │   └── screens/               # OnboardingScreen (tutorial → rationale → ready)
        ├── home/                      # Map dashboard
        │   ├── screens/
        │   └── widgets/
        ├── reports/                   # Incident reporting
        │   ├── screens/
        │   └── widgets/
        │       └── steps/             # Wizard steps
        ├── advisories/                # Advisory management
        │   ├── screens/
        │   └── widgets/
        │       └── steps/             # Wizard steps
        ├── learning/                  # Quiz/lesson system
        │   ├── screens/
        │   └── widgets/
        │       ├── question_widgets/  # Question type displays
        │       └── lesson_management/ # Admin lesson CRUD
        │           └── question_editors/
        ├── admin/                     # User/account management
        │   ├── screens/
        │   └── widgets/
        └── profile/                   # User profile
            ├── screens/
            └── widgets/
```

### Assets Structure

```
assets/
├── database/                     # Archived Firestore snapshots (optional local data)
│   ├── advisories.json           #   — not actively loaded at runtime
│   ├── authentication.json       #   "
│   ├── barangays.json            #   "
│   ├── lesson_progress.json      #   "
│   ├── lessons.json              #   "
│   ├── reports.json              #   "
│   ├── sessions.json             #   "
│   └── users.json                #   "
├── images/
│   ├── advisory-images/          # Archived Storage snapshots (optional local media)
│   ├── lesson-images/            #   "
│   ├── report-images/            #   "
│   ├── user-selfies/             #   "
│   └── user-valid-ids/           #   "
├── lottie/                       # Lottie animation assets
├── json/                         # Static JSON configuration files
├── icons/                        # App icons
├── texts/                        # Text content files
├── barangays/                    # Barangay boundary data (GeoJSON)
├── downloads/                    # Downloadable content
└── fonts/                        # Custom fonts (Poppins)
```

> The `database/` and `images/` trees are archived exports from the old Firestore/Storage instance.  
> They are **not** actively loaded at runtime — the app communicates with live backend APIs.  
> They remain in the repository as a reference / fallback for development convenience.

### ISO 25010 Quality Mapping

| Quality Characteristic | How the Structure Addresses It |
|---|---|
| **Maintainability** | Feature modules encapsulate related UI, state, and logic. Clear dependency direction (→ presentation → data → core). Each layer has a single responsibility. |
| **Portability** | Repository pattern abstracts data sources. `core/utils/web/` isolates platform-specific code via conditional exports. Domain logic is platform-agnostic. |
| **Modularity** | Feature-first grouping makes it easy to add/remove/modify features without affecting others. Shared code lives in `presentation/shared/` or `core/`. |
| **Analyzability** | File names reflect their purpose (e.g., `login_screen.dart`, `auth_service.dart`, `user_provider.dart`). A developer can locate any file by feature + role. |
| **Testability** | Repositories can be mocked independently. Providers are decoupled from UI. Domain logic can be tested without Flutter dependencies. |
| **Reusability** | Shared widgets in `presentation/shared/widgets/` are used across features. Utility functions in `core/utils/` are pure Dart with no UI coupling. |
| **Replaceability** | External services (Firebase, Google Maps) are isolated behind repository interfaces, making them swappable without touching UI code. |

---

## Free API Strategy

The app uses **Firebase Spark (free tier)** as its primary backend and replaces premium/paid APIs with **free, open-source alternatives**:

| Current Service | Free API Replacement | Status |
|---|---|---|
| **Firebase Auth** | Spark free tier (unlimited) | ✅ Active |
| **Cloud Firestore** | Spark free tier (50K reads/day) | ✅ Active |
| **Firebase Storage** | Parked — requires Blaze plan | ⏳ Free alternative TBD |
| **Cloud Functions** | Parked — requires Blaze plan | ⏳ Login tracking migrated to Firestore ✅; remaining functions still require Blaze |
| **Google Maps SDK** | OpenStreetMap via `flutter_map` + `latlong2` | ✅ Done |
| **Google Places API** | Nominatim (free OSM geocoding) | ✅ Done |
| **Google Roads API** | OSRM (free road snapping) | ✅ Done |
| **Google Cloud Vision** | Client-side image heuristics | ✅ Done |
| **Algolia Search** | Firestore queries or Algolia free tier (10K docs) | ⏳ Planned |
| **Google Sheets Export** | Local CSV export | ✅ Done |

> `assets/database/` and `assets/images/` are archived exports from the old Firestore instance.  
> They are **not loaded** at runtime — all data comes from live Firebase (free tier) + free APIs.

### Migration Plan

| Phase | What | Status |
|---|---|---|
| **Phase 0** | Directory restructured for Clean Architecture; Firestore export archived locally | ✅ Done |
| **Phase 1** | Replace Google Maps with `flutter_map` + OSM tiles | ✅ Done |
| **Phase 2a** | Switch Firebase project (Auth + Firestore active) | ✅ Done |
| **Phase 2b** | Replace Google Places API with Nominatim (OSM geocoding) | ✅ Done |
| **Phase 2c** | Replace Cloud Vision with client-side image validation | ✅ Done |
| **Phase 3** | Replace Google Roads API with OSRM | ✅ Done |
| **Phase 4** | Find free alternatives for Storage & Cloud Functions | ⏳ Parked |
| **Phase 5** | Static map generation → OSM tile rendering + Canvas | ✅ Done |
| **Phase 6** | Google Sheets export → local CSV download | ✅ Done |
| **Phase 7** | Replace Algolia with Firestore queries (or keep Algolia free tier) | ⏳ Not started |
| **Phase 8** | Remove unused Google/3rd-party SDKs and config | ⏳ Not started |

### Current Dependency Status

- ✅ `firebase_core`, `firebase_auth`, `cloud_firestore` — **Active (Spark free tier)**
- ⏳ `cloud_functions`, `firebase_storage` — **Parked** (requires Blaze upgrade)
- ✅ `flutter_map`, `latlong2` — **Active** (OpenStreetMap)
- ✅ `geolocator`, `permission_handler`, `http` — **Keep** (platform-agnostic)
- ✅ Nominatim (place search) — **Active** (via `http`)
- ✅ OSRM Nearest API (road snapping) — **Active** (via `http`)
- ✅ Client-side image validation — **Active** (via `image` package)
- ✅ OSM tile rendering (static map export) — **Active** (via `dart:ui` Canvas)
- ✅ Local CSV export — **Active** (replaces Google Sheets proxy)

---

## Data Flow

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
│  Firebase       │   │  Free APIs / Client-Side         │
│  (Spark tier)   │   │  ┌──────────────────────────┐    │
│  ┌──────────┐   │   │  │ Nominatim (geocoding) ✅ │    │
│  │ Auth ✅  │   │   │  │ OSRM (road snap)      ✅ │    │
│  │ Firestore✅│  │   │  │ Client vision heuristics✅│    │
│  │ Storage ⏸️│   │   │  │ OSM tiles (static map) ✅│    │
│  │ Funcs  ⏸️│   │   │  │ CSV export             ✅│    │
│  └──────────┘   │   │  └──────────────────────────┘    │
│                  │   └─────────────────────────────────┘
```

> ✅ = Active (Spark free tier) &nbsp;&nbsp; ⏸️ = Parked (requires Blaze)
---

## Development

### Prerequisites

- Flutter SDK ^3.9.2
- Dart SDK ^3.9.2

### Setup

```bash
flutter pub get
flutter run
```

### Running on Web

```bash
flutter run -d chrome
```

### Running on Android

```bash
flutter run -d android
```

### Session Management

The app implements a Firestore-based session system for **single-device enforcement** and **persistent login**:

- **Persistent login**: Firebase Auth persists credentials via `Persistence.LOCAL`. On app restart, the splash screen calls `SessionService.ensureSession(uid)` which reads the existing session from Firestore (`sessions/{uid}`). If a session exists, it is reused — the user stays logged in without re-authentication.
- **Single-device enforcement**: On login, `checkActiveSession()` reads the Firestore session doc. If another device holds an active session, the user is shown a `SessionConflictDialog` with the option to force-logout the other device. Forcing logout writes a new session ID, which the other device's real-time `watchSession()` listener detects and triggers an automatic sign-out.
- **Session ID**: Each session is identified by a UUID (`Uuid().v4()`), replacing the legacy timestamp-based ID that risked collisions.
- **Cleanup**: `clearSession()` uses `FieldValue.delete()` to properly remove session fields from Firestore (vs. old `null`-setting approach), leaving a clean document on sign-out.
- **Model cleanup**: The `UserDetails` model had 4 dead session fields (`activeSessionId`, `activeDeviceInfo`, `activeSessionStartedAt`, `sessionHistory`) that were never populated by any code. They have been removed from the model, constructor, `fromJson`/`toJson`, and `copyWith`. Session data lives exclusively in the `sessions/{uid}` collection managed by `SessionService`.

### Brute Force Protection

The app implements a **defense-in-depth** approach for login brute-force prevention, aligned with **ISO 25010 Security**:

| Layer | Mechanism | Scope | Cost |
|---|---|---|---|
| **Firestore `loginAttempts`** | Per-email attempt counter; 5 failures → 15 min lockout (stored in `loginAttempts/{email}`) | ✅ Cross-device (all devices share the same Firestore doc) | Spark free tier (1 read + 1 write per attempt) |
| **SharedPreferences** | Local countdown timer for immediate UX feedback (no network latency) | ❌ Per-device only | Free (built-in) |
| **Firebase Auth** | Native `too-many-requests` error after excessive sign-in failures | ✅ Server-side (opaque threshold) | Free (built-in) |

1. When the user taps **Login**, the client first checks its local `SharedPreferences` cache.  
   - If locked locally, a countdown (`_formatLockoutTime`) is shown instantly.
2. `_checkFirestoreLockout()` reads the `loginAttempts/{email}` Firestore doc.  
   - If `lockedUntil` is in the future, throws `too-many-requests` — all devices are blocked.
3. If the lockout is clear, Firebase Auth sign-in proceeds.
4. On credential errors (`wrong-password`, `user-not-found`, etc.), `_trackFirestoreAttempt()` increments the Firestore counter.  
   - At **5 failed attempts**, `lockedUntil` is set to **15 minutes from now** and a `too-many-requests` error is thrown.
5. On any `too-many-requests` (from Firestore check, Firestore tracking, or Firebase Auth itself), the client syncs its local timer to 15 minutes.

> The legacy Cloud Function `trackLoginAttempt` has been **replaced** by direct Firestore reads/writes, eliminating the dependency on the Blaze plan for this feature.

### Location Permission Strategy

Location permission follows the **just-in-time, in-context** principle (ISO 25010 Privacy, OWASP):

| When | What | Rationale |
|---|---|---|
| **During onboarding** (first-time users) | `OnboardingScreen` shows tutorial → location rationale → ready page → "Let's Go" → `AppScreen` is built. `AppScreen` calls `LocationProvider.start()` → `Geolocator.requestPermission()` | User understands the app value before being asked. Rationale explains *why* location is needed: "show your position on the map and tag reports with the correct barangay." |
| **App launch** (returning users) | `_RoadUserScreen` checks `hasSeenAppTutorial` flag → `AppScreen` built directly (no onboarding). `AppScreen` calls `showReminderOnLaunch()` dialog, then `LocationProvider.start()` | Returning users skip onboarding but still get the reminder and location starts automatically. |
| **User taps "Center on me"** | `HomeScreen._centerOnUser()` → `LocationProvider.start()` | User explicitly requests location — no extra rationale needed. |
| **User starts a report** | `ReportStepsScreen._ensureLocationFlow()` → rationale dialog (once per install) → `requestLocation()` | User intends to report an incident; location context is obvious. |
| **App resumes from background** | `HomeScreen.didChangeAppLifecycleState()` → `LocationProvider.start()` | Silently re-acquires if still granted; no new permission dialog. |

The location rationale screen is built into the `OnboardingScreen` for first-time users, and also available via `PermissionService.showLocationRationale` (self-gated via SharedPreferences, at most once per device).

**Onboarding is a dedicated screen, not stacked on top of the app.** The `_RoadUserScreen` widget in the `/roaduser` route checks SharedPreferences before deciding whether to show `OnboardingScreen` or `AppScreen`. This means `AppScreen` (with its map, Firestore streams, and nav shell) is only built **after** onboarding completes — no wasted resources or flash of app UI behind overlays.

### Map Markers

- Markers use `MarkerLayer(rotate: true)` so they counter-rotate against the map's rotation and stay upright (flutter_map 6.x wraps the marker layer in `MobileLayerTransformer` which applies `camera.rotationRad`; `rotate: true` applies `-camera.rotationRad` per-marker to cancel it out).
- Marker sizes are responsive via `ResponsiveInfo.markerScale`: mobile (<600px) = 0.85×, tablet (600–900px) = 1.0×, small desktop (900–1200px) = 1.1×, medium desktop (1200–1600px) = 1.25×, large desktop (≥1600px) = 1.5×. Base sizes: report=44px, advisory=40px, user=52px.
- Marker icons are loaded as `.webp` assets per category (report category, advisory type) and cached at device-appropriate pixel densities.

### Theme System

Design tokens are centralized under `lib/core/theme/`:

| File | Purpose |
|---|---|---|
| `app_colors.dart` | All color constants — brand (`primary`, `primaryAlt`, `primaryDark`), light palette (`background`, `surface`, `surfaceVariant`, `border`), dark palette (`darkBackground`, `darkSurface`, `darkSurfaceVariant`, `darkBorder`, `darkTextSecondary`), semantic (`success`, `warning`, `error`), advisory category colors, and export-specific colors |
| `app_text_styles.dart` | Typography presets — `heading1`–`heading4`, `bodyLarge`/`body`/`bodySmall`, `labelLarge`/`label`/`labelSmall`, `button`, `caption`, `error` — all using the **Poppins** font family |
| `app_theme.dart` | `ThemeData` factories — `light()` (seeded from `Color(0xFF001278)`) and `dark()` (seeded from `#001278` with `Brightness.dark`, then overridden with the navy palette) |

### Palette

| Token | Light | Dark |
|---|---|---|
| Background | `#F7F5FA` | `#081021` |
| Surface | `#FFFFFF` | `#111B2F` |
| Surface Variant | `#F2F4F8` | `#1A2743` |
| Primary | `#001278` | `#001278` |
| Border | `#BDBDBD` | `#2D4A7A` |
| Text Primary | Black | White |
| Text Secondary | Gray | `#B8C7E8` |

**Usage guidelines:**
- **Colors:** Prefer `AppColors.primary` over `Color(0xFF001278)`, `AppColors.background` over `Color(0xFFF7F5FA)`, etc. This keeps the brand color in one place.
- **Text styles:** Prefer `AppTextStyles.body` over inline `TextStyle(fontSize: 15, fontFamily: 'Poppins')`. For overrides, use `.copyWith(...)`.
- **Inherited theme:** Widgets should use `Theme.of(context).textTheme` / `.colorScheme` where possible before reaching for `AppTextStyles` / `AppColors`.
- **Theme toggle:** A `ThemeProvider` (`lib/presentation/providers/theme.dart`) manages a persistent `ThemeMode` selection (Light / Dark / System) stored in `SharedPreferences`. The toggle is accessible in **Profile → Appearance → Theme** via a `SegmentedButton`. The provider is wired in `main.dart` via `MultiProvider` and updates `MaterialApp.router.themeMode` reactively.
- **Dark theme:** Uses a navy-based palette (`#081021` background, `#111B2F` surface, `#1A2743` surface variant, `#2D4A7A` borders, `#B8C7E8` secondary text) that preserves the brand's blue identity while providing a cohesive, modern dark appearance.

### Lint

```bash
flutter analyze
```

---

## Security Model (Firestore Rules)

Role-based access control is enforced at the **database level** via `firestore.rules`, not just the client UI.

### Roles

| Role | Read | Write | Elevation |
|---|---|---|---|
| `user` | Own data, public reports, advisories | Own profile, own reports (if verified, not banned) | Users can **only** set `role: 'user'` on create; no self-elevation |
| `admin` | All users, reports, advisories, settings | User profiles (non-admin users), reports, advisories, settings | Cannot self-promote to `sysadmin` |
| `sysadmin` | Everything | Everything (users, reports, advisories, settings, pending registrations) | Full access |

### Key Rules

- **No self-elevation**: `users/{userId}` create requires `role == 'user'`. Update denies role changes unless the requestor is an admin/sysadmin acting on another user.
- **Report integrity**: `reports/{reportId}` create requires `userId == request.auth.uid` and `reportedBy == request.auth.uid` — no spoofed reports.
- **Verification gating**: Only `isVerified == true` users can create reports.
- **Deny-all fallback**: `match /{document=**}` at the bottom rejects anything not explicitly allowed.

### Deployment

```bash
firebase deploy --only firestore:rules
```

---

## Key Dependencies

| Package | Purpose | Status |
|---------|---------|--------|
| `firebase_core` / `firebase_auth` / `cloud_firestore` | Backend (Spark free tier) | ✅ Active |
| `firebase_storage` | File storage | ⏸️ Parked |
| `cloud_functions` | Server logic (login tracking migrated to Firestore) | ⏸️ Parked (partially replaced) |
| `provider` | State management | — |
| `go_router` | Declarative routing | — |
| `flutter_map` | OpenStreetMap map display | ✅ Active |
| `latlong2` | Coordinate types | ✅ Active |
| `http` | HTTP client for Nominatim / OSRM APIs | ✅ Active |
| `image` | Client-side image decode & validation | ✅ Active |
| `geolocator` | Device GPS | — |
| `permission_handler` | Runtime permissions | — |
| `introduction_screen` | Full-page onboarding tutorial | — |
| `lottie` | Animations | — |
| `shared_preferences` | Key-value prefs | — |
| `image_picker` | Camera/gallery | — |
| `flutter_image_compress` | Image compression | — |

---

*Architecture restructured July 2026. Firebase on Spark free tier, migrating paid APIs to free alternatives.*
