import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/suggestions/domain/song_suggestion.dart';

/// O modelo da sugestão.
///
/// Duas coisas aqui quebram caladas: a leitura da data civil (que não pode
/// passar por fuso nenhum) e o enum de status vindo de um servidor mais novo
/// que o APK instalado.
void main() {
  Map<String, dynamic> json({
    String? targetDate,
    String? songId,
    Object? status,
    List<String> alsoSuggestedBy = const [],
  }) =>
      {
        'id': 'sg1',
        'songId': songId,
        'title': 'Bondade de Deus',
        'artist': 'Isaías Saad',
        'link': null,
        'targetDate': targetDate,
        'reason': 'A igreja já canta essa nos cultos de oração.',
        'status': status ?? 'PENDING',
        'declineReason': null,
        'inRepertoire': songId != null,
        'createdBy': {
          'membershipId': 'm1',
          'displayName': 'Maria',
          'avatarUrl': null,
        },
        'createdAt': '2026-09-03T12:00:00.000Z',
        'alsoSuggestedBy': alsoSuggestedBy,
      };

  test('a data é lida como dia de calendário, sem fuso pelo caminho', () {
    final s = SongSuggestion.fromJson(json(targetDate: '2026-09-13'));

    // O erro clássico seria `DateTime.parse`, que trata a string como instante
    // UTC e devolve dia 12 às 21h em São Paulo -- o domingo pedido viraria
    // sábado na tela.
    expect(s.targetDate, DateTime(2026, 9, 13));
    expect(s.isForRepertoire, isFalse);
  });

  test('sem data significa "para o repertório", e não campo faltando', () {
    final s = SongSuggestion.fromJson(json());

    expect(s.targetDate, isNull);
    expect(s.isForRepertoire, isTrue);
  });

  test('status desconhecido não derruba a tela: cai em pendente', () {
    // Um servidor mais novo pode ganhar um status que este APK não conhece.
    // Mostrar a sugestão como pendente é melhor que uma tela em erro.
    final s = SongSuggestion.fromJson(json(status: 'CONVERSAR'));

    expect(s.status, SuggestionStatus.pending);
    expect(s.status.isPending, isTrue);
  });

  test('sem cadastro não há o que pôr no culto', () {
    expect(SongSuggestion.fromJson(json()).canGoToSetlist, isFalse);
    expect(
      SongSuggestion.fromJson(json(songId: 's1')).canGoToSetlist,
      isTrue,
    );
  });

  test('a faixa da escala só oferece o que dá para selecionar', () {
    final payload = {
      'date': '2026-09-13',
      'forDate': [
        json(targetDate: '2026-09-13', songId: 's1'),
        // Sugerida sem cadastro: fica na faixa com o botão de cadastrar, e
        // fora da lista de selecionáveis.
        json(targetDate: '2026-09-13'),
      ],
      'undated': [json(songId: 's2')],
    };

    final suggestions = EventSuggestions.fromJson(payload);

    expect(suggestions.date, '2026-09-13');
    expect(suggestions.forDate, hasLength(2));
    expect(suggestions.undated, hasLength(1));
    expect(suggestions.selectable, hasLength(2));
    expect(suggestions.isEmpty, isFalse);
  });

  test('quem mais sugeriu vem como lista de nomes', () {
    final s = SongSuggestion.fromJson(
      json(alsoSuggestedBy: const ['Samuel', 'João']),
    );

    expect(s.alsoSuggestedBy, ['Samuel', 'João']);
  });
}
