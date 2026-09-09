import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/events/domain/next_service_date.dart';
import 'package:louvor_app/features/team/domain/service_template.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// "Nova escala" abria sempre em hoje, e hoje quase nunca é dia de culto: quem
/// criava a escala de domingo numa quarta-feira via "Não há grade para este dia
/// da semana" e tinha de abrir o calendário para consertar o palpite do app.
///
/// **Nada de domingo e quinta escrito no código.** Quais dias têm culto é o que
/// a equipe cadastrou; o que estes testes travam é que a regra só olha a grade
/// e o relógio da igreja.
const _fuso = 'America/Sao_Paulo';

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

/// Domingo de manhã (08:30) e de noite (19:00), mais a quinta (19:30).
final _gradeDaIgreja = [
  _grade('Manhã', 0, 510),
  _grade('Noite', 0, 1140),
  _grade('Oração', 4, 1170),
];

DateTime? _proxima({
  List<ServiceTemplate>? templates,
  required DateTime now,
}) =>
    nextScheduledDate(
      templates: templates ?? _gradeDaIgreja,
      timezone: _fuso,
      now: now,
    );

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('numa quarta, propõe a quinta da grade', () {
    // Quarta, 2 de setembro de 2026, meio-dia em São Paulo.
    final data = _proxima(now: DateTime.utc(2026, 9, 2, 15));

    expect(data, DateTime(2026, 9, 3));
  });

  test('na quinta de manhã, o culto da noite ainda é hoje', () {
    // Quinta, 08:00 em São Paulo — o culto é 19:30.
    final data = _proxima(now: DateTime.utc(2026, 9, 3, 11));

    expect(data, DateTime(2026, 9, 3));
  });

  test('passado o último culto do dia, pula para a próxima data', () {
    // Quinta, 21:00 em São Paulo: o culto das 19:30 já começou.
    final data = _proxima(now: DateTime.utc(2026, 9, 4, 0));

    expect(data, DateTime(2026, 9, 6));
  });

  test('no domingo entre os dois cultos, o dia continua sendo hoje', () {
    // Domingo, 12:00 em São Paulo: a manhã passou, a noite não.
    final data = _proxima(now: DateTime.utc(2026, 9, 6, 15));

    expect(data, DateTime(2026, 9, 6));
  });

  test('linha desativada da grade não propõe data', () {
    final data = _proxima(
      templates: [
        _grade('Manhã', 0, 510),
        _grade('Oração', 4, 1170, isActive: false),
      ],
      now: DateTime.utc(2026, 9, 2, 15),
    );

    expect(data, DateTime(2026, 9, 6));
  });

  /// A igreja que só tem culto no sábado recebe a mesma ajuda: nada aqui sabe
  /// o que é "domingo".
  test('a grade de sábado é respeitada como qualquer outra', () {
    final data = _proxima(
      templates: [_grade('Culto', 6, 1140)],
      now: DateTime.utc(2026, 9, 2, 15),
    );

    expect(data, DateTime(2026, 9, 5));
  });

  test('sem grade, nada é proposto', () {
    expect(
      _proxima(templates: const [], now: DateTime.utc(2026, 9, 2, 15)),
      isNull,
    );
  });

  /// O fuso é o da equipe, e não o do aparelho: às 23h de quarta em São Paulo
  /// já é quinta em UTC, e olhar o relógio errado proporia a data seguinte.
  test('a virada do dia é a da igreja', () {
    final data = nextScheduledDate(
      templates: _gradeDaIgreja,
      timezone: _fuso,
      // Quinta, 01:00 UTC = quarta, 22:00 em São Paulo.
      now: DateTime.utc(2026, 9, 3, 1),
    );

    expect(data, DateTime(2026, 9, 3));
  });
}
