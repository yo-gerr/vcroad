import 'dart:typed_data';

/// Non-web stub. Calling this on native will throw — callers should use the
/// native file approach (generateAdvisoryImage returning File).
void openBytesInNewTab(
  Uint8List bytes,
  String filename, {
  bool autoDownload = false,
}) {
  throw UnsupportedError('openBytesInNewTab is only supported on web.');
}
