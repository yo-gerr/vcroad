import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vcroad_v2/shared/models/user.dart';
import 'package:vcroad_v2/shared/providers/user.dart';
import 'package:vcroad_v2/shared/services/auth.dart';
import 'package:vcroad_v2/shared/services/image.dart';
import 'package:vcroad_v2/shared/services/session.dart';
import 'package:vcroad_v2/shared/utils/dialog/session_conflict.dart';
import 'package:vcroad_v2/shared/utils/dialog/deletion.dart';
import 'package:vcroad_v2/shared/utils/exception/try_catch.dart';
import 'package:vcroad_v2/shared/widgets/login/footer.dart';
import 'package:vcroad_v2/shared/widgets/login/logo.dart';
import 'package:vcroad_v2/shared/widgets/login/background.dart';
import 'package:vcroad_v2/shared/widgets/login/download.dart';
import 'package:vcroad_v2/shared/widgets/login/login_form.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/utils/image/image_slider.dart';
import 'package:vcroad_v2/shared/utils/snackbar/snackbar.dart';
import 'package:vcroad_v2/shared/utils/routing/role_router.dart';
import 'package:vcroad_v2/shared/utils/dialog/loading.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with SingleTickerProviderStateMixin {
  final ValueNotifier<bool> _downloadHover = ValueNotifier<bool>(false);

  // Form state
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final ValueNotifier<bool> _isPasswordVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoggingIn = ValueNotifier<bool>(false);

  // Auth service
  final _authService = AuthService.instance;

  static const List<String> _posterImages = [
    'assets/images/slider_1.webp',
    'assets/images/slider_2.webp',
    'assets/images/slider_3.webp',
    'assets/images/slider_4.webp',
  ];

  static const Color _bgColorA = Color(0xFF00247A);
  static const Color _bgColorB = Color(0xFF0033CC);

  // Login attempt tracking
  static const String _prefsKeyAttempts = 'login_failed_attempts';
  static const String _prefsKeyLockout = 'login_lockout_until';
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 15);

  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;

  bool get _isLocked =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  Duration get _remainingLockout {
    if (_lockoutUntil == null) return Duration.zero;
    final remaining = _lockoutUntil!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  void initState() {
    super.initState();
    _loadAttemptState();

    // Precache poster images for smoother slider transitions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mq = MediaQuery.of(context);
      final logicalWidth = (mq.size.shortestSide * 0.5).clamp(300.0, 1200.0);
      for (final p in _posterImages.skip(1)) {
        precacheImage(
          AssetImage(p),
          context,
          size: Size(logicalWidth, logicalWidth / (16 / 9)),
          onError: (_, __) {},
        );
      }
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _downloadHover.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _isPasswordVisible.dispose();
    _isLoggingIn.dispose();
    super.dispose();
  }

  /// Loads login attempt and lockout state from shared preferences.
  Future<void> _loadAttemptState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _failedAttempts = prefs.getInt(_prefsKeyAttempts) ?? 0;
      final lockMillis = prefs.getInt(_prefsKeyLockout);

      if (lockMillis != null) {
        _lockoutUntil = DateTime.fromMillisecondsSinceEpoch(lockMillis);

        // Clear expired lockout
        if (DateTime.now().isAfter(_lockoutUntil!)) {
          await _clearLockout();
        } else {
          _startLockoutTimer();
        }
      }

      if (mounted) setState(() {});
    } catch (_) {
      // Ignore errors loading state
    }
  }

  /// Saves current login attempt and lockout state to shared preferences.
  Future<void> _saveAttemptState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeyAttempts, _failedAttempts);

      if (_lockoutUntil != null) {
        await prefs.setInt(
          _prefsKeyLockout,
          _lockoutUntil!.millisecondsSinceEpoch,
        );
      } else {
        await prefs.remove(_prefsKeyLockout);
      }
    } catch (_) {
      // Ignore errors saving state
    }
  }

  /// Increments failed login attempts and applies lockout if threshold reached.
  Future<void> _incrementFailedAttempts() async {
    _failedAttempts++;

    if (_failedAttempts >= _maxAttempts) {
      _lockoutUntil = DateTime.now().add(_lockoutDuration);
      _failedAttempts = 0; // Reset counter for next cycle
      _startLockoutTimer();
    }

    await _saveAttemptState();
    if (mounted) setState(() {});
  }

  /// Clears lockout and failed attempt state.
  Future<void> _clearLockout() async {
    _failedAttempts = 0;
    _lockoutUntil = null;
    _lockoutTimer?.cancel();
    _lockoutTimer = null;
    await _saveAttemptState();
    if (mounted) setState(() {});
  }

  /// Starts a timer to update UI during lockout period.
  void _startLockoutTimer() {
    _lockoutTimer?.cancel();

    // Update UI every second during lockout
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isLocked) {
        timer.cancel();
        _clearLockout();
      } else {
        if (mounted) setState(() {});
      }
    });
  }

  /// Formats remaining lockout time as a string.
  String _formatLockoutTime(Duration remaining) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  /// Finalizes login by prefetching user assets, applying claims, updating provider, and navigating.
  Future<void> _finalizeLoginAndNavigate(UserDetails userDetails) async {
    try {
      await ImageService.prefetchDownloadUrls([userDetails.selfiePath]);
    } catch (_) {}
    try {
      await AuthService.instance.applyUserRoleClaim();
    } catch (_) {}
    if (!mounted) return;
    Provider.of<UserProvider>(context, listen: false).setUser(userDetails);
    SnackbarUtils.showSuccess(
      context,
      'Welcome back, ${userDetails.firstName}!',
    );
    RoleRouter.navigate(context, userDetails.role, userDetails: userDetails);
  }

  /// Handles the login flow, including validation, lockout, session conflict, and error handling.
  Future<void> _onLogin() async {
    // Check if locked
    if (_isLocked) {
      final remaining = _remainingLockout;
      SnackbarUtils.showError(
        context,
        'Too many failed attempts. Try again in ${_formatLockoutTime(remaining)}.',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // Show initial loading dialog
    bool initialLoadingVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingDialog(message: 'Signing in...'),
    );

    await trycatch(
      context: context,
      task: () async {
        try {
          final userDetails = await _authService.login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

          // Success: clear attempts
          await _clearLockout();

          if (!mounted) return;

          // Handle pending account deletion flow
          final scheduledDeletion = await _authService.checkPendingDeletion(
            userDetails.userId,
          );
          if (scheduledDeletion != null && mounted) {
            if (initialLoadingVisible && Navigator.canPop(context)) {
              Navigator.of(context).pop();
              initialLoadingVisible = false;
            }
            await _handlePendingDeletion(scheduledDeletion, userDetails);
            return;
          }

          final proposedSessionId = SessionService.instance.newSessionId();

          // Check for active session on server
          final conflict = await SessionService.instance.checkActiveSession(
            userDetails.userId,
            proposedSessionId,
          );

          if (conflict != null && mounted) {
            // Handle session conflict dialog
            if (initialLoadingVisible && Navigator.canPop(context)) {
              Navigator.of(context).pop();
              initialLoadingVisible = false;
            }
            final shouldForceLogout = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => SessionConflictDialog(
                deviceInfo: conflict['deviceInfo'] ?? 'Unknown Device',
                startedAt: conflict['startedAt'],
                onForceLogout: () => Navigator.of(context).pop(true),
                onCancel: () => Navigator.of(context).pop(false),
              ),
            );

            if (shouldForceLogout == true && mounted) {
              // Force logout other device and finalize login
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const LoadingDialog(message: 'Logging out other device...'),
              );
              try {
                await SessionService.instance.setActiveSession(
                  userDetails.userId,
                  proposedSessionId,
                );
                await _finalizeLoginAndNavigate(userDetails);
              } finally {
                if (mounted && Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                }
              }
            } else {
              // User canceled: sign out local auth and return to login UI
              await _authService.signOut();
            }
            return;
          }

          // No conflict: finalize login
          await SessionService.instance.setActiveSession(
            userDetails.userId,
            proposedSessionId,
          );
          await _finalizeLoginAndNavigate(userDetails);
        } on FirebaseAuthException catch (e) {
          // Increment attempts only for credential errors
          if (e.code == 'wrong-password' ||
              e.code == 'user-not-found' ||
              e.code == 'invalid-email' ||
              e.code == 'invalid-credential') {
            await _incrementFailedAttempts();

            // Show remaining attempts warning
            if (_failedAttempts > 0 && _failedAttempts < _maxAttempts) {
              final remaining = _maxAttempts - _failedAttempts;
              if (mounted && Navigator.canPop(context)) {
                if (initialLoadingVisible) {
                  Navigator.of(context).pop();
                  initialLoadingVisible = false;
                }
              }
              if (mounted) {
                SnackbarUtils.showError(
                  context,
                  'Invalid credentials. $remaining attempt${remaining == 1 ? '' : 's'} remaining.',
                );
              }
              return;
            }
          }
          rethrow;
        }
      },
      onRetry: _onLogin,
    );

    // Ensure initial loading dialog is closed if still open
    if (initialLoadingVisible && mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  /// Handles pending account deletion dialog and actions.
  Future<void> _handlePendingDeletion(
    DateTime scheduledDate,
    UserDetails userDetails,
  ) async {
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PendingDeletionDialog(
        scheduledForDeletionAt: scheduledDate,
        onCancelDeletion: () => Navigator.of(context).pop('cancel'),
        onDismiss: () => Navigator.of(context).pop('dismiss'),
      ),
    );

    if (!mounted) return;

    if (action == 'cancel') {
      // Cancel deletion
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const LoadingDialog(message: 'Cancelling deletion...'),
      );
      try {
        await _authService.cancelAccountDeletion(userDetails.userId);
        if (mounted) {
          Navigator.of(context).pop();
          SnackbarUtils.showSuccess(
            context,
            'Account deletion cancelled successfully.',
          );
          // Proceed with normal login
          final proposedSessionId = SessionService.instance.newSessionId();
          await SessionService.instance.setActiveSession(
            userDetails.userId,
            proposedSessionId,
          );
          _proceedWithLogin(userDetails);
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
          SnackbarUtils.showError(context, 'Failed to cancel deletion: $e');
          await _authService.signOut();
        }
      }
    } else {
      // Dismiss - sign out
      await _authService.signOut();
    }
  }

  /// Continues login flow after deletion cancellation by prefetching assets and navigating.
  void _proceedWithLogin(UserDetails userDetails) async {
    await ImageService.prefetchDownloadUrls([userDetails.selfiePath]);
    await AuthService.instance.applyUserRoleClaim();

    if (!mounted) return;

    Provider.of<UserProvider>(context, listen: false).setUser(userDetails);
    SnackbarUtils.showSuccess(
      context,
      'Welcome back, ${userDetails.firstName}!',
    );
    RoleRouter.navigate(context, userDetails.role, userDetails: userDetails);
  }

  /// Navigates to the password reset screen.
  void _onForgotPassword() {
    context.pushNamed('reset');
  }

  /// Navigates to the registration screen.
  void _onRegister() {
    context.pushNamed('register');
  }

  /// Handles download button tap, launching APK download or showing info.
  void _onDownload() {
    const apkAssetPath = 'assets/assets/downloads/vcroad.apk';
    // Download only supported on web (button is shown only on web). For other
    // platforms we provide a friendly message.
    if (kIsWeb) {
      final url = '/$apkAssetPath';
      launchUrlString(url, mode: LaunchMode.externalApplication)
          .then((ok) {
            if (ok) {
              SnackbarUtils.showInfo(context, 'Download started');
            } else {
              SnackbarUtils.showError(
                context,
                'Could not start download. Try opening $url manually.',
              );
            }
          })
          .catchError((e) {
            SnackbarUtils.showError(context, 'Download failed: $e');
          });
      return;
    }

    // Non-web fallback
    SnackbarUtils.showInfo(
      context,
      'Download is available from the web version. Please visit the website to download the APK.',
    );
  }

  /// Shows the login modal sheet or dialog depending on platform.
  Future<void> _showLoginModal(BuildContext context, bool isDesktop) async {
    if (!isDesktop) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, controller) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: SingleChildScrollView(
                  controller: controller,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 12,
                      bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                    ),
                    child: LoginForm(
                      formKey: _formKey,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      emailFocusNode: _emailFocus,
                      passwordFocusNode: _passwordFocus,
                      isPasswordVisible: _isPasswordVisible,
                      isLoggingIn: _isLoggingIn,
                      onLogin: () async {
                        await _onLogin();

                        if (!ctx.mounted) return;

                        if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                      },
                      onForgotPassword: () {
                        Navigator.of(ctx).pop();
                        _onForgotPassword();
                      },
                      onRegister: () {
                        Navigator.of(ctx).pop();
                        _onRegister();
                      },
                      showLogo: true,
                      logoSize: 72,
                      horizontalPadding: 8,
                      verticalPadding: 8,
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 48,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: LoginForm(
                  formKey: _formKey,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  emailFocusNode: _emailFocus,
                  passwordFocusNode: _passwordFocus,
                  isPasswordVisible: _isPasswordVisible,
                  isLoggingIn: _isLoggingIn,
                  onLogin: () async {
                    await _onLogin();

                    if (!ctx.mounted) return;

                    if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                  },
                  onForgotPassword: () {
                    Navigator.of(ctx).pop();
                    _onForgotPassword();
                  },
                  onRegister: () {
                    Navigator.of(ctx).pop();
                    _onRegister();
                  },
                  showLogo: true,
                  logoSize: 84,
                  horizontalPadding: 12,
                  verticalPadding: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the profile button for login, positioned and styled per platform.
  Widget _buildProfileButton(BuildContext context, bool isDesktop) {
    final mq = MediaQuery.of(context);
    final topOffset = mq.padding.top + 8;
    final rightOffset = isDesktop ? 28.0 : 12.0;
    final double iconSize = isDesktop ? 48.0 : 44.0;
    final double splashRadius = (iconSize * 0.9).clamp(20.0, 28.0);
    final Color iconColor = isDesktop ? const Color(0xFF001276) : Colors.white;

    return Positioned(
      top: topOffset,
      right: rightOffset,
      child: SafeArea(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Tooltip(
            message: 'Sign In',
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: iconSize,
                splashRadius: splashRadius,
                padding: const EdgeInsets.all(4.0),
                icon: Icon(
                  Icons.account_circle,
                  size: iconSize,
                  color: iconColor,
                  semanticLabel: 'Sign In',
                ),
                onPressed: () => _showLoginModal(context, isDesktop),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final isDesktop = info.isDesktop;
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final screenH = mq.size.height;
    final topPad = mq.padding.top;
    final bottomPad = mq.padding.bottom;

    final double cardVerticalGutter = 32.0 * 2 + 24.0;
    final double availableHeight = math.max(
      200.0,
      screenH - topPad - bottomPad - cardVerticalGutter,
    );

    // Desktop / wide layout: two panels
    if (isDesktop) {
      // limit card height so it remains visually balanced
      final double cardHeight = math.min(availableHeight, screenH * 0.88);

      return Stack(
        children: [
          Scaffold(
            body: Row(
              children: [
                // Left gradient panel with large logo + download
                Expanded(
                  flex: 1,
                  child: BackgroundGradient(
                    // pass static colors instead of animations
                    color1: _bgColorA,
                    color2: _bgColorB,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Center the logo + download vertically while keeping footer pinned
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    RepaintBoundary(
                                      child: Logo(
                                        size: (screenW * 0.22).clamp(
                                          180.0,
                                          420.0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    if (kIsWeb)
                                      ValueListenableBuilder<bool>(
                                        valueListenable: _downloadHover,
                                        builder: (context, hovered, _) {
                                          return DownloadButton(
                                            isHovered: _downloadHover,
                                            onTap: _onDownload,
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Footer pinned to the bottom of the SafeArea
                            const Footer(
                              padding: EdgeInsets.only(bottom: 18.0),
                              textColor: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Right content panel with poster slider (only)
                Expanded(
                  flex: 1,
                  child: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: SizedBox(
                              // make the card fit into available height so slider doesn't force scrolling
                              height: cardHeight,
                              child: ImageSlider(
                                images: _posterImages,
                                assets: true,
                                autoPlay: true,
                                autoPlayInterval: const Duration(seconds: 5),
                                autoPlayAnimationDuration: const Duration(
                                  milliseconds: 800,
                                ),
                                showIndicators: true,
                                enableInfiniteScroll: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildProfileButton(context, isDesktop),
        ],
      );
    }

    // Mobile / tablet layout: stacked
    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Hero: logo + download (intrinsic height)
                SizedBox(
                  width: double.infinity,
                  child: BackgroundGradient(
                    color1: _bgColorA,
                    color2: _bgColorB,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: info.scale(28.0),
                        horizontal: info.horizontalPadding,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // intrinsic height
                        children: [
                          RepaintBoundary(
                            child: Logo(size: info.logoSize.clamp(88.0, 200.0)),
                          ),
                          SizedBox(height: info.scale(14.0)),
                          // Show download button only on web (desktop browser). Keep layout compact on native.
                          if (kIsWeb)
                            DownloadButton(
                              isHovered: _downloadHover,
                              onTap: _onDownload,
                            )
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ),
                ),

                // Slider: take remaining space, responsive card styling
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: info.horizontalPadding,
                      vertical: 12,
                    ),
                    child: Card(
                      elevation: info.isDesktop ? 8 : 2, // lighter on mobile
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Center(
                        child: RepaintBoundary(
                          child: ImageSlider(
                            images: _posterImages,
                            assets: true,
                            // let the slider fill the card; disable autoplay on mobile for performance
                            autoPlay: !info.isMobile,
                            autoPlayInterval: const Duration(seconds: 5),
                            autoPlayAnimationDuration: const Duration(
                              milliseconds: 700,
                            ),
                            showIndicators: true,
                            enableInfiniteScroll: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Contact pinned to bottom inside SafeArea
                Padding(
                  padding: EdgeInsets.only(
                    left: info.horizontalPadding,
                    right: info.horizontalPadding,
                    bottom: math.max(
                      12.0,
                      MediaQuery.of(context).padding.bottom,
                    ),
                    top: 8,
                  ),
                  child: const Footer(textColor: Colors.black),
                ),
              ],
            ),
          ),
        ),

        // profile button (same implementation — consider adding subtle background on mobile)
        _buildProfileButton(context, isDesktop),
      ],
    );
  }
}
