import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/events/domain/agenda_entry.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('cada culto tem horário próprio, com ordem global e sem duplicação', () {
    final sunday = event(
      'sunday',
      '2026-09-13T11:30:00Z',
      services: [
        {'id': 'night', 'label': 'Noite', 'startsAt': '2026-09-13T22:00:00Z'},
        {'id': 'morning', 'label': 'Manhã', 'startsAt': '2026-09-13T11:30:00Z'},
      ],
    );
    final entries = agendaEntries([
      sunday,
      event('thursday', '2026-09-10T22:30:00Z'),
      sunday,
    ]);
    expect(
      entries.map((e) => e.id),
      ['thursday/thursday', 'sunday/morning', 'sunday/night'],
    );
    expect(groupAgendaEntries(entries)['2026-09-13'], hasLength(2));
  });

  test('agrupa pela data local de cada culto, inclusive na virada do ano', () {
    final entries = agendaEntries([
      event(
        'new-year',
        '2027-01-01T01:00:00Z',
        services: [
          {'id': 'eve', 'label': 'Vigília', 'startsAt': '2027-01-01T01:00:00Z'},
          {'id': 'day', 'label': 'Manhã', 'startsAt': '2027-01-01T12:00:00Z'},
        ],
      ),
    ]);
    expect(groupAgendaEntries(entries).keys, ['2026-12-31', '2027-01-01']);
  });

  test('cache antigo sem services conserva o horário original', () {
    final entry = agendaEntries([event('old', '2026-09-10T22:30:00Z')]).single;
    expect(entry.title, 'Culto');
    expect(entry.day, DateTime(2026, 9, 10));
  });
}

Event event(
  String id,
  String startsAt, {
  List<Map<String, dynamic>> services = const [],
}) =>
    Event.fromJson({
      'id': id,
      'teamId': 't1',
      'title': null,
      'startsAt': startsAt,
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'services': services,
    });
