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
}
