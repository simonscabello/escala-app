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

final _escalado = [
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
];

void main() {
  test('sem ninguém escalado, a equipe é o que impede publicar', () {
    final event = Event.fromJson(eventJson(morningSongs: 2));

    expect(event.isDraft, isTrue);
    expect(event.publicationBlockers, ['equipe']);
  });

  /// A regra que motivou a mudança: no culto de quinta a equipe é definida
  /// com um mês de antecedência e as músicas saem na semana.
  test('repertório em aberto não impede publicar, mas continua sendo dito', () {
    final event = Event.fromJson(eventJson(assignments: _escalado));

    expect(event.publicationBlockers, isEmpty);
    expect(event.servicesWithoutSongs, ['Manhã', 'Noite']);
    expect(event.hasNoSongs, isTrue);
  });

  test('com um culto montado e outro não, só o que falta é nomeado', () {
    final event = Event.fromJson(
      eventJson(morningSongs: 2, assignments: _escalado),
    );

    expect(event.publicationBlockers, isEmpty);
    expect(event.servicesWithoutSongs, ['Noite']);
    expect(event.hasNoSongs, isFalse);
  });

  test('nada em aberto quando há equipe e música em cada culto', () {
    final event = Event.fromJson(
      eventJson(morningSongs: 2, eveningSongs: 3, assignments: _escalado),
    );

    expect(event.publicationBlockers, isEmpty);
    expect(event.servicesWithoutSongs, isEmpty);
    expect(event.hasNoSongs, isFalse);
  });

  /// Escala publicada também responde "as músicas já saíram?": é a pergunta
  /// de quem está escalado e quer saber se dá para ensaiar.
  test('escala publicada continua dizendo que o repertório está em aberto', () {
    final event = Event.fromJson(
      eventJson(status: 'PUBLISHED', assignments: _escalado),
    );

    expect(event.isDraft, isFalse);
    expect(event.servicesWithoutSongs, ['Manhã', 'Noite']);
  });

  /// Cache gravado antes de `songCount` existir. Na agenda `songs` vem vazio
  /// de propósito, então não há de onde tirar a contagem -- e um palpite
  /// marcaria como pendente toda escala já montada.
  test('sem songCount e sem músicas carregadas, não inventa pendência', () {
    final event = Event.fromJson({
      'id': 'e1',
      'teamId': 't1',
      'startsAt': '2026-09-06T12:00:00.000Z',
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'assignments': _escalado,
      'songs': [],
      'services': [
        {
          'id': 'manha',
          'label': 'Manhã',
          'startsAt': '2026-09-06T12:00:00.000Z',
        },
      ],
    });

    expect(event.servicesWithoutSongs, isEmpty);
    expect(event.hasNoSongs, isFalse);
  });
}
