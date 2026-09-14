import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/events/presentation/setlist_form_screen.dart';
import 'package:louvor_app/features/home/domain/learning_songs.dart';
import 'package:louvor_app/features/songs/domain/moment_suggestion.dart';
import 'package:louvor_app/features/songs/domain/repertoire_health.dart';
import 'package:louvor_app/features/songs/domain/song_history.dart';
import 'package:louvor_app/features/songs/domain/song_models.dart';

/// O que o app escreve a partir do histórico do repertório: os motivos das
/// "Sugestões do Pauta", a segunda linha do seletor da escala e a linha das
/// músicas em aprendizado na Home.
///
/// A regra que atravessa as três é não inventar: cada pedaço da frase vem de um
/// dado, e o que não existe não aparece.
void main() {
  final hoje = DateTime(2026, 9, 14, 10);

  group('Sugestões do Pauta', () {
    test('a linha de motivos junta os fatos na ordem do servidor', () {
      final sugestao = MomentSuggestion.fromJson({
        'song': {'id': 's1', 'title': 'Tudo Entregarei', 'hymnals': []},
        'reasons': [
          {'kind': 'THEME', 'theme': 'GRATIDAO'},
          {'kind': 'MOMENT_HISTORY', 'count': 1},
          {'kind': 'LAST_PLAYED', 'lastPlayedAt': '2026-05-10T12:00:00.000Z'},
        ],
      });

      expect(sugestao.song.title, 'Tudo Entregarei');
      expect(
        suggestionReasonsLine(sugestao.reasons, hoje),
        'Gratidão · já utilizada neste momento · 4 meses sem cantar',
      );
    });

    test('mais de uma vez no momento, a contagem entra na frase', () {
      expect(
        suggestionReasonText(
          const SuggestionReason(kind: 'MOMENT_HISTORY', count: 3),
          hoje,
        ),
        'utilizada 3 vezes neste momento',
      );
      expect(
        suggestionReasonText(const SuggestionReason(kind: 'LEARNING'), hoje),
        'estamos aprendendo',
      );
      expect(
        suggestionReasonText(
          const SuggestionReason(kind: 'PACE', pace: 'CALM'),
          hoje,
        ),
        'Calma',
      );
    });

    test('motivo que o app ainda não conhece some, e a linha para em três', () {
      final reasons = [
        const SuggestionReason(kind: 'ALGO_NOVO'),
        const SuggestionReason(kind: 'THEME', theme: 'GRATIDAO'),
        const SuggestionReason(kind: 'MOMENT_HISTORY', count: 2),
        const SuggestionReason(kind: 'LEARNING'),
        const SuggestionReason(kind: 'PACE', pace: 'UPBEAT'),
      ];

      expect(
        suggestionReasonsLine(reasons, hoje),
        'Gratidão · utilizada 2 vezes neste momento · estamos aprendendo',
      );
    });
  });

  group('segunda linha do seletor da escala', () {
    const cantico = Song(
      id: 's1',
      title: 'Bondade de Deus',
      themes: ['BONDADE_DE_DEUS', 'GRATIDAO', 'FIDELIDADE'],
    );

    test('última vez, quantas vezes e até dois temas', () {
      final linha = songPickerHistory(
        cantico,
        SongHistory(
          songId: 's1',
          lastPlayedAt: DateTime(2026, 9, 2, 10),
          last6Months: 3,
        ),
        hoje,
      );

      expect(linha.lastPlayed, 'Cantada há 12 dias');
      expect(linha.recent, isTrue);
      expect(linha.rest, '3 vezes em 6 meses · Bondade de Deus, Gratidão');
    });

    test('a nunca cantada e sem tema não ganha linha nenhuma', () {
      final linha = songPickerHistory(
        const Song(id: 's2', title: 'Hino 142'),
        null,
        hoje,
      );

      expect(linha.lastPlayed, isNull);
      expect(linha.recent, isFalse);
      expect(linha.rest, isNull);
    });
  });

  test('saúde do repertório: o resumo e as listas vêm do servidor', () {
    final health = RepertoireHealth.fromJson({
      'rules': {'frequentMinLast3Months': 4, 'idleMonths': 12},
      'activeCount': 3,
      'learningCount': 1,
      'neverPlayedCount': 1,
      'usedInLast': {'months3': 1, 'months6': 2, 'months12': 2},
      'frequent': [
        {
          'songId': 's1',
          'title': 'Pão da Vida',
          'hymnRef': '142 CC',
          'lastPlayedAt': '2026-09-07T12:00:00.000Z',
          'playCount': 6,
          'last3Months': 4,
        },
      ],
      'idle': [],
      'learning': [],
      'missingKey': [],
      'missingReference': [],
    });

    expect(health.activeCount, 3);
    expect(health.usedInLast6Months, 2);
    expect(health.frequentMinLast3Months, 4);
    expect(health.frequent.single.displayTitle, '142 CC · Pão da Vida');
    expect(health.frequent.single.last3Months, 4);
  });

  test('Home: o atalho de músicas novas diz quantas, sem inventar zero', () {
    expect(learningShortcutSubtitle(3), '3 para estudar');
    expect(learningShortcutSubtitle(1), '1 para estudar');
    expect(learningShortcutSubtitle(0), 'Nada novo agora');
    // Carregando ou com falha: legenda genérica, e não um zero que ninguém
    // contou.
    expect(learningShortcutSubtitle(null), 'Para estudar');
  });
}
