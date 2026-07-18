import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vcroad/data/models/barangay.dart';
import 'package:vcroad/data/models/registration.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/presentation/features/auth/widgets/agreement.dart';
import 'package:vcroad/presentation/features/auth/widgets/personal.dart';
import 'package:vcroad/presentation/features/auth/widgets/credentials.dart';
import 'package:vcroad/presentation/features/auth/widgets/confirmation.dart';
import 'package:vcroad/presentation/features/auth/widgets/status.dart';
import 'package:vcroad/data/repositories/barangay.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';
import 'package:vcroad/data/repositories/auth.dart';
import 'package:vcroad/core/utils/exception/try_catch.dart';
import 'package:vcroad/presentation/shared/dialogs/something_went_wrong.dart';

class Register extends StatefulWidget {
  final String? resumeUid;
  const Register({super.key, this.resumeUid});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  static const Duration _pendingExpiry = Duration(hours: 24);

  final PageController _pageController = PageController();

  RegistrationStep _step = RegistrationStep.credentials;

  final GlobalKey<FormState> _credentialsKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _personalKey = GlobalKey<FormState>();

  late final Map<String, TextEditingController> _controllers;
  late final Map<String, FocusNode> _focusNodes;

  Barangay? _selectedBarangay;
  final BarangayService _barangayService = BarangayService();
  List<DropdownMenuItem<Barangay>> _barangayItems = [];

  final ValueNotifier<bool> _isSubmitting = ValueNotifier<bool>(false);
  String _emailVerificationStatus = 'pending';
  String? _tempUserId;
  StreamSubscription<bool>? _verificationSub;

  bool _agreed = false;
  bool _isResuming = false;

  @override
  void initState() {
    super.initState();

    _controllers = {
      'firstName': TextEditingController(),
      'middleName': TextEditingController(),
      'lastName': TextEditingController(),
      'suffix': TextEditingController(),
      'phoneNumber': TextEditingController(),
      'street': TextEditingController(),
      'houseNumber': TextEditingController(),
      'email': TextEditingController(),
      'password': TextEditingController(),
      'confirmPassword': TextEditingController(),
    };

    _focusNodes = {
      'firstName': FocusNode(),
      'middleName': FocusNode(),
      'lastName': FocusNode(),
      'suffix': FocusNode(),
      'phoneNumber': FocusNode(),
      'street': FocusNode(),
      'houseNumber': FocusNode(),
      'email': FocusNode(),
      'password': FocusNode(),
      'confirmPassword': FocusNode(),
    };

    _loadBarangays();

    if (widget.resumeUid != null) {
      _resumeRegistration(widget.resumeUid!);
    }
  }

