import 'dart:html' as html;

/// Hides fullscreen / camera controls injected by Google Maps JS.
/// Run after the map is created (small delay to allow controls to render).
void hideMapControlsWeb() {
  try {
    // small delay to let the map DOM render (call via Future.delayed)
    Future.delayed(const Duration(milliseconds: 250), () {
      // search for known control containers and buttons
      final candidates = html.document.querySelectorAll(
        '.gm-style .gm-control-active, .gm-style .gm-fullscreen-control, button[aria-label], button[title]',
      );

      for (final el in candidates) {
        final title =
            (el.getAttribute('aria-label') ?? el.getAttribute('title') ?? '')
                .toLowerCase();
        final classes = el.classes;
        // hide elements that look like fullscreen/camera controls
        if (title.contains('full') ||
            title.contains('fullscreen') ||
            classes.contains('gm-fullscreen-control') ||
            classes.contains('gm-control-active')) {
          el.style.display = 'none';
        }
      }

      // Extra: ensure any button with tooltip "Toggle fullscreen" is hidden
      final toggle = html.document.querySelectorAll(
        'button[title*="full"], button[aria-label*="full"]',
      );
      for (final t in toggle) t.style.display = 'none';
    });
  } catch (_) {
    // fail silently on unexpected DOM structure
  }
}
