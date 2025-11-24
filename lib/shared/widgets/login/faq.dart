import 'package:flutter/material.dart';
import 'package:vcroad_v2/shared/utils/responsive/responsive_build_context.dart';
import 'package:vcroad_v2/shared/widgets/login/support.dart';

class FAQ extends StatefulWidget {
  const FAQ({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const FAQ());
  @override
  State<FAQ> createState() => _FAQState();
}

class _FAQState extends State<FAQ> {
  final List<bool> _open = [];

  final List<_FaqItem> _items = const [
    _FaqItem(
      question: 'How do I download and install VCRoad?',
      answer:
          'Download the APK file from our website and enable installation from unknown sources in your Android settings. After that, open the APK file to install the app.',
    ),
    _FaqItem(
      question: 'How do I report an incident?',
      answer:
          'Open the Report screen from the bottom navigation, choose a category, attach a photo/video, and submit. Your report will be visible to admins and other users after moderation.',
    ),
    _FaqItem(
      question: 'Is my location shared with other users?',
      answer:
          'Your live location is used only locally for navigation and map centering. Reports you submit may include a location for other users to see, but your private account details are not shared publicly.',
    ),
    _FaqItem(
      question: 'How are reports verified?',
      answer:
          'Reports are moderated by administrators. Verification may require additional review, supporting media, or community moderation before a report is marked verified or resolved.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _open.addAll(List<bool>.filled(_items.length, false));
  }

  @override
  Widget build(BuildContext context) {
    final info = context.responsive;
    final horizontal = info.horizontalPadding;
    final titleFont = info.scaleFont(20);
    final subtitleGap = info.scale(12);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF001278),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          'FAQ',
          style: TextStyle(color: Colors.white, fontSize: info.scaleFont(18)),
        ),
        leading: Semantics(
          label: 'Back',
          button: true,
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
            padding: EdgeInsets.all(info.scale(8)),
            iconSize: info.scale(32),
            icon: Image.asset(
              'assets/icons/return.webp',
              width: info.scale(24),
              height: info.scale(24),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: info.scale(24),
              ),
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontal,
            vertical: info.verticalPadding,
          ),
          children: [
            // hero image (reduced size for better layout & performance)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/reset.webp',
                  fit: BoxFit.contain,
                  // keep image compact: taller on desktop, smaller on mobile
                  height: info.isDesktop ? info.scale(160) : info.scale(120),
                  // reduce cache width to match displayed size (improves memory on web/retina)
                  cacheWidth: context.cacheWidthForImage(
                    info.isDesktop ? 640 : 360,
                  ),
                  semanticLabel: 'FAQ illustration',
                ),
              ),
            ),
            SizedBox(height: subtitleGap),
            // heading
            Text(
              'Frequently Asked Questions',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleFont,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: info.scale(18)),
            // FAQ list
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(info.scale(8)),
                child: Column(
                  children: List.generate(_items.length, (i) {
                    final item = _items[i];
                    return _buildTile(context, item, i);
                  }),
                ),
              ),
            ),
            SizedBox(height: info.scale(24)),
            // small footer with direct action to Support
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Can\'t find an answer?',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: info.scaleFont(13),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: info.scale(8)),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).push(SupportScreen.route()),
                    icon: Icon(
                      Icons.support_agent,
                      size: info.scale(16),
                      color: const Color(0xFF001278),
                    ),
                    label: Text(
                      'Contact Support',
                      style: TextStyle(
                        color: const Color(0xFF001278),
                        fontSize: info.scaleFont(13),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: info.scale(12),
                        vertical: info.scale(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, _FaqItem item, int index) {
    final info = context.responsive;
    return Column(
      children: [
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey('faq_$index'),
            initiallyExpanded: _open[index],
            tilePadding: EdgeInsets.symmetric(
              horizontal: info.scale(12),
              vertical: info.scale(6),
            ),
            childrenPadding: EdgeInsets.symmetric(
              horizontal: info.scale(16),
              vertical: info.scale(12),
            ),
            title: Text(
              item.question,
              style: TextStyle(
                fontSize: info.scaleFont(14),
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Icon(
              _open[index] ? Icons.expand_less : Icons.expand_more,
            ),
            onExpansionChanged: (v) {
              setState(() => _open[index] = v);
            },
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item.answer,
                  style: TextStyle(
                    fontSize: info.scaleFont(13),
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (index != _items.length - 1)
          Divider(height: 1, color: Colors.grey.shade200),
      ],
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});
}
