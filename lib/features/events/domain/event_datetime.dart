import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

DateTime eventLocalTime(DateTime utc, String timezone) {
  return tz.TZDateTime.from(utc, tz.getLocation(timezone));
}

String formatEventWeekdayDate(DateTime utc, String timezone) {
  final location = tz.getLocation(timezone);
  final localTime = tz.TZDateTime.from(utc, location);
  final now = tz.TZDateTime.now(location);

  // O ano so aparece quando difere do atual: "Domingo, 9 de agosto" no uso do
  // dia a dia, "Domingo, 9 de agosto de 2025" ao revisitar cultos passados.
  final pattern = localTime.year == now.year
      ? "EEEE, d 'de' MMMM"
      : "EEEE, d 'de' MMMM 'de' y";

  // O pt_BR devolve o dia da semana em minuscula ("domingo"); como este texto
  // abre cards e mensagens, a maiuscula inicial faz diferenca na leitura.
  return _capitalize(DateFormat(pattern, 'pt_BR').format(localTime));
}

/// O pt_BR devolve o dia da semana em minúscula; exposto para outros pontos
/// que formatam data por conta própria usarem a mesma regra.
String capitalizeWeekday(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

String _capitalize(String value) => capitalizeWeekday(value);

/// Duas datas caem no mesmo dia civil no fuso da equipe?
/// Usado para não repetir a data do culto no horário do ensaio.
bool isSameLocalDay(DateTime a, DateTime b, String timezone) {
  final localA = eventLocalTime(a, timezone);
  final localB = eventLocalTime(b, timezone);
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}

String formatEventTime(DateTime utc, String timezone) {
  final localTime = eventLocalTime(utc, timezone);
  return DateFormat('HH:mm', 'pt_BR').format(localTime);
}
