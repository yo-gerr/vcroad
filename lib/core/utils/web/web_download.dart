// Conditional export: use HTML implementation on web, stub elsewhere.
export 'web_download_stub.dart' if (dart.library.html) 'web_download_html.dart';
