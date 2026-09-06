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
