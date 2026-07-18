import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vcroad/presentation/app/app_shell.dart';
import 'package:vcroad/presentation/features/onboarding/screens/onboarding_screen.dart';
import 'package:vcroad/presentation/features/auth/screens/register_screen.dart';
import 'package:vcroad/presentation/features/auth/screens/reset_password_screen.dart';
import 'package:vcroad/data/models/user.dart';
import 'package:vcroad/presentation/providers/advisory.dart';
import 'package:vcroad/presentation/providers/user.dart';
import 'package:vcroad/presentation/providers/account.dart';
import 'package:vcroad/presentation/providers/lesson.dart';
import 'package:vcroad/presentation/providers/learning.dart';
import 'package:vcroad/presentation/providers/report.dart';
import 'package:vcroad/presentation/providers/location.dart';
import 'package:vcroad/presentation/providers/theme.dart';
import 'package:vcroad/data/repositories/auth.dart';
import 'package:vcroad/data/repositories/session.dart';
import 'package:vcroad/core/theme/app_theme.dart';
import 'package:vcroad/core/utils/responsive/responsive_scope.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/presentation/app/splash_screen.dart';
import 'package:vcroad/presentation/features/auth/screens/login_screen.dart';
import 'package:url_strategy/url_strategy.dart';
import 'firebase_options.dart';

