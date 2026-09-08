import 'package:intl/intl.dart';

// Dia civil — data sem hora e sem fuso, do jeito que a API grava em colunas
// `date`: aniversário, indisponibilidade, previsão de retorno.
//
// **Nunca use `toIso8601String()` para isto.** Ele devolve o instante, e um
// `DateTime` local de meia-noite vira o dia anterior em UTC — quem nasceu no
// dia 1º aparecia no dia 30. A conta é feita sobre ano/mês/dia, e ponto.

/// AAAA-MM-DD a partir de uma data de calendário.
String dateKey(DateTime date) {
  final mes = date.month.toString().padLeft(2, '0');
  final dia = date.day.toString().padLeft(2, '0');
  return '${date.year}-$mes-$dia';
}

/// AAAA-MM-DD -> `DateTime` local à meia-noite. Nulo entra, nulo sai: os
/// campos que usam isto são quase todos opcionais.
DateTime? parseDateKey(String? value) {
  if (value == null || value.length < 10) return null;
  final parts = value.substring(0, 10).split('-').map(int.tryParse).toList();
  if (parts.length != 3 || parts.any((p) => p == null)) return null;
  return DateTime(parts[0]!, parts[1]!, parts[2]!);
}

/// Hoje, sem hora — para comparar com um dia civil sem o relógio atrapalhar.
DateTime today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// "Setembro 2026" — o nome de um mês como cabeçalho.
///
/// **Existe porque o app escrevia isto de três jeitos.** A agenda agrupava as
/// escalas por mês, o calendário de indisponibilidade navegava mês a mês e a
/// tela da equipe fazia o mesmo — e as três montavam o rótulo por conta
/// própria, duas delas com "de" no meio ("Setembro de 2026") e uma sem. São o
/// mesmo elemento na mesma interface, e a pessoa não deveria notar de qual
/// tela veio.
///
/// **Sem o "de", e com o ano sempre.** Sem o "de" porque aqui o mês não está
/// numa frase, é um título; com o ano sempre porque um cabeçalho de mês sem
/// ano não distingue dezembro de dezembro do ano que vem, e as duas listas
/// atravessam a virada.
///
/// Maiúscula inicial: o pt_BR devolve "setembro", e título começa em
/// maiúscula.
String monthYearLabel(DateTime month) {
  return capitalizeMonth(DateFormat('MMMM y', 'pt_BR').format(month));
}

/// O pt_BR devolve o nome do mês em minúscula. Mesma regra do dia da semana.
String capitalizeMonth(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
