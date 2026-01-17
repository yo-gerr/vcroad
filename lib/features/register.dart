import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vcroad_v2/shared/models/barangay.dart';
import 'package:vcroad_v2/shared/models/registration.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/widgets/register/agreement.dart';
import 'package:vcroad_v2/shared/widgets/register/personal.dart';
import 'package:vcroad_v2/shared/widgets/register/id_capture.dart';
import 'package:vcroad_v2/shared/widgets/register/authentication.dart';
import 'package:vcroad_v2/shared/widgets/register/confirmation.dart';
import 'package:vcroad_v2/shared/widgets/register/status.dart';
import 'package:vcroad_v2/shared/widgets/register/verification.dart';
import 'package:vcroad_v2/shared/services/barangay.dart';
import 'package:vcroad_v2/shared/utils/snackbar/snackbar.dart';
import 'package:vcroad_v2/shared/services/auth.dart';
import 'package:vcroad_v2/shared/utils/exception/try_catch.dart';
import 'package:vcroad_v2/shared/utils/dialog/something_went_wrong.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final PageController _pageController = PageController();

  RegistrationStep _step = RegistrationStep.personal;

  // Form keys for each registration step
  final GlobalKey<FormState> _personalKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _emailKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _authKey = GlobalKey<FormState>();

  // Controllers and focus nodes for form fields
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, FocusNode> _focusNodes;

  // Stores images for ID and selfie verification
  final Map<String, dynamic> _images = {'id': null, 'selfie': null};

  // Barangay selection and dropdown items
  Barangay? _selectedBarangay;
  final BarangayService _barangayService = BarangayService();
  List<DropdownMenuItem<Barangay>> _barangayItems = [];

  // Submission and verification state
  final ValueNotifier<bool> _isSubmitting = ValueNotifier<bool>(false);
  String _emailVerificationStatus = 'pending'; // pending | verified | expired
  String? _tempUserId; // Firestore doc ID for pending registration
  StreamSubscription<bool>? _verificationSub;

  // Tracks user agreement to terms and privacy policy
  bool _agreed = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers and focus nodes for all form fields
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
  }

  /// Loads barangay data and populates dropdown items.
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

  /// Returns the next registration step based on the current step.
  RegistrationStep _nextStep(RegistrationStep current) {
    switch (current) {
      case RegistrationStep.personal:
        return RegistrationStep.idCapture;
      case RegistrationStep.idCapture:
        return RegistrationStep.emailInput;
      case RegistrationStep.emailInput:
        return RegistrationStep.emailStatus;
      case RegistrationStep.emailStatus:
        return RegistrationStep.password;
      case RegistrationStep.password:
        return RegistrationStep.confirmation;
      case RegistrationStep.confirmation:
        return RegistrationStep.confirmation;
    }
  }

  /// Returns the index of the current registration step.
  int get _stepIndex => RegistrationStep.values.indexOf(_step);

  /// Advances to the next registration step, validating input and handling logic for each step.
  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_isSubmitting.value) return;
    switch (_step) {
      case RegistrationStep.personal:
        if (!(_personalKey.currentState?.validate() ?? false)) return;
        // Prevent progression if user has not agreed to terms
        if (!_agreed) {
          await showSomethingWentWrongDialog(
            context: context,
            message:
                'You need to read and agree to the Terms and Privacy Policy before continuing.',
            onRetry: () {
              Navigator.of(context).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const UserAgreement()));
            },
          );
          return;
        }
        setState(() => _step = _nextStep(_step));
        break;
      case RegistrationStep.idCapture:
        // Require both ID and selfie images before continuing
        if (_images['id'] == null || _images['selfie'] == null) {
          SnackbarUtils.showError(context, 'Please capture ID and selfie.');
          return;
        }
        setState(() => _step = _nextStep(_step));
        break;
      case RegistrationStep.emailInput:
        // Validate email input and send verification
        if (!(_emailKey.currentState?.validate() ?? false)) return;
        await _handleSendVerification();
        break;
      case RegistrationStep.emailStatus:
        // Require email verification before continuing
        if (_emailVerificationStatus != 'verified') {
          SnackbarUtils.showInfo(context, 'Verify your email first.');
          return;
        }
        setState(() => _step = _nextStep(_step));
        break;
      case RegistrationStep.password:
        // Validate password and create account
        if (!(_authKey.currentState?.validate() ?? false)) return;
        await _handleCreateAccount();
        break;
      case RegistrationStep.confirmation:
        // Registration complete, navigate to login
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

  /// Handles sending the email verification link and starts verification watcher.
  Future<void> _handleSendVerification() async {
    final email = _controllers['email']!.text.trim().toLowerCase();
    if (email.isEmpty) return;
    if (_isSubmitting.value) return;

    _isSubmitting.value = true;

    await trycatch(
      context: context,
      dismissDialog: false,
      onRetry: () {
        if (!mounted) return;
        Navigator.of(context).pop();
        _handleSendVerification();
      },
      task: () async {
        final uid = await AuthService.instance.handleSendVerification(
          images: _images,
          formValues: _collectFormValues(),
          barangay: _selectedBarangay,
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
                  'Email verified. Continue to set password.',
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
          'Verification email sent. Check inbox and spam folder.',
        );
      },
    );

    if (!mounted) return;

    _isSubmitting.value = false;
  }

  /// Handles account creation after password is set and all steps are complete.
  Future<void> _handleCreateAccount() async {
    _isSubmitting.value = true;
    try {
      final email = _controllers['email']!.text;
      final password = _controllers['password']!.text;

      final details = await AuthService.instance.finalizeAccount(
        email: email,
        newPassword: password,
        formValues: _collectFormValues(),
        barangay: _selectedBarangay!,
      );

      debugPrint('User finalized: ${details.userId}');

      if (!mounted) return;

      setState(() => _step = _nextStep(_step));
      await _pageController.animateToPage(
        _stepIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      if (!mounted) return;
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Account error: $e');
      }
    } finally {
      if (mounted) {
        _isSubmitting.value = false;
      }
    }
  }

  /// Collects all form values into a map for submission.
  Map<String, String?> _collectFormValues() {
    return {
      'firstName': _controllers['firstName']!.text,
      'middleName': _controllers['middleName']!.text,
      'lastName': _controllers['lastName']!.text,
      'suffix': _controllers['suffix']!.text,
      'phoneNumber': _controllers['phoneNumber']!.text,
      'street': _controllers['street']!.text,
      'houseNumber': _controllers['houseNumber']!.text,
      'email': _controllers['email']!.text,
    };
  }

  /// Handles navigation to the previous registration step.
  void _back() {
    if (_step == RegistrationStep.personal) {
      GoRouter.of(context).goNamed('login');
      return;
    }
    if (_step == RegistrationStep.emailStatus) {
      SnackbarUtils.showInfo(context, 'Please finish email verification.');
      return;
    }
    final index = _stepIndex - 1;
    setState(() => _step = RegistrationStep.values[index]);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  /// Updates the images map when ID or selfie images are changed.
  void _onImagesChanged(Map<String, dynamic> images) {
    setState(() {
      _images
        ..clear()
        ..addAll(images);
    });
  }

  /// Refreshes the email verification status.
  Future<void> _onRefreshEmailStatus() async {
    _isSubmitting.value = true;
    try {
      final verified = await AuthService.instance
          .refreshAndCheckEmailVerified();

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

  /// Resends the email verification link, with throttling and error feedback.
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
        backgroundColor: const Color(0xFF001278),
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
            // Header section with step indicator
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
                    'Fill your details, verify your email, and set a password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: info.scaleFont(13),
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: info.scale(12)),
                  // Step indicator
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
                              ? const Color(0xFF001278)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(info.scale(8)),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            // PageView for registration steps
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: RepaintBoundary(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
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
                        IdCapture(images: _images, onChanged: _onImagesChanged),
                        Verification(
                          formKey: _emailKey,
                          emailController: _controllers['email']!,
                          emailFocusNode: _focusNodes['email']!,
                          onSendVerification: _next,
                          isSending: _isSubmitting.value,
                        ),
                        VerificationStatus(
                          email: _controllers['email']!.text,
                          status: _emailVerificationStatus,
                          onRefresh: _onRefreshEmailStatus,
                          onResendEmail: _onResendEmail,
                          isRefreshing: _isSubmitting.value,
                        ),
                        Authentication(
                          formKey: _authKey,
                          controllers: _controllers,
                          focusNodes: _focusNodes,
                        ),
                        const RegistrationConfirmation(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Footer with navigation buttons
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
                    RegistrationStep.personal => 'Next',
                    RegistrationStep.idCapture => 'Continue',
                    RegistrationStep.emailInput => 'Send Link & Continue',
                    RegistrationStep.emailStatus => 'Continue',
                    RegistrationStep.password => 'Create Account',
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
                              _step == RegistrationStep.personal
                                  ? 'Cancel'
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
