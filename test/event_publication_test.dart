import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';

Map<String, dynamic> eventJson({
  String status = 'DRAFT',
  List<Object?> assignments = const [],
  int morningSongs = 0,
  int eveningSongs = 0,
}) {
  return {
    'id': 'e1',
    'teamId': 't1',
    'startsAt': '2026-09-06T12:00:00.000Z',
    'status': status,
    'timezone': 'America/Sao_Paulo',
    'assignments': assignments,
    'songs': [],
    'services': [
      {
        'id': 'manha',
        'label': 'Manhã',
        'startsAt': '2026-09-06T12:00:00.000Z',
        'songCount': morningSongs,
      },
      {
        'id': 'noite',
        'label': 'Noite',
        'startsAt': '2026-09-06T22:00:00.000Z',
        'songCount': eveningSongs,
      },
    ],
  };
}

void main() {
  test('rascunho mostra cada pendência que impede a publicação', () {
    final event = Event.fromJson(eventJson(morningSongs: 2));

    expect(event.isDraft, isTrue);
    expect(event.publicationPendingItems, ['equipe', 'músicas de Noite']);
  });

  test('fica pronto quando há equipe e música em cada culto', () {
    final event = Event.fromJson(
      eventJson(
        morningSongs: 2,
        eveningSongs: 3,
        assignments: [
          {
            'positionId': 'p1',
            'positionName': 'Vocal',
            'members': [
              {
                'id': 'a1',
                'membershipId': 'm1',
                'displayName': 'Maria',
                'note': null,
              },
            ],
          },
        ],
      ),
    );

    expect(event.publicationPendingItems, isEmpty);
  });
}
