import 'package:intl/intl.dart';

import '../../core/date/civil_date.dart';

/// Como a pessoa se identifica. `null` (não informado) é um estado legítimo e
/// o padrão: nada no app depende deste campo, ele existe para filtrar e para a
/// equipe conhecer quem está nela.
enum Gender {
  male('MALE', 'Masculino'),
  female('FEMALE', 'Feminino'),
  other('OTHER', 'Outro');

  const Gender(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static Gender? fromApi(String? value) {
    for (final gender in Gender.values) {
      if (gender.apiValue == value) return gender;
    }
    return null;
  }
}

/// "12 de março" — o aniversário como se fala, sem o ano.
///
/// O ano fica de fora de propósito nas listas: quem lê quer saber **quando**
/// parabenizar, e anunciar a idade de todo mundo na tela da equipe é uma
/// decisão que ninguém tomou. Na própria ficha, onde a pessoa vê o que
/// cadastrou, a data aparece inteira.
String formatBirthday(DateTime date) =>
    DateFormat("d 'de' MMMM", 'pt_BR').format(date);

String formatFullDate(DateTime date) =>
    DateFormat('dd/MM/yyyy', 'pt_BR').format(date);

/// Idade completa em uma data — usada só onde a pessoa já viu a data inteira.
int ageOn(DateTime birthDate, DateTime reference) {
  var age = reference.year - birthDate.year;
  final aniversarioPassou = reference.month > birthDate.month ||
      (reference.month == birthDate.month && reference.day >= birthDate.day);
  if (!aniversarioPassou) age--;
  return age;
}

/// O próximo aniversário a partir de hoje, para ordenar "quem vem primeiro".
///
/// 29 de fevereiro cai em 1º de março nos anos comuns: o `DateTime` do Dart
/// normaliza sozinho, e essa é a convenção que a maioria das pessoas usa.
DateTime nextBirthday(DateTime birthDate, DateTime from) {
  final esteAno = DateTime(from.year, birthDate.month, birthDate.day);
  if (!esteAno.isBefore(from)) return esteAno;
  return DateTime(from.year + 1, birthDate.month, birthDate.day);
}

/// Quantos dias faltam. Zero = é hoje.
int daysUntilBirthday(DateTime birthDate, [DateTime? from]) {
  final base = from ?? today();
  return nextBirthday(birthDate, base).difference(base).inDays;
}

/// Nome do mês em português, com inicial maiúscula: "Março".
String monthName(int month) {
  final nome = DateFormat('MMMM', 'pt_BR').format(DateTime(2000, month));
  return nome[0].toUpperCase() + nome.substring(1);
}
