import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/songs/domain/song_history.dart';

/// O histórico da música dito em português.
///
/// A regra da tela é "frase, e não métrica": quem monta a escala lê "Cantada
/// há 12 dias", e não "12d". Estes testes travam a redação e os cortes — até
/// cinco meses o foco é quando; a partir de seis, a ausência.
void main() {
  final hoje = DateTime(2026, 9, 14, 10);

  group('a última vez', () {
    test('perto, conta os dias; ontem é ontem', () {
      expect(lastPlayedPhrase(DateTime(2026, 9, 14, 8), hoje), 'Cantada hoje');
      // Domingo à noite ainda é "ontem" na segunda de manhã, embora não
      // tenham passado 24 horas.
      expect(lastPlayedPhrase(DateTime(2026, 9, 13, 19), hoje), 'Cantada ontem');
      expect(
        lastPlayedPhrase(DateTime(2026, 9, 2, 10), hoje),
        'Cantada há 12 dias',
      );
    });

    test('depois de um mês, semanas; depois de dois, meses', () {
      expect(
        lastPlayedPhrase(DateTime(2026, 8, 10, 10), hoje),
        'Cantada há 5 semanas',
      );
      expect(
        lastPlayedPhrase(DateTime(2026, 6, 10, 10), hoje),
        'Cantada há 3 meses',
      );
    });

    test('a partir de seis meses, a frase vira a ausência', () {
      expect(
        lastPlayedPhrase(DateTime(2026, 1, 10, 10), hoje),
        'Há 8 meses sem cantar',
      );
      expect(
        lastPlayedPhrase(DateTime(2025, 7, 1, 10), hoje),
        'Há mais de um ano sem cantar',
      );
      expect(
        lastPlayedPhrase(DateTime(2024, 3, 1, 10), hoje),
        'Há mais de 2 anos sem cantar',
      );
    });

    test('nunca cantada não vira frase', () {
      expect(lastPlayedPhrase(null, hoje), isNull);
    });
  });

  test('como motivo de sugestão, o descanso sai sem o "Há"', () {
    expect(restPhrase(DateTime(2026, 5, 10, 10), hoje), '4 meses sem cantar');
    expect(restPhrase(DateTime(2026, 8, 3, 10), hoje), '6 semanas sem cantar');
    expect(restPhrase(DateTime(2026, 9, 10, 10), hoje), isNull);
  });

  test('recente é até três semanas', () {
    expect(isRecentlyPlayed(DateTime(2026, 9, 2, 10), hoje), isTrue);
    expect(isRecentlyPlayed(DateTime(2026, 8, 10, 10), hoje), isFalse);
    expect(isRecentlyPlayed(null, hoje), isFalse);
  });

  test('a contagem só aparece a partir de duas vezes', () {
    expect(recentCountPhrase(3), '3 vezes em 6 meses');
    expect(recentCountPhrase(1), isNull);
    expect(recentCountPhrase(0), isNull);
  });

  test('os momentos de costume, com o nome escrito em "Outro"', () {
    final history = SongHistory.fromJson({
      'songId': 's1',
      'lastPlayedAt': '2026-09-02T12:00:00.000Z',
      'playCount': 9,
      'last3Months': 2,
      'last6Months': 4,
      'last12Months': 9,
      'moments': [
        {'moment': 'LOUVOR', 'label': null, 'count': 7},
        {'moment': 'OUTRO', 'label': 'Santa Ceia', 'count': 1},
        {'moment': 'ABERTURA', 'label': null, 'count': 1},
      ],
    });

    expect(history.playCount, 9);
    expect(history.last6Months, 4);
    expect(
      usualMomentsPhrase(history.moments),
      'Momento de Louvor (7 vezes) · Santa Ceia (1 vez)',
    );
    expect(usualMomentsPhrase(const []), isNull);
  });
}
