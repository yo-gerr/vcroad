import 'package:flutter/material.dart';

class DownloadButton extends StatelessWidget {
  final ValueNotifier<bool> isHovered;
  final VoidCallback onTap;

  const DownloadButton({
    super.key,
    required this.isHovered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isNarrow = mq.size.width < 420;
    final isWide = mq.size.width > 600;
    final fontSize = isNarrow ? 15.0 : 17.0;
    final iconSize = isNarrow ? 18.0 : 20.0;
    final horizontalPadding = isWide ? 12.0 : (isNarrow ? 8.0 : 10.0);
    final verticalPadding = isWide ? 10.0 : 12.0;

    Widget buttonContent = Row(
      mainAxisSize: isWide ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.download_rounded, size: iconSize),
        const SizedBox(width: 6),
        Text(
          'Download APK',
          style: TextStyle(fontSize: fontSize),
          maxLines: 1,
          softWrap: false,
        ),
      ],
    );

    return ValueListenableBuilder<bool>(
      valueListenable: isHovered,
      child: buttonContent,
      builder: (context, hovered, child) {
        Widget animatedButton = AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          constraints: BoxConstraints(
            minHeight: 44,
            minWidth: isWide ? 0 : double.infinity,
            // On wide: shrink to content, on mobile: expand to fill
            maxWidth: isWide ? 220 : double.infinity,
          ),
          decoration: BoxDecoration(
            color: hovered ? const Color(0xFF0033CC) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: hovered
                    ? Colors.blue.withAlpha((0.4 * 255).round())
                    : Colors.black26,
                blurRadius: hovered ? 12 : 6,
                offset: Offset(0, hovered ? 8 : 4),
              ),
            ],
            border: Border.all(
              color: hovered ? const Color(0xFF001276) : Colors.black,
              width: 3,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style:
                    (Theme.of(context).textTheme.labelLarge ??
                            const TextStyle())
                        .copyWith(
                          fontFamily: 'Poppins',
                          color: hovered
                              ? Colors.white
                              : const Color(0xFF001276),
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          shadows: hovered
                              ? [
                                  const Shadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                child: child!,
              ),
            ),
          ),
        );

        // On mobile/tablet: expand to fill parent width
        if (!isWide) {
          return SizedBox(width: double.infinity, child: animatedButton);
        }
        // On wide layout: shrink to content
        return animatedButton;
      },
    );
  }
}
