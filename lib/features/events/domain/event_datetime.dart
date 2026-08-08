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

/// Dia da semana abreviado e em minúscula: "sáb", "qui".
///
/// Minúscula porque nunca aparece sozinho -- entra dentro de um rótulo
/// ("Ensaio sáb 19:00"), e ali a maiúscula parece começo de frase. O ponto que
/// o pt_BR acrescenta ("sáb.") sai: encosta no horário e vira sujeira.
String formatEventShortWeekday(DateTime utc, String timezone) {
  final localTime = eventLocalTime(utc, timezone);
  return DateFormat('EEE', 'pt_BR').format(localTime).replaceAll('.', '');
}

/// O horário do ensaio, curto o suficiente para caber numa linha.
///
/// No mesmo dia da escala: só a hora. Em outro dia: o dia da semana abreviado
/// antes dela. A data por extenso ("Segunda-feira, 10 de agosto 00:30")
/// estourava o cartão e não acrescentava nada de útil -- o ensaio acontece na
/// semana da escala, e ninguém marca um três semanas antes.
String formatRehearsalTime(
  DateTime rehearsalAt,
  DateTime startsAt,
  String timezone,
) {
  final hora = formatEventTime(rehearsalAt, timezone);
  if (isSameLocalDay(rehearsalAt, startsAt, timezone)) return hora;
  return '${formatEventShortWeekday(rehearsalAt, timezone)} $hora';
}
