import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:louvor_app/core/date/civil_date.dart';
import 'package:louvor_app/features/team/domain/team_models.dart';
import 'package:louvor_app/shared/domain/person_fields.dart';

/// Um integrante como a API o devolve, com o mínimo preenchido.
Member membro(Map<String, dynamic> extras) => Member.fromJson({
      'id': 'm1',
      'displayName': 'Ana',
      'role': 'MEMBER',
      'hasAccount': true,
      'positions': const <dynamic>[],
      ...extras,
    });

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('dia civil', () {
    test('lê a data da API sem deixar o fuso empurrar para o dia anterior', () {
      final data = parseDateKey('1990-03-01');

      expect(data, isNotNull);
      expect(data!.year, 1990);
      expect(data.month, 3);
      // O erro que isto existe para impedir: `DateTime.parse` seguido de
      // `toLocal()` devolve 28 de fevereiro a oeste de Greenwich.
      expect(data.day, 1);
    });

    test('volta para a API no mesmo dia em que a pessoa escolheu', () {
      expect(dateKey(DateTime(1990, 3, 1)), '1990-03-01');
      expect(dateKey(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('data ausente ou quebrada vira nulo, e não exceção', () {
      expect(parseDateKey(null), isNull);
      expect(parseDateKey(''), isNull);
      expect(parseDateKey('ontem'), isNull);
    });
  });

  group('aniversário', () {
    test('conta os dias até o próximo, virando o ano quando já passou', () {
      final base = DateTime(2026, 12, 20);

      expect(daysUntilBirthday(DateTime(1990, 12, 25), base), 5);
      // Aniversário de 1º de janeiro visto em dezembro: o próximo é no ano
      // seguinte, e não um número negativo.
      expect(daysUntilBirthday(DateTime(1990, 1, 1), base), 12);
    });

    test('o dia do aniversário conta zero, não trezentos e sessenta e cinco',
        () {
      final base = DateTime(2026, 5, 10);
      expect(daysUntilBirthday(DateTime(1988, 5, 10), base), 0);
    });

    test('idade só aumenta depois do dia', () {
      final nascimento = DateTime(1990, 6, 15);

      expect(ageOn(nascimento, DateTime(2026, 6, 14)), 35);
      expect(ageOn(nascimento, DateTime(2026, 6, 15)), 36);
    });

    test('a etiqueta do mês não mostra o ano', () {
      expect(formatBirthday(DateTime(1990, 3, 12)), '12 de março');
    });
  });

  group('Member vindo da API', () {
    test('sem conta não traz nascimento nem gênero, e isso não é erro', () {
      final m = membro({'hasAccount': false});

      expect(m.hasAccount, isFalse);
      expect(m.birthDate, isNull);
      expect(m.gender, isNull);
      expect(m.daysToBirthday, isNull);
    });

    test('lê nascimento, gênero e afastamento', () {
      final m = membro({
        'birthDate': '1992-08-30',
        'gender': 'FEMALE',
        'notes': 'Chega depois das 9h',
        'onLeave': true,
        'leaveUntil': '2027-01-15',
        'leaveReason': 'Intercâmbio',
        'leaveOverdue': false,
      });

      expect(m.birthDate, DateTime(1992, 8, 30));
      expect(m.gender, Gender.female);
      expect(m.notes, 'Chega depois das 9h');
      expect(m.onLeave, isTrue);
      expect(m.leaveUntil, DateTime(2027, 1, 15));
      expect(m.leaveLabel, 'Em afastamento até 15 de janeiro');
    });

    test('gênero desconhecido vira nulo em vez de derrubar a lista', () {
      expect(membro({'gender': 'ALIEN'}).gender, isNull);
      expect(membro({'gender': null}).gender, isNull);
    });

    test('sem previsão a etiqueta não inventa data', () {
      final m = membro({'onLeave': true});
      expect(m.leaveLabel, 'Em afastamento');
    });
  });

  group('telefone para WhatsApp', () {
    test('celular e fixo com DDD ganham o código do país', () {
      expect(membro({'phone': '(11) 98765-4321'}).phoneDigits, '5511987654321');
      expect(membro({'phone': '11 3456-7890'}).phoneDigits, '551134567890');
    });

    test('número que já veio com o país não ganha outro', () {
      expect(membro({'phone': '+55 11 98765-4321'}).phoneDigits, '5511987654321');
    });

    test('número curto demais não vira botão', () {
      // Melhor não oferecer WhatsApp do que abrir conversa com ninguém.
      expect(membro({'phone': '98765-4321'}).phoneDigits, isNull);
      expect(membro({'phone': '1234'}).phoneDigits, isNull);
      expect(membro({'phone': null}).phoneDigits, isNull);
      expect(membro({'phone': 'recado com a mãe'}).phoneDigits, isNull);
    });
  });
}
