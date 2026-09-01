import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/assignments/presentation/assignment_form_screen.dart';
import 'package:louvor_app/features/team/domain/workload_report.dart';

/// A linha de rodízio no seletor da escalação.
///
/// Ela existe para o líder reparar em quem está sumindo da escala sem ter de
/// abrir um relatório — então o que se testa é a leitura: "há quanto tempo" na
/// unidade que a pessoa usaria ao falar, e a contagem por escala.
void main() {
  final now = DateTime.utc(2026, 3, 1, 12);

  RotationMember member({DateTime? last, int recent = 0}) => RotationMember(
        membershipId: 'm1',
        recentCount: recent,
        lastScheduledAt: last,
      );

  test('sem histórico, diz que não houve escala no último ano', () {
    expect(
      rotationSummary(null, weeks: 8, now: now),
      'Sem escala no último ano',
    );
    expect(
      rotationSummary(member(), weeks: 8, now: now),
      'Sem escala no último ano',
    );
  });

  test('conta em dias na primeira quinzena e em semanas depois', () {
    expect(
      rotationSummary(
        member(last: DateTime.utc(2026, 2, 26, 12), recent: 2),
        weeks: 8,
        now: now,
      ),
      'Há 3 dias · 2 escalas em 8 semanas',
    );
    expect(
      rotationSummary(
        member(last: DateTime.utc(2026, 2, 8, 12), recent: 1),
        weeks: 8,
        now: now,
      ),
      'Há 3 semanas · 1 escala em 8 semanas',
    );
  });

  test('passado de dois meses vira meses, e não dez semanas', () {
    expect(
      rotationSummary(
        member(last: DateTime.utc(2025, 12, 1, 12)),
        weeks: 8,
        now: now,
      ),
      'Há 3 meses · 0 escalas em 8 semanas',
    );
  });

  test('quem tocou hoje não vira "há 0 dias"', () {
    expect(
      rotationSummary(
        member(last: DateTime.utc(2026, 3, 1, 9), recent: 1),
        weeks: 8,
        now: now,
      ),
      'Hoje · 1 escala em 8 semanas',
    );
  });
}
