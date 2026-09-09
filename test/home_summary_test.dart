import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';
import 'package:louvor_app/features/home/domain/home_summary.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// A Home responde uma pergunta que a agenda não responde — "quando **eu**
/// toco?" — e a resposta é uma leitura da mesma lista de escalas que a agenda
/// já carregou. Estes testes travam essa leitura, que é a única regra nova que
/// a tela trouxe.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('a minha próxima escala', () {
    test('pula as escalas em que eu não entro', () {
      final resumo = HomeSummary.of(
        [
          _event(id: 'e1', startsAt: '2026-09-13T12:00:00.000Z'),
          _event(
            id: 'e2',
            startsAt: '2026-09-20T12:00:00.000Z',
            assignments: _group('Vocal', ['Simon']),
          ),
          _event(
            id: 'e3',
            startsAt: '2026-09-27T12:00:00.000Z',
            assignments: _group('Violão', ['Simon']),
          ),
        ],
        membershipId: 'm-Simon',
        canManage: false,
        now: DateTime.utc(2026, 9, 9, 12),
      );

      // A agenda destacaria `e1`, que é a próxima da equipe. A pergunta da
      // Home é outra.
      expect(resumo.myNext?.id, 'e2');
      expect(resumo.myPositions, ['Vocal']);
    });

    test('junta as funções quando eu entro em mais de uma', () {
      final resumo = HomeSummary.of(
        [
          _event(
            id: 'e1',
            startsAt: '2026-09-13T12:00:00.000Z',
            assignments: [
              ..._group('Vocal', ['Simon', 'Maria']),
              ..._group('Violão', ['Simon']),
            ],
          ),
        ],
        membershipId: 'm-Simon',
        canManage: false,
        now: DateTime.utc(2026, 9, 9, 12),
      );

      expect(resumo.myPositions, ['Vocal', 'Violão']);
    });

    test('sem participação, a manchete sabe que a equipe tem escalas', () {
      final resumo = HomeSummary.of(
        [_event(id: 'e1', startsAt: '2026-09-13T12:00:00.000Z')],
        membershipId: 'm-Simon',
        canManage: false,
        now: DateTime.utc(2026, 9, 9, 12),
      );

      // "Você está livre" e "não há nada marcado" são frases diferentes, e é
      // este par de campos que as separa.
      expect(resumo.myNext, isNull);
      expect(resumo.hasSchedules, isTrue);
    });

    test('equipe sem escala nenhuma não é "você está livre"', () {
      final resumo = HomeSummary.of(
        const [],
        membershipId: 'm-Simon',
        canManage: true,
        now: DateTime.utc(2026, 9, 9, 12),
      );

      expect(resumo.myNext, isNull);
      expect(resumo.hasSchedules, isFalse);
      expect(resumo.upcoming, isEmpty);
    });
  });

  group('as próximas da equipe', () {
    test('não repetem a escala que já está na manchete', () {
      final resumo = HomeSummary.of(
        [
          _event(
            id: 'e1',
            startsAt: '2026-09-13T12:00:00.000Z',
            assignments: _group('Vocal', ['Simon']),
          ),
          _event(id: 'e2', startsAt: '2026-09-20T12:00:00.000Z'),
          _event(id: 'e3', startsAt: '2026-09-27T12:00:00.000Z'),
        ],
        membershipId: 'm-Simon',
        canManage: false,
        now: DateTime.utc(2026, 9, 9, 12),
      );

      expect(resumo.myNext?.id, 'e1');
      expect(resumo.upcoming.map((e) => e.id), ['e2', 'e3']);
    });

    test('param em três, mesmo com a agenda cheia', () {
      final resumo = HomeSummary.of(
        [
          for (var i = 1; i <= 8; i++)
            _event(id: 'e$i', startsAt: '2026-09-0${i}T12:00:00.000Z'),
        ],
        membershipId: 'm-Simon',
        canManage: false,
        now: DateTime.utc(2026, 9, 1, 12),
      );

      expect(resumo.upcoming, hasLength(HomeSummary.upcomingLimit));
    });
  });

  group('o repertório contado', () {
    test('soma os cultos quando o servidor disse quantas são', () {
      final event = _event(
        id: 'e1',
        startsAt: '2026-09-13T12:00:00.000Z',
        services: [
          _service(id: 's1', label: 'Manhã', startsAt: '2026-09-13T12:00:00.000Z', songCount: 3),
          _service(id: 's2', label: 'Noite', startsAt: '2026-09-13T23:00:00.000Z', songCount: 2),
        ],
      );

      expect(scheduleSongCount(event), 5);
    });

    test('zero é resposta: "músicas a definir"', () {
      final event = _event(
        id: 'e1',
        startsAt: '2026-09-13T12:00:00.000Z',
        services: [
          _service(id: 's1', label: 'Culto', startsAt: '2026-09-13T12:00:00.000Z', songCount: 0),
        ],
      );

      expect(scheduleSongCount(event), 0);
    });

    test('sem saber, cala — cache gravado antes do campo existir', () {
      // `songCount` ausente é o cache antigo. Chutar "0" ali marcaria como
      // pendente toda escala montada que o app ainda não recarregou.
      final event = _event(
        id: 'e1',
        startsAt: '2026-09-13T12:00:00.000Z',
        services: [
          _service(id: 's1', label: 'Culto', startsAt: '2026-09-13T12:00:00.000Z'),
        ],
      );

      expect(scheduleSongCount(event), isNull);
    });
  });

  group('quantos dias faltam', () {
    test('conta dias civis no fuso da equipe, não horas', () {
      // Culto às 09:00 de 13/09 em São Paulo, consultado às 20:00 de 12/09:
      // faltam menos de 24 horas, e a resposta certa continua sendo "amanhã".
      final event = _event(id: 'e1', startsAt: '2026-09-13T12:00:00.000Z');

      expect(daysUntilEvent(event, DateTime.utc(2026, 9, 12, 23)), 1);
      expect(daysUntilEvent(event, DateTime.utc(2026, 9, 13, 3)), 0);
    });
  });

  group('os avisos do pé da tela', () {
    test('"é hoje" quando a minha escala é hoje', () {
      final resumo = HomeSummary.of(
        [
          _event(
            id: 'e1',
            startsAt: '2026-09-13T12:00:00.000Z',
            assignments: _group('Vocal', ['Simon']),
          ),
        ],
        membershipId: 'm-Simon',
        canManage: false,
        now: DateTime.utc(2026, 9, 13, 10),
      );

      expect(resumo.notices.single.kind, HomeNoticeKind.scheduleToday);
      expect(resumo.notices.single.route, '/agenda/e1');
    });

    test('escala distante não vira aviso nenhum', () {
      final resumo = HomeSummary.of(
        [
          _event(
            id: 'e1',
            startsAt: '2026-09-27T12:00:00.000Z',
            assignments: _group('Vocal', ['Simon']),
          ),
        ],
        membershipId: 'm-Simon',
        canManage: false,
        now: DateTime.utc(2026, 9, 9, 12),
      );

      // Sem aviso real o bloco não existe -- e é isso que o mantém digno de
      // ser lido quando aparece.
      expect(resumo.notices, isEmpty);
    });

    test('rascunho e escala vazia só existem para quem gerencia', () {
      final events = [
        _event(id: 'e1', startsAt: '2026-09-13T12:00:00.000Z', status: 'DRAFT'),
      ];

      final membro = HomeSummary.of(
        events,
        membershipId: 'm-Simon',
        canManage: false,
        now: DateTime.utc(2026, 9, 9, 12),
      );
      expect(membro.notices, isEmpty);

      final lider = HomeSummary.of(
        events,
        membershipId: 'm-Simon',
        canManage: true,
        now: DateTime.utc(2026, 9, 9, 12),
      );
      expect(
        lider.notices.map((n) => n.kind),
        [HomeNoticeKind.pendingDrafts, HomeNoticeKind.unstaffedSchedule],
      );
      expect(lider.notices.first.count, 1);
      expect(lider.notices.last.route, '/agenda/e1/escalar');
    });

    test('nunca mais de dois avisos', () {
      final resumo = HomeSummary.of(
        [
          _event(
            id: 'e1',
            startsAt: '2026-09-13T12:00:00.000Z',
            status: 'DRAFT',
            assignments: _group('Vocal', ['Simon']),
          ),
          _event(id: 'e2', startsAt: '2026-09-20T12:00:00.000Z'),
        ],
        membershipId: 'm-Simon',
        canManage: true,
        now: DateTime.utc(2026, 9, 13, 10),
      );

      expect(resumo.notices, hasLength(HomeSummary.maxNotices));
      // O que é sobre a própria pessoa vem primeiro.
      expect(resumo.notices.first.kind, HomeNoticeKind.scheduleToday);
    });
  });
}

Event _event({
  required String id,
  required String startsAt,
  String status = 'PUBLISHED',
  List<Map<String, dynamic>> assignments = const [],
  List<Map<String, dynamic>> services = const [],
}) =>
    Event.fromJson({
      'id': id,
      'teamId': 't1',
      'title': null,
      'startsAt': startsAt,
      'rehearsalAt': null,
      'location': null,
      'notes': null,
      'colorPalette': null,
      'status': status,
      'timezone': 'America/Sao_Paulo',
      'assignments': assignments,
      'services': services,
      'songs': const [],
    });

Map<String, dynamic> _service({
  required String id,
  required String label,
  required String startsAt,
  int? songCount,
}) =>
    {
      'id': id,
      'label': label,
      'startsAt': startsAt,
      if (songCount != null) 'songCount': songCount,
    };

List<Map<String, dynamic>> _group(String name, List<String> people) => [
      {
        'positionId': 'p-$name',
        'positionName': name,
        'sortOrder': 0,
        'members': [
          for (final p in people)
            {
              'id': 'a-$name-$p',
              'membershipId': 'm-$p',
              'displayName': p,
              'note': null,
              'isRegisteredForPosition': true,
            },
        ],
      },
    ];
