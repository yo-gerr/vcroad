// Compile-time constant RegExp patterns (kept top-level for reuse & performance)
final RegExp kEmailRegex = RegExp(
  r'^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$',
  caseSensitive: false,
);

final RegExp kPasswordRegex = RegExp(
  r'^.{8,}$',
); // keep simple; enforce length >= 8

// Accepts: 09123456789, 9123456789, +989123456789, 989123456789
final RegExp kFullPhoneRegex = RegExp(r'^09\d{9}$');

final RegExp kNameRegex = RegExp(r"^[a-zA-Z\s\-']+$");

/// Error message constants (easy to localize later)
const String kRequiredFieldMsg = 'This field is required';
const String kInvalidEmailMsg = 'Please enter a valid email address';
const String kEmptyEmailMsg = 'Please enter your email';
const String kEmptyPasswordMsg = 'Please enter your password';
const String kPasswordTooShortMsg =
    'Password must be at least 8 characters long';
const String kEmptyConfirmMsg = 'Please confirm your password';
const String kPasswordsDontMatchMsg = 'Passwords don’t match';
const String kEmptyPhoneMsg = 'Phone number is required';
const String kInvalidPhoneMsg =
    'Enter a valid mobile number (e.g. 09123456789)';
const String kInvalidNameMsg = 'Name must contain only letters and spaces';

/// Generic required field validator
String? validateRequired(String? value, {String? fieldName}) {
  if (value == null || value.trim().isEmpty) {
    return fieldName == null ? kRequiredFieldMsg : '$fieldName is required';
  }
  return null;
}

/// Email validator (trims input for validation but doesn't mutate original)
String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return kEmptyEmailMsg;
  if (!kEmailRegex.hasMatch(v)) return kInvalidEmailMsg;
  return null;
}

/// Password validator (do not trim passwords)
String? validatePassword(String? value, {int minLength = 8}) {
  final v = value ?? '';
  if (v.isEmpty) return kEmptyPasswordMsg;
  if (v.length < minLength) return kPasswordTooShortMsg;
  return null;
}

/// Confirm password validator (exact match, no trimming)
String? validateConfirmPassword(String? value, String originalPassword) {
  final v = value ?? '';
  if (v.isEmpty) return kEmptyConfirmMsg;
  if (v != originalPassword) return kPasswordsDontMatchMsg;
  return null;
}

/// Phone validator — accepts common prefixes and normalizes to 0-prefixed format before testing
String? validatePhone(String? value) {
  if (value == null) return kEmptyPhoneMsg;
  var v = value.trim();

  if (v.isEmpty) return kEmptyPhoneMsg;

  // Remove spaces, dashes and parentheses often pasted by users
  v = v.replaceAll(RegExp(r'[\s\-\(\)]'), '');

  // Normalize common international forms to local 0-prefixed form
  if (v.startsWith('+98')) {
    v = '0${v.substring(3)}';
  } else if (v.startsWith('98') && v.length == 12) {
    v = '0${v.substring(2)}';
  } else if (v.length == 10 && v.startsWith('9')) {
    // e.g., 9123456789 -> 09123456789
    v = '0$v';
  }

  if (!kFullPhoneRegex.hasMatch(v)) return kInvalidPhoneMsg;
  return null;
}

String? validateName(String? value, {String? fieldName}) {
  if (value == null || value.trim().isEmpty) {
    return fieldName == null ? kRequiredFieldMsg : '$fieldName is required';
  }
  if (!kNameRegex.hasMatch(value.trim())) {
    return fieldName == null ? kInvalidNameMsg : '$fieldName: $kInvalidNameMsg';
  }
  return null;
}
