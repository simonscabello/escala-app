import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/songs/domain/musical_keys.dart';

/// A lista fechada de tons.
///
/// O que ela precisa garantir: o formato que o sistema já gravava (e que o
/// CifraClub devolve) continua valendo, as duas grafias das teclas pretas
/// existem, e a anotação antiga não vira outro tom por adivinhação.
void main() {
  group('musicalKeys', () {
    test('17 maiores e os mesmos 17 em menor', () {
      expect(musicalKeys, hasLength(34));
      expect(musicalKeys.where(isMinorKey), hasLength(17));
      expect(musicalKeys.toSet(), hasLength(34));
    });

    test('sustenido e bemol nas teclas pretas', () {
      for (final key in ['C#', 'Db', 'D#', 'Eb', 'F#', 'Gb', 'G#', 'Ab']) {
        expect(musicalKeys, contains(key));
        expect(musicalKeys, contains('${key}m'));
      }
      expect(musicalKeys, containsAll(['A#', 'Bb', 'Bbm', 'A#m']));
    });

    test('sem os nomes alternativos das teclas brancas', () {
      for (final key in ['E#', 'B#', 'Fb', 'Cb', 'E#m', 'Cbm']) {
        expect(musicalKeys, isNot(contains(key)));
      }
    });

    test('tudo na lista cabe no formato que o backend lê do CifraClub', () {
      final cifraClub = RegExp(r'^[A-G][#b]?m?$');
      expect(musicalKeys.every(cifraClub.hasMatch), isTrue);
    });
  });

  group('normalizeMusicalKey', () {
    test('devolve o tom na grafia da lista', () {
      expect(normalizeMusicalKey('G'), 'G');
      expect(normalizeMusicalKey('Bbm'), 'Bbm');
      expect(normalizeMusicalKey(' F# '), 'F#');
    });

    test('conserta só a caixa da letra, que era o erro do campo livre', () {
      expect(normalizeMusicalKey('g'), 'G');
      expect(normalizeMusicalKey('f#m'), 'F#m');
      expect(normalizeMusicalKey('bb'), 'Bb');
    });

    test('anotação fora da lista não vira tom nenhum', () {
      expect(normalizeMusicalKey('G (capo 2)'), isNull);
      expect(normalizeMusicalKey('Sol'), isNull);
      expect(normalizeMusicalKey('E#'), isNull);
      expect(normalizeMusicalKey('CM'), isNull);
      expect(normalizeMusicalKey(''), isNull);
      expect(normalizeMusicalKey(null), isNull);
    });
  });

  test('o leitor de tela diz o tom por extenso', () {
    expect(musicalKeySpokenLabel('C#m'), 'C sustenido menor');
    expect(musicalKeySpokenLabel('Bb'), 'B bemol maior');
    expect(musicalKeySpokenLabel('A'), 'A maior');
  });
}
