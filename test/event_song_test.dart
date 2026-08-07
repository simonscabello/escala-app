import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';

void main() {
  group('EventSong', () {
    test('usa o tom que o servidor resolveu, sem refazer a escolha', () {
      // A API manda `key` ja resolvido: o desta escala quando existe, senao o
      // da equipe. O app so exibe.
      final comOverride = EventSong.fromJson({
        'songId': 's1',
        'title': 'Consagração',
        'key': 'D',
        'keyOverride': 'D',
        'defaultKey': 'G',
      });

      expect(comOverride.key, 'D');
      // O destaque na tela depende disto: esta escala mudou o tom.
      expect(comOverride.hasCustomKey, isTrue);
    });

    test('sem override, o tom da equipe nao vira destaque', () {
      final semOverride = EventSong.fromJson({
        'songId': 's2',
        'title': 'Aclame ao Senhor',
        'key': 'A',
        'defaultKey': 'A',
      });

      expect(semOverride.key, 'A');
      expect(semOverride.hasCustomKey, isFalse);
    });

    test('musica sem tom nenhum nao quebra', () {
      final semTom = EventSong.fromJson({
        'songId': 's3',
        'title': 'Corinho da igreja',
      });

      expect(semTom.key, isNull);
      expect(semTom.hasCustomKey, isFalse);
      expect(semTom.artist, isNull);
    });
  });

  group('Event', () {
    test('a agenda devolve repertorio vazio, e isso nao e erro', () {
      final event = Event.fromJson({
        'id': 'e1',
        'teamId': 't1',
        'startsAt': '2026-11-01T11:30:00.000Z',
        'status': 'PUBLISHED',
        'assignments': [],
        'songs': [],
      });

      expect(event.songs, isEmpty);
    });

    test('o detalhe traz o repertorio na ordem recebida', () {
      final event = Event.fromJson({
        'id': 'e1',
        'teamId': 't1',
        'startsAt': '2026-11-01T11:30:00.000Z',
        'status': 'PUBLISHED',
        'assignments': [],
        'songs': [
          {'songId': 's1', 'title': 'Primeira', 'position': 0},
          {'songId': 's2', 'title': 'Segunda', 'position': 1},
        ],
      });

      // A ordem e o conteudo: e a sequencia que a equipe vai tocar.
      expect(event.songs.map((s) => s.title), ['Primeira', 'Segunda']);
    });
  });
}
