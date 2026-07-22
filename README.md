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
</details>

<details>
<summary><b>📚 Road Safety Education</b></summary>

- Interactive lessons with multiple question types: multiple choice, true/false, identification, matching
- Progress tracking with lesson completion stats
- Admin lesson management (create, edit, reorder, filter)
- Confetti celebration on lesson completion
</details>

<details>
<summary><b>👤 User Roles & Administration</b></summary>

- Three roles: `user`, `admin`, `sysadmin` enforced at both UI and Firestore rules level
- Admin panel for user management, bans, and role elevation
- Registration flow with identity verification (valid ID + selfie capture)
- Profile management with appearance settings (theme toggle)
</details>

<details>
<summary><b>🔐 Security & Session Management</b></summary>

- Firestore-based role verification in security rules (no self-elevation)
- Brute force protection: Firestore-based per-email lockout (5 failed attempts → 15-min block) + local SharedPreferences cache
- Single-device session enforcement: on login from a new device, the old device is notified and signed out
- Persistent login via Firebase Auth local persistence
</details>

<details>
<summary><b>🌙 Theme System</b></summary>

- Light and dark themes with a navy-based dark palette
- Persistent theme toggle via SharedPreferences (Light / Dark / System)
- Accessible from Profile → Appearance → Theme
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
| Firebase Storage | ⏸️ Parked | Requires Blaze plan — alternative TBD |
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
| UI Components | `lottie`, `carousel_slider`, `introduction_screen`, `confetti`, `cached_network_image` |
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

# Install dependencies
flutter pub get

# Run on your preferred platform
flutter run -d chrome     # Web
flutter run -d android    # Android
flutter run -d ios        # iOS (macOS only)

# Generate launcher icons (if needed)
flutter pub run flutter_launcher_icons
```
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
    ├── providers/                    # 8 ChangeNotifier state managers
    ├── shared/                       # Shared dialogs, snackbar, widgets
    └── features/                     # Feature modules
        ├── auth/                     # Login, Register, Reset Password
        ├── onboarding/               # First-time tutorial
        ├── home/                     # Map dashboard
        ├── reports/                  # Incident reporting wizard
        ├── advisories/               # Advisory management wizard
        ├── learning/                 # Quiz/lesson system
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

### Deploy Rules

```bash
firebase deploy --only firestore:rules
```

---

## Future Improvements

<details>
<summary><b>Planned Enhancements</b></summary>

| Priority | Feature | Notes |
|----------|---------|-------|
| 🔴 High | Move Algolia credentials to environment variables | Currently hardcoded in `config.dart` |
| 🔴 High | Add Firebase App Check | Protects API keys from unauthorized use |
| 🟡 Medium | Firebase Storage integration | Requires Blaze plan — enables photo uploads for reports |
| 🟡 Medium | Cloud Functions integration | Login tracking migrated; remaining functions pending Blaze |
| 🟡 Medium | End-to-end testing suite | Provider-based architecture primed for integration tests |
| 🟡 Medium | CI/CD pipeline | GitHub Actions for lint → test → build |
| 🟢 Low | Algolia search for users | Or replace with Firestore queries entirely |
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

- **Website:** [https://vcroad.app](https://vcroad.app)
- **Repository:** [https://github.com/yo-gerr/vcroad](https://github.com/yo-gerr/vcroad)
- **Issue Tracker:** [GitHub Issues](https://github.com/yo-gerr/vcroad/issues)

---

*Built with Flutter. Backend on Firebase Spark free tier. Maps powered by OpenStreetMap and contributors. Architecture restructured July 2026.*
