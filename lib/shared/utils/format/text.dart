import 'package:flutter/foundation.dart';

// Returns a compact points label: "1 pt" or "2 pts"
String pointsLabel(int points) =>
    '$points ${(points == 1 || points == 0) ? 'pt' : 'pts'}';

/// Precompiled word matcher: splits on whitespace while keeping word parts with
/// apostrophes and hyphens (e.g. O'Neil, Jean-Luc).
final RegExp _wordExp = RegExp(r"[A-Za-z0-9]+(?:['-][A-Za-z0-9]+)*");

class TextFormat {
  /// Capitalize first letter, lowercase rest. Returns empty string for null/empty.
  static String capitalize(String? input) {
    if (input == null || input.isEmpty) return '';
    if (input.length == 1) return input.toUpperCase();
    return input[0].toUpperCase() + input.substring(1).toLowerCase();
  }

  /// Title-case each word while preserving separators and trimming extra spaces.
  /// Example: "  jEaN-lUc   O'NEIL  " -> "Jean-Luc O'Neil"
  static String titleCase(String? input) {
    if (input == null || input.isEmpty) return '';
    final source = input.trim();
    if (source.isEmpty) return '';
    final buffer = StringBuffer();
    int lastEnd = 0;
    for (final m in _wordExp.allMatches(source)) {
      // Append any non-word chars between previous and current match unchanged
      if (m.start > lastEnd) {
        buffer.write(source.substring(lastEnd, m.start));
      }
      final word = m.group(0)!;
      buffer.write(capitalize(word));
      lastEnd = m.end;
    }
    if (lastEnd < source.length) {
      buffer.write(source.substring(lastEnd));
    }
    // Collapse multiple spaces to single for cleaner UI.
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Safe helper that returns null if input was null (preserves nullable fields).
  static String? titleCaseOrNull(String? input) =>
      input == null ? null : titleCase(input);

  /// Convenience for barangay/locality names.
  static String locality(String? input) => titleCase(input);

  /// For debugging large batches (optional).
  @visibleForTesting
  static List<String> batchTitleCase(Iterable<String> values) =>
      values.map(titleCase).toList();
}

/// String extensions for ergonomic usage.
extension CapitalizationX on String {
  String get asTitleCase => TextFormat.titleCase(this);
  String get asCapitalized => TextFormat.capitalize(this);
}

/// Format address by removing redundant parts and improving readability
String formatAddress(String? address) {
  if (address == null || address.isEmpty) return 'Address not available';

  // Remove trailing ", Philippines" if present
  String formatted = address.replaceAll(RegExp(r',\s*Philippines$'), '');

  // Remove redundant city names (e.g., "Valenzuela, Valenzuela City")
  formatted = formatted.replaceAll(
    RegExp(r'Valenzuela,\s*Valenzuela'),
    'Valenzuela',
  );

  // Capitalize properly
  final words = formatted.split(' ');
  final capitalized = words
      .map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');

  return capitalized.trim();
}

/// Truncate text with ellipsis
String truncateText(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}...';
}

/// Format phone number (Philippine format)
String formatPhoneNumber(String phone) {
  // Remove non-numeric characters
  final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');

  if (cleaned.length == 10) {
    // Format: 0XXX-XXX-XXXX
    return '${cleaned.substring(0, 4)}-${cleaned.substring(4, 7)}-${cleaned.substring(7)}';
  } else if (cleaned.length == 11) {
    // Format: 0XXX-XXX-XXXX
    return '${cleaned.substring(0, 4)}-${cleaned.substring(4, 7)}-${cleaned.substring(7)}';
  }

  return phone; // Return original if format doesn't match
}