  Future<void> _resumeRegistration(String uid) async {
    _isResuming = true;
    try {
      final pending = await AuthService.instance.getPendingRegistration(uid);
      if (!mounted) return;

      if (pending == null) {
        SnackbarUtils.showError(
          context,
          'Saved registration not found. Please start over.',
        );
        return;
      }

      final createdAt = (pending['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null &&
          DateTime.now().difference(createdAt) > _pendingExpiry) {
        await AuthService.instance.cancelPendingRegistration(uid);
        if (!mounted) return;
        SnackbarUtils.showInfo(
          context,
          'Your registration session expired. Please register again.',
        );
        return;
      }

      _tempUserId = uid;
      final email = pending['email'] as String? ?? '';
      _controllers['email']!.text = email;

      final verified = pending['emailVerified'] as bool? ?? false;

      setState(() {
        if (verified) {
          _step = RegistrationStep.personal;
          _emailVerificationStatus = 'verified';
        } else {
          _step = RegistrationStep.emailStatus;
          _emailVerificationStatus = 'pending';
        }
      });

      _pageController.jumpToPage(_stepIndex);

      if (!verified) {
        _verificationSub?.cancel();
        _verificationSub = await AuthService.instance
            .startEmailVerificationWatcher(
              onVerified: () {
                if (!mounted) return;
                setState(() => _emailVerificationStatus = 'verified');
                SnackbarUtils.showSuccess(
                  context,
                  'Email verified. Continue to complete your profile.',
                );
              },
            );
        if (!mounted) return;
        SnackbarUtils.showInfo(
          context,
          'Verify your email to continue registration.',
        );
      } else {
        SnackbarUtils.showInfo(
          context,
          'Email already verified. Complete your profile to finish.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError(
        context,
        'Could not resume registration: $e. Please start over.',
      );
    } finally {
      if (mounted) {
        setState(() => _isResuming = false);
      }
    }
  }

  Future<void> _loadBarangays() async {
    try {
      await _barangayService.loadBarangays();
      if (mounted) {
        setState(() {
          _barangayItems = _barangayService.barangayDropdownItems;
        });
      }
    } catch (e) {
      debugPrint('Failed to load barangays: $e');
      if (mounted) {
        SnackbarUtils.showError(
          context,
          'Failed to load barangays. Please restart the app.',
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _isSubmitting.dispose();
    _verificationSub?.cancel();
    AuthService.instance.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  RegistrationStep _nextStep(RegistrationStep current) {
    switch (current) {
      case RegistrationStep.credentials:
        return RegistrationStep.emailStatus;
      case RegistrationStep.emailStatus:
        return RegistrationStep.personal;
      case RegistrationStep.personal:
        return RegistrationStep.confirmation;
      case RegistrationStep.confirmation:
        return RegistrationStep.confirmation;
    }
  }

  int get _stepIndex => RegistrationStep.values.indexOf(_step);

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_isSubmitting.value) return;
    switch (_step) {
      case RegistrationStep.credentials:
        if (!(_credentialsKey.currentState?.validate() ?? false)) return;
        await _handleCreateAccount();
        break;
      case RegistrationStep.emailStatus:
        if (_emailVerificationStatus != 'verified') {
          SnackbarUtils.showInfo(context, 'Verify your email first.');
          return;
        }
        setState(() => _step = _nextStep(_step));
        break;
      case RegistrationStep.personal:
        if (!(_personalKey.currentState?.validate() ?? false)) return;
        if (!_agreed) {
          await showSomethingWentWrongDialog(
            context: context,
            message:
                'You need to read and agree to the Terms and Privacy Policy before continuing.',
            onRetry: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserAgreement()),
              );
            },
          );
          return;
        }
        await _handleCompleteRegistration();
        break;
      case RegistrationStep.confirmation:
        if (mounted) {
          GoRouter.of(context).goNamed('login');
        }
        break;
    }

    await _pageController.animateToPage(
      _stepIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleCreateAccount() async {
    final email = _controllers['email']!.text.trim().toLowerCase();
    final password = _controllers['password']!.text;
    if (email.isEmpty || password.isEmpty) return;

    _isSubmitting.value = true;

    await trycatch(
      context: context,
      dismissDialog: false,
      onRetry: () {
        if (!mounted) return;
        Navigator.of(context).pop();
        _handleCreateAccount();
      },
      task: () async {
        final uid = await AuthService.instance.createAccount(
          email: email,
          password: password,
        );
        _tempUserId = uid;

        _verificationSub?.cancel();
        _verificationSub = await AuthService.instance
            .startEmailVerificationWatcher(
              onVerified: () {
                if (!mounted) return;
                setState(() => _emailVerificationStatus = 'verified');
                SnackbarUtils.showSuccess(
                  context,
                  'Email verified. Continue to complete your profile.',
                );
              },
            );

        if (!mounted) return;

        setState(() {
          _step = _nextStep(_step);
          _emailVerificationStatus = 'pending';
        });

        SnackbarUtils.showSuccess(
          context,
          'Account created! Check your inbox to verify your email.',
        );
      },
    );

    if (!mounted) return;
    _isSubmitting.value = false;
  }

  Future<void> _handleCompleteRegistration() async {
    if (_tempUserId == null) return;
    _isSubmitting.value = true;
    try {
      final details = await AuthService.instance.completeRegistration(
        uid: _tempUserId!,
        formValues: _collectFormValues(),
        barangay: _selectedBarangay!,
      );

      debugPrint('Registration completed: ${details.userId}');

      if (!mounted) return;

      setState(() => _step = _nextStep(_step));
      await _pageController.animateToPage(
        _stepIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Registration error: $e');
      }
    } finally {
      if (mounted) {
        _isSubmitting.value = false;
      }
    }
  }

  Map<String, String?> _collectFormValues() {
    return {
      'firstName': _controllers['firstName']!.text,
      'middleName': _controllers['middleName']!.text,
      'lastName': _controllers['lastName']!.text,
      'suffix': _controllers['suffix']!.text,
      'phoneNumber': _controllers['phoneNumber']!.text,
      'street': _controllers['street']!.text,
      'houseNumber': _controllers['houseNumber']!.text,
    };
  }

  Future<void> _cancelRegistration() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Registration?'),
        content: const Text(
          'If you cancel, your account will be deleted and all progress lost. '
          'You can register again later with the same email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    _isSubmitting.value = true;
    try {
      if (_tempUserId != null) {
        await AuthService.instance.cancelPendingRegistration(_tempUserId!);
      } else {
        await AuthService.instance.signOut();
      }
    } catch (_) {
      await AuthService.instance.signOut();
    }
    if (!mounted) return;
    _isSubmitting.value = false;
    GoRouter.of(context).goNamed('login');
  }

  Future<void> _back() async {
    if (_step == RegistrationStep.credentials) {
      GoRouter.of(context).goNamed('login');
      return;
    }
    if (_step == RegistrationStep.emailStatus) {
      await _cancelRegistration();
      return;
    }
    final index = _stepIndex - 1;
    setState(() => _step = RegistrationStep.values[index]);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _onRefreshEmailStatus() async {
    _isSubmitting.value = true;
    try {
      final verified =
          await AuthService.instance.refreshAndCheckEmailVerified();

      if (!mounted) return;

      setState(() {
        _emailVerificationStatus = verified ? 'verified' : 'pending';
      });
      if (verified) {
        if (_tempUserId != null) {
          await AuthService.instance.handleEmailVerified(_tempUserId!);
        }
        if (!mounted) return;
        SnackbarUtils.showSuccess(context, 'Email verified.');
      } else {
        if (!mounted) return;
        SnackbarUtils.showInfo(context, 'Not verified yet.');
      }
    } catch (e) {
      SnackbarUtils.showError(context, 'Refresh error: $e');
    } finally {
      _isSubmitting.value = false;
    }
  }

  Future<void> _onResendEmail() async {
    if (_isSubmitting.value) return;
    _isSubmitting.value = true;
    try {
      await AuthService.instance.resendVerificationEmail();
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Verification email resent.');
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, e.message ?? 'Resend failed.');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Resend failed: $e');
      }
    } finally {
      if (mounted) {
        _isSubmitting.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final maxWidth = info.maxFormWidth;
    final stepCount = RegistrationStep.values.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Register',
          style: TextStyle(color: Colors.white, fontSize: info.scaleFont(18)),
        ),
        leading: Semantics(
          label: 'Back',
          button: true,
          child: IconButton(
            onPressed: _back,
            tooltip: 'Back',
            padding: EdgeInsets.all(info.scale(8)),
            iconSize: info.scale(32),
            icon: Image.asset(
              'assets/icons/return.webp',
              width: info.scale(24),
              height: info.scale(24),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: info.scale(24),
              ),
            ),
          ),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: EdgeInsets.symmetric(
                horizontal: info.horizontalPadding,
                vertical: info.scale(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Create account',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: info.scaleFont(20),
                    ),
                  ),
                  SizedBox(height: info.scale(6)),
                  Text(
                    _isResuming
                        ? 'Resuming your registration…'
                        : 'Create credentials, verify your email, then complete your profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: info.scaleFont(13),
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: info.scale(12)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(stepCount, (i) {
                      final active = i == _stepIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: EdgeInsets.symmetric(horizontal: info.scale(4)),
                        width: active ? info.scale(24) : info.scale(8),
                        height: info.scale(8),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(info.scale(8)),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: RepaintBoundary(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        CredentialsStep(
                          formKey: _credentialsKey,
                          controllers: _controllers,
                          focusNodes: _focusNodes,
                        ),
                        VerificationStatus(
                          email: _controllers['email']!.text,
                          status: _emailVerificationStatus,
                          onRefresh: _onRefreshEmailStatus,
                          onResendEmail: _onResendEmail,
                          isRefreshing: _isSubmitting.value,
                        ),
                        PersonalInfo(
                          formKey: _personalKey,
                          controllers: _controllers,
                          selectedBarangay: _selectedBarangay,
                          onBarangayChanged: (b) =>
                              setState(() => _selectedBarangay = b),
                          barangayItems: _barangayItems,
                          focusNodes: _focusNodes,
                          agreed: _agreed,
                          onAgreedChanged: (v) => setState(() => _agreed = v),
                        ),
                        const RegistrationConfirmation(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Container(
              width: double.infinity,
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: EdgeInsets.symmetric(
                horizontal: info.horizontalPadding,
                vertical: info.scale(12),
              ),
              child: ValueListenableBuilder<bool>(
                valueListenable: _isSubmitting,
                builder: (context, submitting, _) {
                  final isConfirmation = _step == RegistrationStep.confirmation;
                  final label = switch (_step) {
                    RegistrationStep.credentials =>
                        'Create Account & Send Verification',
                    RegistrationStep.emailStatus => 'Continue',
                    RegistrationStep.personal => 'Complete Registration',
                    RegistrationStep.confirmation => 'Go to Login',
                  };
                  return Row(
                    children: [
                      if (!isConfirmation)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: submitting ? null : _back,
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size.fromHeight(info.scale(48)),
                            ),
                            child: Text(
                              _step == RegistrationStep.credentials
                                  ? 'Cancel'
                                  : _step == RegistrationStep.emailStatus
                                      ? 'Cancel Registration'
                                      : 'Back',
                              style: TextStyle(fontSize: info.scaleFont(14)),
                            ),
                          ),
                        ),
                      if (!isConfirmation) SizedBox(width: info.scale(12)),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: submitting ? null : _next,
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size.fromHeight(info.scale(48)),
                          ),
                          child: submitting
                              ? SizedBox(
                                  width: info.scale(20),
                                  height: info.scale(20),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: info.scaleFont(14),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
