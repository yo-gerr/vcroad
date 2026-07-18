import 'package:flutter/material.dart';
import 'package:vcroad/core/utils/input/input_style.dart';
import 'package:vcroad/core/utils/input/input_validation.dart';
import 'package:vcroad/presentation/features/auth/widgets/logo.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocusNode;
  final FocusNode passwordFocusNode;
  final ValueNotifier<bool> isPasswordVisible;
  final ValueNotifier<bool> isLoggingIn;
  final Future<void> Function() onLogin;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onRegister;
  final bool showLogo;
  final double logoSize;
  final double horizontalPadding;
  final double verticalPadding;

  const LoginForm({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.emailFocusNode,
    required this.passwordFocusNode,
    required this.isPasswordVisible,
    required this.isLoggingIn,
    required this.onLogin,
    this.onForgotPassword,
    this.onRegister,
    this.showLogo = false,
    this.logoSize = 80,
    this.horizontalPadding = 16,
    this.verticalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final horizontal = (horizontalPadding / 2).clamp(12.0, r.horizontalPadding);
    final vertical = (verticalPadding / 2).clamp(8.0, r.verticalPadding);

    final EdgeInsets contentPadding = EdgeInsets.symmetric(
      horizontal: horizontal,
      vertical: vertical,
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: contentPadding,
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showLogo)
                  Padding(
                    padding: EdgeInsets.all(horizontal),
                    child: Logo(size: logoSize),
                  ),
                SizedBox(height: vertical),
                Text(
                  'Welcome Back',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF001278),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: verticalPadding * 2),
                TextFormField(
                  controller: emailController,
                  focusNode: emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      InputStyles.decoration(
                        label: 'Email',
                        hint: 'Enter your email',
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Colors.white,
                        ),
                      ).copyWith(
                        labelStyle: const TextStyle(color: Colors.white),
                        hintStyle: const TextStyle(color: Colors.white70),
                      ),
                  validator: validateEmail,
                  onFieldSubmitted: (_) => passwordFocusNode.requestFocus(),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: isPasswordVisible,
                  builder: (context, visible, _) {
                    return TextFormField(
                      controller: passwordController,
                      focusNode: passwordFocusNode,
                      obscureText: !visible,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: Colors.white),
                      decoration:
                          InputStyles.decoration(
                            label: 'Password',
                            hint: 'Enter your password',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: Colors.white,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                visible
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                isPasswordVisible.value = !visible;
                              },
                            ),
                          ).copyWith(
                            labelStyle: const TextStyle(color: Colors.white),
                            hintStyle: const TextStyle(color: Colors.white70),
                          ),
                      validator: (value) =>
                          validatePassword(value, minLength: 8),
                      onFieldSubmitted: (_) => onLogin(),
                    );
                  },
                ),
                // Forgot Password
                if (onForgotPassword != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onForgotPassword,
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: verticalPadding),
                ValueListenableBuilder<bool>(
                  valueListenable: isLoggingIn,
                  builder: (context, loading, _) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: loading ? null : onLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF001278),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(double.infinity, 56),
                        ),
                        child: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    );
                  },
                ),
                // Register Link
                if (onRegister != null) ...[
                  SizedBox(height: verticalPadding),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account? ',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      TextButton(
                        onPressed: onRegister,
                        child: Text(
                          'Register',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