// One-time guard to ensure runApp is only executed once.
bool _appLaunched = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent accidental duplicate runApp (hot-restart / mis-invocations).
  if (_appLaunched) {
    debugPrint('[main] runApp already called — skipping duplicate invocation.');
    return;
  }

  // Safe global Flutter error handler: stringifies errors and suppresses the
  // known "EngineFlutterView disposed" render crash coming from diagnostics.
  FlutterError.onError = (FlutterErrorDetails details) {
    final safe = details.exceptionAsString();
    final lower = safe.toLowerCase();

    // If this is the disposed-engine symptom, log and suppress to avoid crash loop.
    if (lower.contains('engineflutterview') || lower.contains('disposed')) {
      debugPrint('[FlutterError] suppressed disposed view error: $safe');
      if (kDebugMode && details.stack != null) {
        debugPrint('[FlutterError] stack:\n${details.stack}');
      }
      return;
    }

    debugPrint('[FlutterError] $safe');
    if (details.stack != null) {
      debugPrint('[FlutterError] stack:\n${details.stack}');
    }
    if (kDebugMode) FlutterError.dumpErrorToConsole(details);
  };

  // Fallback for uncaught async errors (safe stringify)
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    try {
      debugPrint('[PlatformDispatcher.onError] ${error.toString()}');
      debugPrint('[PlatformDispatcher.onError] stack:\n${stack.toString()}');
    } catch (_) {
      debugPrint(
        '[PlatformDispatcher.onError] (error could not be stringified)',
      );
    }
    return true; // signal handled
  };

  // Initialize Firebase but don't let failure block the UI forever.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kIsWeb) {
      setPathUrlStrategy();
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }
  } catch (e, s) {
    debugPrint('[main] Firebase.initializeApp failed: $e\n$s');
    // Continue — services can handle missing firebase gracefully.
  }

  _appLaunched = true;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _sessionSubscription;
  late final GoRouter _router;

  // Rehydrate provider from FirebaseAuth + Firestore when needed (used by protected routes)
  Future<UserDetails?> _ensureUserHydrated(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.user != null) return userProvider.user;

    final auth = AuthService.instance;
    final fbUser = auth.currentUser;
    if (fbUser == null) return null;

    final uid = fbUser.uid;
    final details = await auth.getUserDetails(uid);
    if (details == null) return null;

    userProvider.setUser(details);

    // Ensure a session exists (reuse existing or create new)
    final sessionId = await SessionService.instance.ensureSession(uid);
    _startSessionMonitoring(uid, sessionId);

    // Commented out: prefetchDownloadUrls uses firebase_storage
    // unawaited(ImageService.prefetchDownloadUrls([details.selfiePath]));
    return details;
  }

  @override
  void initState() {
    super.initState();
    _router = _createRouter();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }

  void _startSessionMonitoring(String uid, String sessionId) {
    _sessionSubscription?.cancel();
    _sessionSubscription = SessionService.instance
        .watchSession(uid, sessionId)
        .listen((conflict) async {
          if (conflict != null && mounted) {
            // Clear session first while we still have write access
            try {
              await SessionService.instance.clearSession(uid);
            } catch (_) {
              // ignore; safe to proceed with signOut even if clear fails
            }
            await AuthService.instance.signOut();

            final ctx = _router.routerDelegate.navigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              Provider.of<UserProvider>(ctx, listen: false).clearUser();
              _router.go('/login');
              SnackbarUtils.showError(
                ctx,
                'You were logged out because another device signed in.',
              );
            }
          }
        });
  }

  void _stopSessionMonitoring() {
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
  }

  GoRouter _createRouter() {
    return GoRouter(
      initialLocation: '/',
      redirect: (BuildContext context, GoRouterState state) {
        final auth = AuthService.instance;
        final isSignedIn = auth.isSignedIn;
        final currentPath = state.uri.path;

        // If user is signed in and tries to access public routes, redirect to their role screen
        if (isSignedIn &&
            (currentPath == '/login' ||
                currentPath == '/register' ||
                currentPath == '/reset')) {
          // Get user from provider if available, else from AuthService
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          final user = userProvider.user;
          if (user != null) {
            switch (user.role) {
              case UserRole.user:
                return '/roaduser';
              case UserRole.admin:
                return '/barangayadmin';
              case UserRole.sysadmin:
                return '/superadmin';
            }
          }
          // Fallback: if signed in but no user details yet, allow navigation (will be handled by route builder)
          return null;
        }

        // If not signed in and tries to access protected routes, redirect to login
        if (!isSignedIn &&
            (currentPath == '/roaduser' ||
                currentPath == '/barangayadmin' ||
                currentPath == '/superadmin')) {
          return '/login';
        }

        // Role verification: redirect to the correct role-based route
        if (isSignedIn) {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          final user = userProvider.user;
          if (user != null) {
            final userRoute = switch (user.role) {
              UserRole.user => '/roaduser',
              UserRole.admin => '/barangayadmin',
              UserRole.sysadmin => '/superadmin',
            };
            final isOnRootOrAuthPage = currentPath == '/' ||
                currentPath == '/login' ||
                currentPath == '/register' ||
                currentPath == '/reset';
            if (!isOnRootOrAuthPage && currentPath != userRoute) {
              return userRoute;
            }
          }
        }

        // No redirect needed
        return null;
      },
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          name: 'splash',
          builder: (context, state) => SplashScreen(
            assetImagesToPrecache: const [
              'assets/images/vcroad.webp',
              'assets/images/slider_1.webp',
            ],
            onFinish: () async {
              final auth = AuthService.instance;
              if (auth.isSignedIn) {
                final user = auth.currentUser;
                if (user != null) {
                  final userDetails = await auth.getUserDetails(user.uid);
                  if (userDetails != null) {
                    if (context.mounted) {
                      Provider.of<UserProvider>(
                        context,
                        listen: false,
                      ).setUser(userDetails);

                      final sessionId = await SessionService.instance
                          .createSession(user.uid);

                      // Commented out: prefetchDownloadUrls uses firebase_storage
                      // await ImageService.prefetchDownloadUrls([
                      //   userDetails.selfiePath,
                      // ]);

                      _startSessionMonitoring(user.uid, sessionId);

                      switch (userDetails.role) {
                        case UserRole.user:
                          _router.goNamed('roaduser');
                          return;
                        case UserRole.admin:
                          _router.goNamed('barangayadmin');
                          return;
                        case UserRole.sysadmin:
                          _router.goNamed('superadmin');
                          return;
                      }
                    }
                  }
                  // Signed in but no users/ doc — check for pending registration
                  final pending =
                      await auth.getPendingRegistration(user.uid);
                  if (context.mounted) {
                    if (pending != null) {
                      _stopSessionMonitoring();
                      _router.goNamed(
                        'register',
                        queryParameters: {'uid': user.uid},
                      );
                      return;
                    }
                    // No pending doc either — orphaned Auth account; clean up
                    await auth.signOut();
                  }
                }
              }
              _stopSessionMonitoring();
              if (context.mounted) {
                _router.goNamed('login');
              }
            },
          ),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) {
            // Stop session monitoring when on login page
            _stopSessionMonitoring();
            return const Login();
          },
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const MyHomePage(title: 'Home'),
        ),
        GoRoute(
          path: '/register',
          name: 'register',
          builder: (context, state) {
            _stopSessionMonitoring();
            final resumeUid = state.uri.queryParameters['uid'];
            return Register(resumeUid: resumeUid);
          },
        ),
        GoRoute(
          path: '/reset',
          name: 'reset',
          builder: (context, state) {
            _stopSessionMonitoring();
            return const ResetPassword();
          },
        ),
        GoRoute(
          path: '/roaduser',
          name: 'roaduser',
          builder: (context, state) {
            final provider = Provider.of<UserProvider>(context, listen: false);
            if (provider.user != null) {
              return _RoadUserScreen(user: provider.user!);
            }
            return FutureBuilder<UserDetails?>(
              future: _ensureUserHydrated(context),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return SplashScreen(
                    assetImagesToPrecache: const ['assets/images/vcroad.webp'],
                    minDisplay: const Duration(milliseconds: 800),
                    onFinish: () {},
                    child: const SizedBox.shrink(),
                  );
                }
                final details = snap.data;
                if (details == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _router.go('/login');
                  });
                  return const SizedBox.shrink();
                }
                return _RoadUserScreen(user: details);
              },
            );
          },
        ),
        GoRoute(
          path: '/barangayadmin',
          name: 'barangayadmin',
          builder: (context, state) {
            final provider = Provider.of<UserProvider>(context, listen: false);
            if (provider.user != null) {
              return AppScreen(
                role: UserRole.admin,
                userDetails: provider.user,
              );
            }
            return FutureBuilder<UserDetails?>(
              future: _ensureUserHydrated(context),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return SplashScreen(
                    assetImagesToPrecache: const ['assets/images/vcroad.webp'],
                    minDisplay: const Duration(milliseconds: 800),
                    onFinish: () {},
                    child: const SizedBox.shrink(),
                  );
                }
                final details = snap.data;
                if (details == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _router.go('/login');
                  });
                  return const SizedBox.shrink();
                }
                return AppScreen(role: UserRole.admin, userDetails: details);
              },
            );
          },
        ),
        GoRoute(
          path: '/superadmin',
          name: 'superadmin',
          builder: (context, state) {
            final provider = Provider.of<UserProvider>(context, listen: false);
            if (provider.user != null) {
              return AppScreen(
                role: UserRole.sysadmin,
                userDetails: provider.user,
              );
            }
            return FutureBuilder<UserDetails?>(
              future: _ensureUserHydrated(context),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return SplashScreen(
                    assetImagesToPrecache: const ['assets/images/vcroad.webp'],
                    minDisplay: const Duration(milliseconds: 800),
                    onFinish: () {},
                    child: const SizedBox.shrink(),
                  );
                }
                final details = snap.data;
                if (details == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _router.go('/login');
                  });
                  return const SizedBox.shrink();
                }
                return AppScreen(role: UserRole.sysadmin, userDetails: details);
              },
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => AdvisoryProvider()),
        ChangeNotifierProvider(create: (_) => AccountProvider()),
        ChangeNotifierProvider(create: (_) => LessonProvider()),
        ChangeNotifierProvider(create: (_) => LearningProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) {
          final tp = ThemeProvider();
          tp.load();
          return tp;
        }),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'VCRoad',
            routerConfig: _router,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeProvider.themeMode,
            builder: (context, child) {
              // Start/stop monitoring when user state changes
              final user = context.select<UserProvider, UserDetails?>(
                (p) => p.user,
              );
              final sid = SessionService.instance.currentSessionId;

              if (user == null) {
                if (_sessionSubscription != null) _stopSessionMonitoring();
              } else if (_sessionSubscription == null && sid != null) {
                _startSessionMonitoring(user.userId, sid);
              }

              return ResponsiveBuilder(child: child ?? const SizedBox());
            },
          );
        },
      ),
    );
  }
}

/// Gated road-user screen that checks onboarding before showing the app.
class _RoadUserScreen extends StatefulWidget {
  final UserDetails user;
  const _RoadUserScreen({required this.user});

  @override
  State<_RoadUserScreen> createState() => _RoadUserScreenState();
}

class _RoadUserScreenState extends State<_RoadUserScreen> {
  bool? _needsOnboarding;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'hasSeenAppTutorial_${widget.user.userId}';
    final seen = prefs.getBool(key) ?? false;
    if (mounted) setState(() => _needsOnboarding = !seen);
  }

  @override
  Widget build(BuildContext context) {
    if (_needsOnboarding == null) {
      return SplashScreen(
        assetImagesToPrecache: const ['assets/images/vcroad.webp'],
        minDisplay: const Duration(milliseconds: 800),
        onFinish: () {},
        child: const SizedBox.shrink(),
      );
    }
    if (_needsOnboarding == true) {
      return OnboardingScreen(
        userId: widget.user.userId,
        onComplete: () => setState(() => _needsOnboarding = false),
      );
    }
    return AppScreen(role: UserRole.user, userDetails: widget.user);
  }
}

// Keep MyHomePage here or in its own file
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  void _incrementCounter() => setState(() => _counter++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
