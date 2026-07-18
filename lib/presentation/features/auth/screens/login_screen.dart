import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vcroad/data/models/user.dart';
import 'package:vcroad/presentation/providers/user.dart';
import 'package:vcroad/data/repositories/auth.dart';
import 'package:vcroad/data/repositories/session.dart';
import 'package:vcroad/presentation/shared/dialogs/session_conflict.dart';
import 'package:vcroad/presentation/shared/dialogs/deletion.dart';
import 'package:vcroad/core/utils/exception/try_catch.dart';
import 'package:vcroad/presentation/features/auth/widgets/logo.dart';
import 'package:vcroad/presentation/features/auth/widgets/background.dart';
import 'package:vcroad/presentation/features/auth/widgets/login_form.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/core/utils/routing/role_router.dart';
import 'package:vcroad/presentation/shared/dialogs/loading.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final ValueNotifier<bool> _isPasswordVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoggingIn = ValueNotifier<bool>(false);

  final _authService = AuthService.instance;

  static const Color _bgColorA = Color(0xFF00247A);
  static const Color _bgColorB = Color(0xFF0033CC);

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
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _isPasswordVisible.dispose();
    _isLoggingIn.dispose();
    super.dispose();
  }

  Future<void> _loadAttemptState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _failedAttempts = prefs.getInt(_prefsKeyAttempts) ?? 0;
      final lockMillis = prefs.getInt(_prefsKeyLockout);

      if (lockMillis != null) {
        _lockoutUntil = DateTime.fromMillisecondsSinceEpoch(lockMillis);
        if (DateTime.now().isAfter(_lockoutUntil!)) {
          await _clearLockout();
        } else {
          _startLockoutTimer();
        }
      }

      if (mounted) setState(() {});
    } catch (_) {}
  }

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
    } catch (_) {}
  }

  Future<void> _incrementFailedAttempts() async {
    _failedAttempts++;
    if (_failedAttempts >= _maxAttempts) {
      _lockoutUntil = DateTime.now().add(_lockoutDuration);
      _failedAttempts = 0;
      _startLockoutTimer();
    }
    await _saveAttemptState();
    if (mounted) setState(() {});
  }

  Future<void> _clearLockout() async {
    _failedAttempts = 0;
    _lockoutUntil = null;
    _lockoutTimer?.cancel();
    _lockoutTimer = null;
    await _saveAttemptState();
    if (mounted) setState(() {});
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isLocked) {
        timer.cancel();
        _clearLockout();
      } else {
        if (mounted) setState(() {});
      }
    });
  }

  String _formatLockoutTime(Duration remaining) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  Future<void> _finalizeLoginAndNavigate(UserDetails userDetails) async {
    if (!mounted) return;
    Provider.of<UserProvider>(context, listen: false).setUser(userDetails);
    SnackbarUtils.showSuccess(
      context,
      'Welcome back, ${userDetails.firstName}!',
    );
    RoleRouter.navigate(context, userDetails.role, userDetails: userDetails);
  }

  Future<void> _onLogin() async {
    if (_isLocked) {
      final remaining = _remainingLockout;
      SnackbarUtils.showError(
        context,
        'Too many failed attempts. Try again in ${_formatLockoutTime(remaining)}.',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

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

          await _clearLockout();
          if (!mounted) return;

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
          final conflict = await SessionService.instance.checkActiveSession(
            userDetails.userId,
            proposedSessionId,
          );

          if (conflict != null && mounted) {
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
              await _authService.signOut();
            }
            return;
          }

          await SessionService.instance.setActiveSession(
            userDetails.userId,
            proposedSessionId,
          );
          await _finalizeLoginAndNavigate(userDetails);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-data-not-found') {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              final pending = await _authService.getPendingRegistration(uid);
              if (pending != null && mounted) {
                if (initialLoadingVisible && Navigator.canPop(context)) {
                  Navigator.of(context).pop();
                  initialLoadingVisible = false;
                }
                SnackbarUtils.showInfo(
                  context,
                  'Complete your registration to access your account.',
                );
                GoRouter.of(context).goNamed(
                  'register',
                  queryParameters: {'uid': uid},
                );
                return;
              }
            }
          }
          if (e.code == 'too-many-requests') {
            _lockoutUntil = DateTime.now().add(_lockoutDuration);
            _failedAttempts = 0;
            _startLockoutTimer();
            await _saveAttemptState();
            if (mounted && Navigator.canPop(context)) {
              if (initialLoadingVisible) Navigator.of(context).pop();
              initialLoadingVisible = false;
            }
            if (mounted) {
              SnackbarUtils.showError(
                context,
                e.message ?? 'Too many failed attempts. Please try again later.',
              );
            }
            return;
          }
          if (e.code == 'wrong-password' ||
              e.code == 'user-not-found' ||
              e.code == 'invalid-email' ||
              e.code == 'invalid-credential') {
            await _incrementFailedAttempts();
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

    if (initialLoadingVisible && mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const LoadingDialog(message: 'Cancelling deletion...'),
      );
      try {
        await _authService.cancelAccountDeletion(userDetails.userId);
        if (mounted) {
          Navigator.of(context).pop();
          SnackbarUtils.showSuccess(
            context,
            'Account deletion cancelled successfully.',
          );
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
      await _authService.signOut();
    }
  }

  void _proceedWithLogin(UserDetails userDetails) async {
    if (!mounted) return;
    Provider.of<UserProvider>(context, listen: false).setUser(userDetails);
    SnackbarUtils.showSuccess(
      context,
      'Welcome back, ${userDetails.firstName}!',
    );
    RoleRouter.navigate(context, userDetails.role, userDetails: userDetails);
  }

  void _onForgotPassword() {
    context.pushNamed('reset');
  }

  void _onRegister() {
    context.pushNamed('register');
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final isDesktop = info.isDesktop;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            Expanded(
              flex: 2,
              child: BackgroundGradient(
                color1: _bgColorA,
                color2: _bgColorB,
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Logo(size: 140),
                          const SizedBox(height: 24),
                          Text(
                            'VCRoad',
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Road incident reporting &\ntraffic advisory management',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: LoginForm(
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        emailFocusNode: _emailFocus,
                        passwordFocusNode: _passwordFocus,
                        isPasswordVisible: _isPasswordVisible,
                        isLoggingIn: _isLoggingIn,
                        onLogin: _onLogin,
                        onForgotPassword: _onForgotPassword,
                        onRegister: _onRegister,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            BackgroundGradient(
              color1: _bgColorA,
              color2: _bgColorB,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: info.scale(32),
                  horizontal: info.horizontalPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Logo(size: info.logoSize.clamp(72, 140)),
                    SizedBox(height: info.scale(12)),
                    Text(
                      'VCRoad',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: info.horizontalPadding,
                  vertical: info.scale(24),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: LoginForm(
                    formKey: _formKey,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    emailFocusNode: _emailFocus,
                    passwordFocusNode: _passwordFocus,
                    isPasswordVisible: _isPasswordVisible,
                    isLoggingIn: _isLoggingIn,
                    onLogin: _onLogin,
                    onForgotPassword: _onForgotPassword,
                    onRegister: _onRegister,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
