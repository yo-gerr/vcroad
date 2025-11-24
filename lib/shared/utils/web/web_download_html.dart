import 'dart:typed_data';
import 'dart:html' as html;

/// Open bytes in a new tab (web). If [autoDownload] is true the file will be
/// downloaded instead of opened in a new tab/window.
void openBytesInNewTab(
  Uint8List bytes,
  String filename, {
  bool autoDownload = false,
}) {
  // pick a sensible mime-type from filename
  String mime = 'application/octet-stream';
  final low = filename.toLowerCase();
  if (low.endsWith('.png')) {
    mime = 'image/png';
  } else if (low.endsWith('.jpg') || low.endsWith('.jpeg')) {
    mime = 'image/jpeg';
  } else if (low.endsWith('.webp')) {
    mime = 'image/webp';
  } else if (low.endsWith('.pdf')) {
    mime = 'application/pdf';
  }

  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);

  try {
    if (autoDownload) {
      final anchor = html.document.createElement('a') as html.AnchorElement;
      anchor.href = url;
      anchor.download = filename;
      // append to DOM for some browsers to allow programmatic click
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    } else {
      // Try opening in a new tab/window. This should display images when MIME is correct.
      // Use noopener to avoid granting access to the opener.
      html.window.open(url, '_blank', 'noopener');
    }
  } finally {
    // Revoke after short delay so browser has time to load the resource
    Future.delayed(const Duration(seconds: 5), () {
      try {
        html.Url.revokeObjectUrl(url);
      } catch (_) {}
    });
  }
}
