import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';
import 'package:vcroad/presentation/shared/dialogs/loading.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const SupportScreen());

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const String formEndpoint = 'https://formspree.io/f/yourFormId';

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtl = TextEditingController();
  final TextEditingController _emailCtl = TextEditingController();
  final TextEditingController _subjectCtl = TextEditingController();
  final TextEditingController _msgCtl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _subjectCtl.dispose();
    _msgCtl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    // show modal loading dialog (non-dismissible) while sending
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingDialog(message: 'Sending message...'),
    );
    try {
      final body = {
        'name': _nameCtl.text.trim(),
        'email': _emailCtl.text.trim(),
        'subject': _subjectCtl.text.trim(),
        'message': _msgCtl.text.trim(),
      };

      final resp = await http.post(
        Uri.parse(formEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent — thank you!')),
        );
        _formKey.currentState!.reset();
        _nameCtl.clear();
        _emailCtl.clear();
        _subjectCtl.clear();
        _msgCtl.clear();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Send failed (${resp.statusCode}). Please try again.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Please try again.')),
        );
      }
    } finally {
      // close loading dialog if still open and restore submitting state
      try {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).maybePop();
        }
      } catch (_) {}
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter your email';
    final email = v.trim();
    final re = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$");
    return re.hasMatch(email) ? null : 'Invalid email';
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final horizontal = info.horizontalPadding;
    final isWide = info.isDesktop;
    // match FAQ hero sizing for consistency (larger on desktop, smaller on mobile)
    final heroSize = isWide ? info.scale(160) : info.scale(120);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF001278),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Contact Us',
          style: TextStyle(fontSize: info.scaleFont(18), color: Colors.white),
        ),
        leading: IconButton(
          iconSize: info.scale(28),
          padding: EdgeInsets.all(info.scale(8)),
          icon: Image.asset(
            'assets/icons/return.webp',
            width: info.scale(24),
            height: info.scale(24),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWide ? 920 : 720),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontal,
                vertical: info.verticalPadding,
              ),
              children: [
                SizedBox(height: info.scale(8)),
                Center(
                  child: Column(
                    children: [
                      // hero icon
                      Container(
                        width: heroSize,
                        height: heroSize,
                        decoration: const BoxDecoration(
                          shape: BoxShape.rectangle,
                        ),
                        child: Image.asset(
                          'assets/images/reset.webp',
                          fit: BoxFit.contain,
                          height: heroSize,
                          cacheWidth: context.cacheWidthForImage(
                            isWide ? 640 : 360,
                          ),
                          errorBuilder: (_, _, _) => Icon(
                            Icons.support_agent,
                            size: heroSize,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      SizedBox(height: info.scale(12)),
                      Text(
                        "Have questions or suggestions? We'd love to hear from you",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: info.scaleFont(16),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: info.scale(12)),
                    ],
                  ),
                ),

                // form card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(info.scale(12)),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Name
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Name',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          SizedBox(height: info.scale(8)),
                          TextFormField(
                            controller: _nameCtl,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              hintText: 'Your name',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: info.scale(12),
                                vertical: info.scale(14),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: const Color(0xFF001278),
                                ),
                              ),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Please enter your name'
                                : null,
                          ),
                          SizedBox(height: info.scale(12)),
                          // Email
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Email',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          SizedBox(height: info.scale(8)),
                          TextFormField(
                            controller: _emailCtl,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              hintText: 'your.email@example.com',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: info.scale(12),
                                vertical: info.scale(14),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: const Color(0xFF001278),
                                ),
                              ),
                            ),
                            validator: _validateEmail,
                          ),
                          SizedBox(height: info.scale(12)),
                          // Subject
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Subject',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          SizedBox(height: info.scale(8)),
                          TextFormField(
                            controller: _subjectCtl,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              hintText: "What's this about?",
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: info.scale(12),
                                vertical: info.scale(14),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: const Color(0xFF001278),
                                ),
                              ),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Please enter a subject'
                                : null,
                          ),
                          SizedBox(height: info.scale(12)),
                          // Message
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Message',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          SizedBox(height: info.scale(8)),
                          TextFormField(
                            controller: _msgCtl,
                            keyboardType: TextInputType.multiline,
                            maxLines: 6,
                            minLines: 4,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              hintText: 'Tell us more...',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: info.scale(12),
                                vertical: info.scale(14),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: const Color(0xFF001278),
                                ),
                              ),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Please enter a message'
                                : null,
                          ),
                          SizedBox(height: info.scale(16)),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: info.scale(12)),

                // send button full width at bottom
                SizedBox(
                  width: double.infinity,
                  height: info.scale(52),
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _send,
                    icon: _submitting
                        ? const SizedBox.shrink()
                        : const Icon(Icons.send, color: Colors.white),
                    label: Text(
                      _submitting ? 'Sending…' : 'Send Message',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF001278),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: TextStyle(
                        fontSize: info.scaleFont(15),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: info.scale(16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
