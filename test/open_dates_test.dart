import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';
import 'package:louvor_app/features/events/domain/open_date.dart';
import 'package:louvor_app/features/team/domain/service_template.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// As datas em aberto são a **prévia** do que o botão "criar rascunhos" vai
/// gravar: a mesma regra que roda no servidor, calculada no aparelho para a
/// agenda poder mostrar o mês antes de existir uma linha no banco.
///
/// O que estes testes protegem é essa igualdade. Se a regra daqui divergir da
/// de `EventsService.generate`, a tela promete um conjunto de datas e o
/// servidor cria outro — e o líder só descobre depois de tocar no botão.
const _fuso = 'America/Sao_Paulo';

/// Quarta-feira, meio-dia em São Paulo.
final _quarta = DateTime.utc(2026, 9, 2, 15);

ServiceTemplate _grade(
  String label,
  int weekday,
  int startMinutes, {
  bool isActive = true,
}) =>
    ServiceTemplate(
      id: '$label-$weekday-$startMinutes',
      label: label,
      weekday: weekday,
      startMinutes: startMinutes,
      isActive: isActive,
    );

Event _escala(String startsAt) => Event.fromJson({
      'id': startsAt,
      'teamId': 't1',
      'title': null,
      'startsAt': startsAt,
      'rehearsalAt': null,
      'location': null,
      'notes': null,
      'colorPalette': null,
      'status': 'DRAFT',
      'timezone': _fuso,
      'assignments': const [],
      'songs': const [],
    });

/// Domingo de manhã e de noite, mais a quinta.
final _gradeDaIgreja = [
  _grade('Manhã', 0, 510),
  _grade('Noite', 0, 1140),
  _grade('Oração', 4, 1170),
];

List<OpenDate> _abertas({
  List<ServiceTemplate>? templates,
  List<Event> events = const [],
  DateTime? now,
}) =>
    openDates(
      templates: templates ?? _gradeDaIgreja,
      events: events,
      timezone: _fuso,
      now: now ?? _quarta,
    );

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('Datas que a grade prevê', () {
    test('preenche as quatro semanas seguintes, em ordem', () {
      expect(
        _abertas().map((data) => data.dateParam),
        [
          '2026-09-03',
          '2026-09-06',
          '2026-09-10',
          '2026-09-13',
          '2026-09-17',
          '2026-09-20',
          '2026-09-24',
          '2026-09-27',
        ],
      );
    });

    test('o domingo é uma data só, com os dois cultos em ordem de horário', () {
      final domingo =
          _abertas().firstWhere((data) => data.dateParam == '2026-09-06');

      expect(domingo.services.map((culto) => culto.label), ['Manhã', 'Noite']);
      // 08:30 em São Paulo. O instante da data é o do culto mais cedo, igual
      // ao que a escala grava em `startsAt`.
      expect(domingo.services.first.startsAt, DateTime.utc(2026, 9, 6, 11, 30));
      expect(domingo.startsAt, domingo.services.first.startsAt);
    });

    test('hoje conta como data em aberto', () {
      // Domingo ao meio-dia, com o culto da manhã já passado. A data continua
      // sendo proposta porque a agenda trata o dia civil inteiro como próximo
      // -- e porque é o que o servidor faria ao gerar os rascunhos.
      final datas = _abertas(now: DateTime.utc(2026, 9, 6, 15));

      expect(datas.first.dateParam, '2026-09-06');
    });

    test('linha desativada da grade não propõe data', () {
      final datas = _abertas(
        templates: [
          _grade('Manhã', 0, 510),
          _grade('Oração', 4, 1170, isActive: false),
        ],
      );

      expect(datas.map((data) => data.dateParam), [
        '2026-09-06',
        '2026-09-13',
        '2026-09-20',
        '2026-09-27',
      ]);
    });

    test('sem grade não há o que propor', () {
      expect(_abertas(templates: const []), isEmpty);
    });
  });

  group('Datas que já viraram escala', () {
    test('saem da lista', () {
      final datas = _abertas(events: [_escala('2026-09-06T11:30:00.000Z')]);

      expect(datas.any((data) => data.dateParam == '2026-09-06'), isFalse);
      expect(datas, hasLength(7));
    });

    test('saem inteiras, mesmo que a escala cubra só um dos cultos', () {
      // A escala do domingo é uma só para manhã e noite. Propor "Noite" de
      // novo criaria uma segunda escala no mesmo dia -- exatamente o que o
      // modelo evita ao pendurar a escalação na data, e não no culto.
      final datas = _abertas(events: [_escala('2026-09-06T22:00:00.000Z')]);

      expect(datas.any((data) => data.dateParam == '2026-09-06'), isFalse);
    });

    test('escala fora da janela não tira data nenhuma', () {
      final datas = _abertas(events: [_escala('2026-12-25T15:00:00.000Z')]);

      expect(datas, hasLength(8));
    });
  });

  group('Fuso da equipe', () {
    // Uma vigília das 22:00 cai no dia seguinte em UTC. Se a conta fosse feita
    // no relógio de Greenwich, a data apareceria como domingo, o link levaria
    // para a data errada e a vigília que já tem escala continuaria sendo
    // proposta.
    final vigilia = [_grade('Vigília', 6, 1320)];

    test('a data é a do calendário da equipe, não a do UTC', () {
      final datas = _abertas(templates: vigilia);

      expect(datas.first.dateParam, '2026-09-05');
      expect(datas.first.startsAt, DateTime.utc(2026, 9, 6, 1));
    });

    test('e a escala já criada é reconhecida pelo mesmo critério', () {
      final datas = _abertas(
        templates: vigilia,
        events: [_escala('2026-09-06T01:00:00.000Z')],
      );

      expect(datas.map((data) => data.dateParam), [
        '2026-09-12',
        '2026-09-19',
        '2026-09-26',
      ]);
    });
  });
}
