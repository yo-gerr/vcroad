import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/services/auth.dart';
import 'package:vcroad_v2/shared/utils/input/input_validation.dart';
import 'package:vcroad_v2/shared/utils/input/input_style.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_scope.dart';
import 'package:vcroad_v2/shared/utils/snackbar/snackbar.dart'; // <-- Import SnackbarUtils

class ResetPassword extends StatefulWidget {
  const ResetPassword({super.key});

  @override
  State<ResetPassword> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _emailController.text.trim();
      await AuthService.instance.sendPasswordResetEmail(email);
      if (mounted) {
        SnackbarUtils.showSuccess(
          context,
          'A password reset link has been sent to your email.',
        );
        Navigator.of(context).pop();
      }
    } on Exception catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ResponsiveScope.of(context);

    // renamed to avoid leading underscore on a local identifier
    void back() => Navigator.of(context).maybePop();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF001278),
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
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: info.horizontalPadding,
            vertical: info.verticalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: info.maxFormWidth),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Responsive image above the text
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
                    'Enter your email address to receive a password reset link.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    // ensure entered text and cursor are white for dark header/background
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: InputStyles.decoration(
                      label: 'Email',
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
                      onPressed: _loading ? null : _resetPassword,
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
}
