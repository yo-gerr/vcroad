import 'package:flutter/material.dart';
import 'package:vcroad/core/theme/app_colors.dart';
import 'package:vcroad/core/utils/responsive/responsive_build_context.dart';

class AgreementCheckbox extends StatefulWidget {
  final bool initialValue;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onViewAgreement;

  const AgreementCheckbox({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.onViewAgreement,
  });

  @override
  State<AgreementCheckbox> createState() => _AgreementCheckboxState();
}

class _AgreementCheckboxState extends State<AgreementCheckbox> {
  late bool agreed;

  @override
  void initState() {
    super.initState();
    agreed = widget.initialValue;
  }

  void _openAgreementScreen() {
    if (widget.onViewAgreement != null) {
      widget.onViewAgreement!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserAgreement()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Agreement checkbox',
      hint: 'Check to agree with Terms and Privacy Policy',
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outline,
            width: 1.25,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: agreed,
              onChanged: (v) {
                if (v == null) return;
                setState(() => agreed = v);
                widget.onChanged(v);
              },
            ),
            Expanded(
              child: GestureDetector(
                onTap: _openAgreementScreen,
                behavior: HitTestBehavior.translucent,
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    children: [
                      TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms and Privacy Policy',
                        style: TextStyle(
                          color: cs.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'View Agreement',
              onPressed: _openAgreementScreen,
              icon: Icon(Icons.info_outline, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class UserAgreement extends StatefulWidget {
  // When false the confirmation button at the bottom will be hidden.
  final bool showConfirmButton;
  const UserAgreement({super.key, this.showConfirmButton = true});

  @override
  State<UserAgreement> createState() => _UserAgreementState();
}

class _UserAgreementState extends State<UserAgreement> {
  bool _isEnglish = true;
  String? _enCache;
  String? _tlCache;
  bool _loading = true;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _preload();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _preload() async {
    try {
      final bundle = DefaultAssetBundle.of(context);
      final en = await bundle.loadString('assets/texts/agreement.txt');
      final tl = await bundle.loadString('assets/texts/kasunduan.txt');
      if (mounted) {
        setState(() {
          _enCache = en;
          _tlCache = tl;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleLanguage() => setState(() => _isEnglish = !_isEnglish);

  String? get _currentText => _isEnglish ? _enCache : _tlCache;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final responsive = context.responsive;
    final titleFontSize = responsive.scaleFont(18);
    final contentFontSize = responsive.isDesktop ? 18.0 : 14.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          _isEnglish ? 'User Agreement' : 'Kasunduan ng Gumagamit',
          style: TextStyle(
            color: Colors.white,
            fontSize: responsive.scaleFont(18),
          ),
        ),
        leading: Semantics(
          label: 'Back',
          button: true,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
            padding: EdgeInsets.all(responsive.scale(8)),
            iconSize: responsive.scale(32),
            icon: Image.asset(
              'assets/icons/return.webp',
              width: responsive.scale(24),
              height: responsive.scale(24),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: responsive.scale(24),
              ),
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: responsive.scale(8)),
            child: IconButton(
              onPressed: _toggleLanguage,
              tooltip: _isEnglish ? 'Switch to Tagalog' : 'Switch to English',
              icon: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.scale(12),
                  vertical: responsive.scale(6),
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  _isEnglish ? 'EN' : 'TL',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _currentText == null
          ? Center(
              child: Text(
                _isEnglish
                    ? 'Failed to load agreement.'
                    : 'Hindi ma-load ang kasunduan.',
                style: const TextStyle(color: Colors.red),
              ),
            )
          : Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.horizontalPadding,
                  vertical: responsive.verticalPadding,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: responsive.maxFormWidth,
                    ),
                    child: Container(
                      padding: EdgeInsets.all(responsive.horizontalPadding),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: cs.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              _isEnglish
                                  ? 'END-USER LICENSE AGREEMENT (EULA) FOR VCROAD'
                                  : 'KASUNDUAN SA LISENSYA NG END-USER (EULA) PARA SA VCROAD',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: titleFontSize.clamp(18, 28),
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 15),
                          SelectableText(
                            _currentText!,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: contentFontSize.clamp(12, 20),
                              height: 1.6,
                            ),
                            textAlign: TextAlign.justify,
                          ),
                          const SizedBox(height: 24),
                          if (widget.showConfirmButton)
                            Align(
                              alignment: Alignment.center,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline),
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.primary,
                                  foregroundColor: cs.onPrimary,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: responsive.scale(28),
                                    vertical: responsive.scale(14),
                                  ),
                                ),
                                label: Text(
                                  _isEnglish ? 'I Understand' : 'Nauunawaan Ko',
                                  style: TextStyle(
                                    fontSize: responsive.scaleFont(14),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
