import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vcroad_v2/app/app.dart';
import 'package:vcroad_v2/features/register.dart';
import 'package:vcroad_v2/features/reset.dart';
import 'package:vcroad_v2/shared/models/user.dart';
import 'package:vcroad_v2/shared/providers/advisory.dart';
import 'package:vcroad_v2/shared/providers/user.dart';
import 'package:vcroad_v2/shared/providers/account.dart';
import 'package:vcroad_v2/shared/providers/lesson.dart';
import 'package:vcroad_v2/shared/providers/learning.dart';
import 'package:vcroad_v2/shared/providers/report.dart';
import 'package:vcroad_v2/shared/providers/location.dart'; // <--- add
import 'package:vcroad_v2/shared/services/auth.dart';
import 'package:vcroad_v2/shared/services/image.dart';
import 'package:vcroad_v2/shared/services/session.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_scope.dart';
import 'package:vcroad_v2/shared/utils/snackbar/snackbar.dart';
import 'package:vcroad_v2/app/splash.dart';
import 'package:vcroad_v2/features/login.dart';
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

    // Read session from Firestore
    final sessionSnap = await FirebaseFirestore.instance
        .doc('sessions/$uid')
        .get();
    final firestoreSessionId =
        sessionSnap.data()?['activeSessionId'] as String?;

    if (firestoreSessionId != null) {
      SessionService.instance.currentSessionId = firestoreSessionId;
      _startSessionMonitoring(uid, firestoreSessionId);
    } else {
      // No session exists, create one
      final newSid = await SessionService.instance.createSession(uid);
      _startSessionMonitoring(uid, newSid);
    }

    // Prefetch avatar URL in background (non-blocking)
    unawaited(ImageService.prefetchDownloadUrls([details.selfiePath]));
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

                      // Start session monitoring
                      final sessionId = await SessionService.instance
                          .createSession(user.uid);

                      // Prefetch avatar URL before navigation (no UI stall).
                      await ImageService.prefetchDownloadUrls([
                        userDetails.selfiePath,
                      ]);

                      _startSessionMonitoring(user.uid, sessionId);

                      // Route based on role — DO NOT pass complex extra object
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
                }
              }
              // If not signed in, stop monitoring and go to login
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
            return const Register();
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
              return AppScreen(role: UserRole.user, userDetails: provider.user);
            }
            return FutureBuilder<UserDetails?>(
              future: _ensureUserHydrated(context),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  // Use your custom splash loading here
                  return SplashScreen(
                    assetImagesToPrecache: const ['assets/images/vcroad.webp'],
                    minDisplay: const Duration(milliseconds: 800),
                    onFinish: () {}, // No navigation, just loading
                    child: const SizedBox.shrink(), // fallback if lottie fails
                  );
                }
                final details = snap.data;
                if (details == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _router.go('/login');
                  });
                  return const SizedBox.shrink();
                }
                return AppScreen(role: UserRole.user, userDetails: details);
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
      ],
      child: MaterialApp.router(
        title: 'VCRoad',
        routerConfig: _router,
        theme: ThemeData(
          fontFamily: 'Poppins',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF001278)),
          visualDensity: VisualDensity.adaptivePlatformDensity,
          textTheme: Typography.material2018().black.apply(
            fontFamily: 'Poppins',
          ),
          primaryTextTheme: Typography.material2018().black.apply(
            fontFamily: 'Poppins',
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF001278),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFBDBDBD), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF001278), width: 2),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              textStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              textStyle: const TextStyle(fontFamily: 'Poppins'),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              textStyle: const TextStyle(fontFamily: 'Poppins'),
            ),
          ),
          appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
        ),
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
      ),
    );
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
