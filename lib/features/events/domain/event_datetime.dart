import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

DateTime eventLocalTime(DateTime utc, String timezone) {
  return tz.TZDateTime.from(utc, tz.getLocation(timezone));
}

String formatEventWeekdayDate(DateTime utc, String timezone) {
  final localTime = eventLocalTime(utc, timezone);
  return DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(localTime);
}

String formatEventTime(DateTime utc, String timezone) {
  final localTime = eventLocalTime(utc, timezone);
  return DateFormat('HH:mm', 'pt_BR').format(localTime);
}
