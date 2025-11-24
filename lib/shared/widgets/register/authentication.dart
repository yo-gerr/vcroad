import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/constants/password_policy.dart';
import 'package:vcroad_v2/shared/utils/input/input_style.dart';
import 'package:vcroad_v2/shared/utils/input/input_validation.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';

class Authentication extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final Map<String, TextEditingController> controllers;
  final Map<String, FocusNode> focusNodes;

  const Authentication({
    super.key,
    required this.formKey,
    required this.controllers,
    required this.focusNodes,
  });

  @override
  State<Authentication> createState() => _AuthenticationState();
}

class _AuthenticationState extends State<Authentication>
    with AutomaticKeepAliveClientMixin {
  final ValueNotifier<String> _passwordText = ValueNotifier('');
  final ValueNotifier<bool> _obscurePassword = ValueNotifier(true);
  final ValueNotifier<bool> _obscureConfirm = ValueNotifier(true);

  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _passwordController = widget.controllers['password']!;
    _passwordController.addListener(_updatePasswordText);
    _updatePasswordText();
  }

  void _updatePasswordText() {
    _passwordText.value = _passwordController.text;
  }

  @override
  void dispose() {
    _passwordController.removeListener(_updatePasswordText);
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
                Icons.lock_outline,
                size: responsive.scale(64),
                color: Theme.of(context).primaryColor,
              ),
              SizedBox(height: responsive.scale(16)),
              Text(
                'Set your password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: responsive.scaleFont(20),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: responsive.scale(8)),
              Text(
                'Create a secure password to protect your account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: responsive.scaleFont(14),
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: responsive.scale(24)),

              // Password
              InputStyles.fieldLabel('Password'),
              SizedBox(height: responsive.scale(4)),
              ValueListenableBuilder<bool>(
                valueListenable: _obscurePassword,
                builder: (_, obscure, __) {
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
                builder: (_, password, __) {
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
                builder: (_, obscure, __) {
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
                        validateConfirmPassword(val, _passwordText.value),
                    autovalidateMode: AutovalidateMode.onUnfocus,
                    onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
