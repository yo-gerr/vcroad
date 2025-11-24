class PasswordPolicy {
  static const int minLength = 8;
  static final RegExp hasUppercase = RegExp(r'[A-Z]');
  static final RegExp hasLowercase = RegExp(r'[a-z]');
  static final RegExp hasDigit = RegExp(r'[0-9]');
  static final RegExp hasSymbol = RegExp(r'[!@#\$%^&*(),.?":{}|<>]');

  static String? validate(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < minLength) return 'Minimum $minLength characters';
    if (!hasUppercase.hasMatch(value)) {
      return 'Include at least one uppercase letter';
    }
    if (!hasLowercase.hasMatch(value)) {
      return 'Include at least one lowercase letter';
    }
    if (!hasDigit.hasMatch(value)) return 'Include at least one number';
    if (!hasSymbol.hasMatch(value)) {
      return 'Include at least one symbol';
    }
    return null;
  }

  static List<PasswordRule> getRules(String password) {
    return [
      PasswordRule(
        'Minimum $minLength characters',
        password.length >= minLength,
      ),
      PasswordRule(
        'At least one uppercase letter',
        hasUppercase.hasMatch(password),
      ),
      PasswordRule(
        'At least one lowercase letter',
        hasLowercase.hasMatch(password),
      ),
      PasswordRule('At least one number', hasDigit.hasMatch(password)),
      PasswordRule('At least one symbol', hasSymbol.hasMatch(password)),
    ];
  }
}

class PasswordRule {
  final String label;
  final bool isValid;

  PasswordRule(this.label, this.isValid);
}
