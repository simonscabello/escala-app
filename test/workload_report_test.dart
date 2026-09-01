import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/events/data/event_repository.dart';
import 'package:louvor_app/features/team/domain/workload_report.dart';

void main() {
  test('lê contagem por escala sem confundir com duas funções', () {
    final report = WorkloadReport.fromJson({
      'weeks': 8,
      'since': '2026-07-01T00:00:00.000Z',
      'until': '2026-09-01T00:00:00.000Z',
      'members': [
        {
          'membershipId': 'm1',
          'displayName': 'Maria',
          'scheduleCount': 3,
          'assignmentCount': 5,
          'lastScheduledAt': '2026-08-30T12:00:00.000Z',
          'positions': [
            {'name': 'Vocal', 'count': 3},
            {'name': 'Violão', 'count': 2},
          ],
        },
      ],
    });

    expect(report.members.single.scheduleCount, 3);
    expect(report.members.single.assignmentCount, 5);
    expect(report.members.single.positions.first.name, 'Vocal');
  });

  test('lê o resultado do planejamento em lote', () {
    final result = GeneratedSchedules.fromJson({
      'createdCount': 8,
      'skippedCount': 2,
    });

    expect(result.createdCount, 8);
    expect(result.skippedCount, 2);
  });
}
