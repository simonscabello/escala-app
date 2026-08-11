import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:louvor_app/features/events/domain/event_datetime.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting('pt_BR');
  });

  test('fromJson mapeia datas ISO UTC', () {
    final event = Event.fromJson({
      'id': 'e1',
      'teamId': 't1',
      'title': 'Culto',
      'startsAt': '2026-08-09T12:00:00.000Z',
      'rehearsalAt': '2026-08-08T22:00:00.000Z',
      'location': null,
      'notes': 'Chegar cedo',
      'colorPalette': 'Preto e dourado',
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'assignments': [],
      'songs': [],
    });

    expect(event.startsAt.isUtc, isTrue);
    expect(event.startsAt.hour, 12);
    expect(event.rehearsalAt, isNotNull);
    expect(event.colorPalette, 'Preto e dourado');
    expect(event.assignments, isEmpty);
  });

  test('formata dia da semana e horario em portugues no TZ da equipe', () {
    final utc = DateTime.parse('2026-08-09T12:00:00.000Z');

    final label = formatEventWeekdayDate(utc, 'America/Sao_Paulo');
    final time = formatEventTime(utc, 'America/Sao_Paulo');

    expect(label.toLowerCase(), contains('domingo'));
    expect(time, '09:00');
  });

  test('dia da semana comeca com maiuscula', () {
    final label = formatEventWeekdayDate(
      DateTime.parse('2026-08-09T12:00:00.000Z'),
      'America/Sao_Paulo',
    );

    expect(label.startsWith('Domingo'), isTrue, reason: label);
  });

  test('mostra o ano apenas quando difere do ano corrente', () {
    const tzName = 'America/Sao_Paulo';
    final thisYear = DateTime.now().year;

    final atual = formatEventWeekdayDate(
      DateTime.utc(thisYear, 8, 9, 12),
      tzName,
    );
    final antigo = formatEventWeekdayDate(
      DateTime.utc(thisYear - 1, 8, 9, 12),
      tzName,
    );

    expect(atual.contains('$thisYear'), isFalse, reason: atual);
    expect(antigo.contains('${thisYear - 1}'), isTrue, reason: antigo);
  });

  group('horario do ensaio', () {
    const tzName = 'America/Sao_Paulo';
    // Domingo, 9 de agosto de 2026, 09:00 em Sao Paulo.
    final culto = DateTime.parse('2026-08-09T12:00:00.000Z');

    test('no mesmo dia do culto, so a hora', () {
      final ensaio = DateTime.parse('2026-08-09T16:00:00.000Z');

      expect(formatRehearsalTime(ensaio, culto, tzName), '13:00');
    });

    test('em outro dia, o dia da semana abreviado antes da hora', () {
      // Sabado, 8 de agosto, 19:00.
      final ensaio = DateTime.parse('2026-08-08T22:00:00.000Z');

      final label = formatRehearsalTime(ensaio, culto, tzName);

      expect(label, 'sáb 19:00');
    });

    test('nunca traz a data por extenso, que estourava o cartao', () {
      final ensaio = DateTime.parse('2026-08-10T03:30:00.000Z');

      final label = formatRehearsalTime(ensaio, culto, tzName);

      // O formato antigo era "Segunda-feira, 10 de agosto 00:30" -- 33
      // caracteres numa etiqueta que cabia em 15, e o layout quebrava.
      expect(label, 'seg 00:30');
      expect(label.length, lessThan(12));
      expect(label, isNot(contains('agosto')));
      expect(label, isNot(contains('-feira')));
    });

    test('dia abreviado vem minusculo e sem ponto', () {
      final label = formatEventShortWeekday(
        DateTime.parse('2026-08-08T22:00:00.000Z'),
        tzName,
      );

      expect(label, 'sáb');
    });
  });

  /// A frase dos horários ("Ensaio no sábado às 19:00") precisa do dia por
  /// extenso e do artigo certo. Português não perdoa: "no sábado" e "na quinta"
  /// não trocam de lugar, e um artigo fixo erra metade da semana.
  group('o dia do ensaio dentro da frase', () {
    const tzName = 'America/Sao_Paulo';
    // Domingo, 9 de agosto de 2026, 09:00 em Sao Paulo.
    final culto = DateTime.parse('2026-08-09T12:00:00.000Z');

    test('sabado e domingo levam "no"', () {
      // Sabado, 8 de agosto, 19:00.
      expect(
        formatRehearsalDayPhrase(
          DateTime.parse('2026-08-08T22:00:00.000Z'),
          culto,
          tzName,
        ),
        'no sábado',
      );
    });

    test('de segunda a sexta levam "na", porque o substantivo e "feira"', () {
      // Quinta, 6 de agosto, 19:00.
      expect(
        formatRehearsalDayPhrase(
          DateTime.parse('2026-08-06T22:00:00.000Z'),
          culto,
          tzName,
        ),
        'na quinta',
      );
      // Segunda, 10 de agosto, 00:30.
      expect(
        formatRehearsalDayPhrase(
          DateTime.parse('2026-08-10T03:30:00.000Z'),
          culto,
          tzName,
        ),
        'na segunda',
      );
    });

    test('o "-feira" nao entra: ninguem diz "na quinta-feira as 19"', () {
      final phrase = formatRehearsalDayPhrase(
        DateTime.parse('2026-08-06T22:00:00.000Z'),
        culto,
        tzName,
      );

      expect(phrase, isNot(contains('-feira')));
    });

    test('no mesmo dia do culto a frase fica vazia', () {
      // Dizer o dia aqui repetiria a data que está logo acima, no título.
      expect(
        formatRehearsalDayPhrase(
          DateTime.parse('2026-08-09T16:00:00.000Z'),
          culto,
          tzName,
        ),
        isEmpty,
      );
    });
  });
}
