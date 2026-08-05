import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';
import 'package:louvor_app/features/events/domain/schedule_share_text.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting('pt_BR');
  });

  Event sampleEvent({List<Object?> songs = const []}) {
    return Event.fromJson({
      'id': 'e1',
      'teamId': 't1',
      'title': 'Culto da Manhã',
      'startsAt': '2026-08-16T12:00:00.000Z',
      'rehearsalAt': '2026-08-15T22:00:00.000Z',
      'location': 'Templo',
      'notes': 'Chegar cedo',
      'colorPalette': 'Preto e dourado',
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'assignments': [
        {
          'positionId': 'p1',
          'positionName': 'Guitarra',
          'sortOrder': 1,
          'members': [
            {
              'id': 'a1',
              'membershipId': 'm1',
              'displayName': 'Samuel',
              'note': null,
              'isRegisteredForPosition': true,
            },
          ],
        },
      ],
      'songs': songs,
    });
  }

  test('texto de compartilhamento inclui culto, ensaio e equipe', () {
    final text = buildScheduleShareText(sampleEvent());

    expect(text, contains('Culto da Manhã'));
    expect(text, contains('Culto às 09:00'));
    expect(text, contains('Ensaio:'));
    expect(text, contains('Guitarra:'));
    expect(text, contains('• Samuel'));
    expect(text, contains('Paleta: Preto e dourado'));
    expect(text, contains('Observações'));
    expect(text, contains('Chegar cedo'));
    expect(text, isNot(contains('Músicas')));
  });

  test('texto inclui músicas quando a lista não está vazia', () {
    final text = buildScheduleShareText(
      sampleEvent(
        songs: [
          {
            'title': 'Grande é o Senhor',
            'artist': 'Adoração',
            'keyOverride': 'G',
          },
        ],
      ),
    );

    expect(text, contains('Músicas'));
    expect(text, contains('1. Grande é o Senhor — Adoração (G)'));
  });
}
