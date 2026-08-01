import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/data/repositories/auth.dart';
import 'package:vcroad/core/utils/input/input_validation.dart';
import 'package:vcroad/core/utils/input/input_style.dart';
import 'package:vcroad/core/utils/responsive/responsive.dart';
import 'package:vcroad/core/utils/responsive/responsive_scope.dart';
import 'package:vcroad/presentation/shared/snackbar/snackbar.dart';

class ResetPassword extends StatefulWidget {
  const ResetPassword({super.key});

  @override
  State<ResetPassword> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword> {
  final AuthService _authService = AuthService.instance;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownSeconds = _authService.passwordResetCooldown();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds = _authService.passwordResetCooldown();
      });
      if (_cooldownSeconds <= 0) timer.cancel();
    });
  }

  Future<void> _sendResetLink() async {
    if (!_sent && !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _emailController.text.trim();
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() => _sent = true);
      _startCooldown();
    } on Exception catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError(context, _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'The email address is invalid. Please check and try again.';
        case 'too-many-requests':
          return 'Too many requests. Please wait a bit and try again.';
        case 'resend-throttled':
          return e.message ?? 'Please wait before requesting another reset link.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final info = ResponsiveScope.of(context);
    void back() => Navigator.of(context).maybePop();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Reset Password',
          style: TextStyle(color: Colors.white, fontSize: info.scaleFont(18)),
        ),
        leading: Semantics(
          label: 'Back',
          button: true,
          child: IconButton(
            onPressed: back,
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
      body: _sent ? _buildConfirmation(info) : _buildForm(info),
    );
  }

  Widget _buildForm(ResponsiveInfo info) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: info.horizontalPadding,
          vertical: info.verticalPadding,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: info.maxFormWidth),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/reset.webp',
                    width: info.logoSize,
                    height: info.logoSize,
                    fit: BoxFit.contain,
                    cacheWidth: info.cacheWidthForImage(
                      info.logoSize,
                      MediaQuery.of(context).devicePixelRatio,
                    ),
                    errorBuilder: (context, error, stack) => Icon(
                      Icons.lock_reset,
                      color: Colors.white,
                      size: info.logoSize,
                    ),
                    semanticLabel: 'Reset Password',
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Enter your email address and we\'ll send you a link to reset your password.',
                    style: TextStyle(fontSize: 16, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _sendResetLink(),
                    autofillHints: const [AutofillHints.email],
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: InputStyles.decoration(
                      label: 'Email',
                      helperText: 'If an account exists for this email, we\'ll send you a reset link.',
                      prefixIcon: const Icon(Icons.email, color: Colors.white),
                      contentPadding: InputStyles.responsiveContentPadding(
                        info,
                      ),
                    ),
                    validator: validateEmail,
                    enabled: !_loading,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _sendResetLink,
                      child: _loading
                          ? Semantics(
                              label: 'Sending reset link',
                              child: const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : const Text('Send Reset Link'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmation(ResponsiveInfo info) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: info.horizontalPadding,
          vertical: info.verticalPadding,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: info.maxFormWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mark_email_read_outlined,
                size: info.logoSize,
                color: AppColors.primary,
                semanticLabel: 'Check your email',
              ),
              const SizedBox(height: 24),
              Text(
                'Check your email',
                style: TextStyle(
                  fontSize: info.scaleFont(20),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'We\'ve sent a password reset link to ${_emailController.text.trim()}. '
                'Follow the link to choose a new password. Be sure to check your '
                'spam folder if you don\'t see it.',
                style: const TextStyle(fontSize: 16, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: (_cooldownSeconds > 0 || _loading)
                      ? null
                      : _sendResetLink,
                  child: _cooldownSeconds > 0
                      ? Text('Resend in ${_cooldownSeconds}s')
                      : const Text('Resend link'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Back'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
