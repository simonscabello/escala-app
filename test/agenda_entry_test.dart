import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/events/domain/agenda_entry.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';
import 'package:louvor_app/features/team_events/domain/team_event.dart';
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
      [
        'escala/thursday/thursday',
        'escala/sunday/morning',
        'escala/sunday/night',
      ],
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
    final entry =
        agendaEntries([event('old', '2026-09-10T22:30:00Z')]).single
            as ScheduleEntry;
    expect(entry.title, 'Culto');
    expect(entry.day, DateTime(2026, 9, 10));
  });

  test('a lista do dia conta escalas, e não horários', () {
    final entries = agendaEntries([
      event(
        'sunday',
        '2026-09-13T11:30:00Z',
        services: [
          {
            'id': 'morning',
            'label': 'Manhã',
            'startsAt': '2026-09-13T11:30:00Z',
          },
          {'id': 'night', 'label': 'Noite', 'startsAt': '2026-09-13T22:00:00Z'},
        ],
      ),
    ]);

    // Dois pontos no calendário é certo; duas linhas na lista faria a equipe
    // achar que tem escala em dobro.
    expect(groupAgendaEntries(entries)['2026-09-13'], hasLength(2));
    final linhas = groupAgendaRows(entries)['2026-09-13']!;
    expect(linhas, hasLength(1));
    expect((linhas.single as ScheduleEntry).event.id, 'sunday');
  });

  group('o evento da equipe na agenda', () {
    test('entra na mesma lista, ordenado pelo relógio', () {
      final entries = agendaEntries(
        [event('domingo', '2026-09-13T11:30:00Z')],
        teamEvents: [
          teamEvent('churrasco', '2026-09-12T15:00:00Z'),
          teamEvent('reuniao', '2026-09-14T23:00:00Z'),
        ],
      );

      // Misturados, e não a agenda de escalas seguida da de eventos: quem
      // abre a tela quer o mês como ele acontece.
      expect(
        entries.map((e) => e.id),
        ['evento/churrasco', 'escala/domingo/domingo', 'evento/reuniao'],
      );
    });

    test('cada evento é uma linha, e marca o próprio dia', () {
      final entries = agendaEntries(
        const [],
        teamEvents: [teamEvent('churrasco', '2026-09-12T15:00:00Z')],
      );

      expect(groupAgendaEntries(entries).keys, ['2026-09-12']);
      final linha = groupAgendaRows(entries)['2026-09-12']!.single;
      expect(linha, isA<TeamEventEntry>());
      expect((linha as TeamEventEntry).event.title, 'churrasco');
    });

    test('o recorte pessoal não esconde o evento da equipe', () {
      final entries = agendaEntries(
        [
          event(
            'minha',
            '2026-09-10T22:30:00Z',
            assignments: [grupo('Bateria', 'm-eu')],
          ),
          event('da-equipe', '2026-09-13T11:30:00Z'),
        ],
        teamEvents: [teamEvent('churrasco', '2026-09-12T15:00:00Z')],
      );

      final minhas = filterAgendaEntries(
        entries,
        filter: AgendaFilter.mine,
        membershipId: 'm-eu',
      );

      // O domingo em que ela não toca sai; o churrasco fica. Um evento não
      // tem escalados -- é de todo mundo, inclusive dela.
      expect(minhas.map((e) => e.id), [
        'escala/minha/minha',
        'evento/churrasco',
      ]);
    });
  });

  test('o recorte pessoal sai de estar escalado em alguma função', () {
    final entries = agendaEntries([
      event(
        'minha',
        '2026-09-10T22:30:00Z',
        assignments: [grupo('Bateria', 'm-eu')],
      ),
      event('da-equipe', '2026-09-13T11:30:00Z'),
    ]);

    expect(
      filterAgendaEntries(
        entries,
        filter: AgendaFilter.all,
        membershipId: 'm-eu',
      ),
      hasLength(2),
    );
    expect(
      filterAgendaEntries(
        entries,
        filter: AgendaFilter.mine,
        membershipId: 'm-eu',
      ).map((e) => (e as ScheduleEntry).event.id),
      ['minha'],
    );
    // Sem membership não há recorte pessoal possível: some tudo, em vez de
    // devolver a agenda inteira como se fosse sua.
    expect(
      filterAgendaEntries(
        entries,
        filter: AgendaFilter.mine,
        membershipId: '',
      ),
      isEmpty,
    );
  });
}

Map<String, dynamic> grupo(String funcao, String membershipId) => {
      'positionId': 'p-$funcao',
      'positionName': funcao,
      'sortOrder': 0,
      'members': [
        {
          'id': 'a-$funcao',
          'membershipId': membershipId,
          'displayName': 'Simon',
          'note': null,
          'isRegisteredForPosition': true,
        },
      ],
    };

Event event(
  String id,
  String startsAt, {
  List<Map<String, dynamic>> services = const [],
  List<Map<String, dynamic>> assignments = const [],
}) =>
    Event.fromJson({
      'id': id,
      'teamId': 't1',
      'title': null,
      'startsAt': startsAt,
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'services': services,
      'assignments': assignments,
    });

TeamEvent teamEvent(String id, String startsAt, {String? endsAt}) =>
    TeamEvent.fromJson({
      'id': id,
      'teamId': 't1',
      'title': id,
      'startsAt': startsAt,
      'endsAt': endsAt,
      'location': null,
      'notes': null,
      'timezone': 'America/Sao_Paulo',
    });
