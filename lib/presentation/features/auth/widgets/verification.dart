import 'package:flutter/material.dart';
import 'package:vcroad/core/utils/input/input_style.dart';
import 'package:vcroad/core/utils/input/input_validation.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class Verification extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final FocusNode emailFocusNode;
  final VoidCallback onSendVerification;
  final bool isSending;

  const Verification({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.emailFocusNode,
    required this.onSendVerification,
    this.isSending = false,
  });

  @override
  State<Verification> createState() => _VerificationState();
}

class _VerificationState extends State<Verification>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final responsive = context.responsive;

    return Form(
      key: widget.formKey,
      autovalidateMode: AutovalidateMode.onUnfocus,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: responsive.horizontalPadding,
          vertical: responsive.verticalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.email_outlined,
              size: responsive.scale(64),
              color: const Color(0xFF001278),
            ),
            SizedBox(height: responsive.scale(16)),
            Text(
              'Verify your email',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.scaleFont(20),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: responsive.scale(8)),
            Text(
              'Enter your email address. When you press Next below, we will send a verification link to that email. After clicking the link, return here to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.scaleFont(14),
                color: Colors.black54,
              ),
            ),
            SizedBox(height: responsive.scale(24)),
            InputStyles.fieldLabel('Email Address'),
            SizedBox(height: responsive.scale(4)),
            TextFormField(
              controller: widget.emailController,
              focusNode: widget.emailFocusNode,
              decoration: InputStyles.baseDecoration.copyWith(
                labelText: 'Email Address',
                prefixIcon: const Icon(
                  Icons.email,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              style: InputStyles.labelStyle,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              validator: validateEmail,
              enabled: !widget.isSending,
              onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
            ),
            SizedBox(height: responsive.scale(16)),
            Text(
              'Tip: Check your spam folder if you do not see the email within a minute.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.scaleFont(12),
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: responsive.scale(8)),
            Text(
              widget.isSending
                  ? 'Sending verification link...'
                  : 'Press Next below to send the verification link.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: responsive.scaleFont(12),
                color: widget.isSending ? Colors.blueGrey : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
