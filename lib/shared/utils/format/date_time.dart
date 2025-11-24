import 'package:intl/intl.dart';

class DateFormatUtils {
  // Cache the DateFormat to avoid re-creating it on every call (better perf).
  static final DateFormat _friendlyFormatter = DateFormat(
    'MMM d, yyyy hh:mm a',
  );

  static String formatFriendly(DateTime dateTime) =>
      _friendlyFormatter.format(dateTime);
}
