import 'package:flutter/material.dart';
import 'package:vcroad/core/constants/password_policy.dart';
import 'package:vcroad/core/utils/debouncer/debouncer.dart';
import 'package:vcroad/core/utils/input/input_style.dart';
import 'package:vcroad/core/utils/input/input_validation.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/data/repositories/auth.dart';
import 'package:vcroad/presentation/features/auth/widgets/agreement.dart';

class CredentialsStep extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final Map<String, TextEditingController> controllers;
  final Map<String, FocusNode> focusNodes;

  const CredentialsStep({
    super.key,
    required this.formKey,
    required this.controllers,
    required this.focusNodes,
  });

  @override
  State<CredentialsStep> createState() => _CredentialsStepState();
}

class _CredentialsStepState extends State<CredentialsStep>
    with AutomaticKeepAliveClientMixin {
  final ValueNotifier<String> _passwordText = ValueNotifier('');
  final ValueNotifier<bool> _obscurePassword = ValueNotifier(true);
  final ValueNotifier<bool> _obscureConfirm = ValueNotifier(true);
  final ValueNotifier<String?> _emailError = ValueNotifier(null);
  final ValueNotifier<bool> _checkingEmail = ValueNotifier(false);

  late final TextEditingController _passwordController;
  late final TextEditingController _emailController;
  late final Debouncer _emailDebouncer;

  @override
  void initState() {
    super.initState();
    _passwordController = widget.controllers['password']!;
    _emailController = widget.controllers['email']!;
    _emailDebouncer = Debouncer(const Duration(milliseconds: 500));

    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(_updatePasswordText);
  }

  void _updatePasswordText() {
    _passwordText.value = _passwordController.text;
  }

  void _onEmailChanged() {
    final email = _emailController.text.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$')
        .hasMatch(email)) {
      _emailError.value = null;
      return;
    }
    _checkingEmail.value = true;
    _emailDebouncer.call(() async {
      try {
        final inUse = await AuthService.instance.isEmailInUse(email);
        _emailError.value = inUse ? 'This email is already registered' : null;
      } catch (_) {
        _emailError.value = null;
      } finally {
        _checkingEmail.value = false;
      }
    });
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _passwordController.removeListener(_updatePasswordText);
    _emailDebouncer.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final responsive = context.responsive;
    final baseDecoration = InputStyles.baseDecoration;

    return AutofillGroup(
      child: Form(
        key: widget.formKey,
        autovalidateMode: AutovalidateMode.onUnfocus,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: responsive.horizontalPadding,
            vertical: responsive.verticalPadding * 0.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.person_add_outlined,
                size: responsive.scale(64),
                color: Theme.of(context).primaryColor,
              ),
              SizedBox(height: responsive.scale(16)),
              Text(
                'Create your account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: responsive.scaleFont(20),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: responsive.scale(8)),
              Text(
                'Enter your email and create a secure password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: responsive.scaleFont(14),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: responsive.scale(24)),

              // Email
              InputStyles.fieldLabel('Email Address'),
              SizedBox(height: responsive.scale(4)),
              ValueListenableBuilder<bool>(
                valueListenable: _checkingEmail,
                builder: (_, checking, _) {
                  return ValueListenableBuilder<String?>(
                    valueListenable: _emailError,
                    builder: (_, error, _) {
                      return TextFormField(
                        controller: _emailController,
                        focusNode: widget.focusNodes['email'],
                        decoration: baseDecoration.copyWith(
                          labelText: 'Email Address',
                          prefixIcon: const Icon(
                            Icons.email,
                            size: 20,
                            color: Colors.white,
                          ),
                          suffixIcon: checking
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                          errorText: error,
                        ),
                        style: InputStyles.labelStyle,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: (val) {
                          final result = validateEmail(val);
                          if (result != null) return result;
                          if (_emailError.value != null) {
                            return _emailError.value;
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) =>
                            widget.focusNodes['password']?.requestFocus(),
                      );
                    },
                  );
                },
              ),
              SizedBox(height: responsive.scale(16)),

              // Password
              InputStyles.fieldLabel('Password'),
              SizedBox(height: responsive.scale(4)),
              ValueListenableBuilder<bool>(
                valueListenable: _obscurePassword,
                builder: (_, obscure, _) {
                  final decoration = baseDecoration.copyWith(
                    labelText: 'Password',
                    prefixIcon: const Icon(
                      Icons.lock,
                      size: 20,
                      color: Colors.white,
                    ),
                    suffixIcon: Semantics(
                      label: obscure ? 'Show password' : 'Hide password',
                      button: true,
                      child: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => _obscurePassword.value = !obscure,
                        tooltip: obscure ? 'Show password' : 'Hide password',
                        splashRadius: 22,
                      ),
                    ),
                  );
                  return TextFormField(
                    controller: _passwordController,
                    focusNode: widget.focusNodes['password'],
                    decoration: decoration,
                    style: InputStyles.labelStyle,
                    obscureText: obscure,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: PasswordPolicy.validate,
                    autovalidateMode: AutovalidateMode.onUnfocus,
                    onFieldSubmitted: (_) =>
                        widget.focusNodes['confirmPassword']?.requestFocus(),
                  );
                },
              ),
              SizedBox(height: responsive.scale(12)),

              // Password rules
              ValueListenableBuilder<String>(
                valueListenable: _passwordText,
                builder: (_, password, _) {
                  final rules = PasswordPolicy.getRules(password);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: rules.map((rule) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: responsive.scale(4)),
                        child: Row(
                          children: [
                            Icon(
                              rule.isValid ? Icons.check_circle : Icons.cancel,
                              color: rule.isValid ? Colors.green : Colors.red,
                              size: responsive.scale(18),
                            ),
                            SizedBox(width: responsive.scale(6)),
                            Expanded(
                              child: Text(
                                rule.label,
                                style: TextStyle(
                                  fontSize: responsive.scaleFont(13),
                                  color: rule.isValid
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              SizedBox(height: responsive.scale(16)),

              // Confirm Password
              InputStyles.fieldLabel('Confirm Password'),
              SizedBox(height: responsive.scale(4)),
              ValueListenableBuilder<bool>(
                valueListenable: _obscureConfirm,
                builder: (_, obscure, _) {
                  return TextFormField(
                    controller: widget.controllers['confirmPassword'],
                    focusNode: widget.focusNodes['confirmPassword'],
                    decoration: baseDecoration.copyWith(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        size: 20,
                        color: Colors.white,
                      ),
                      suffixIcon: Semantics(
                        label: obscure
                            ? 'Show confirm password'
                            : 'Hide confirm password',
                        button: true,
                        child: IconButton(
                          icon: Icon(
                            obscure ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => _obscureConfirm.value = !obscure,
                          tooltip: obscure
                              ? 'Show confirm password'
                              : 'Hide confirm password',
                          splashRadius: 22,
                        ),
                      ),
                    ),
                    style: InputStyles.labelStyle,
                    obscureText: obscure,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (val) =>
                        validateConfirmPassword(val, _passwordController.text),
                    autovalidateMode: AutovalidateMode.onUnfocus,
                    onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                  );
                },
              ),
              SizedBox(height: responsive.scale(24)),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserAgreement(showConfirmButton: false),
                  ),
                ),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: responsive.scaleFont(12),
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    children: [
                      const TextSpan(text: 'By creating an account, you agree to our '),
                      TextSpan(
                        text: 'Terms and Privacy Policy',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
