import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/songs/data/song_repository.dart';
import 'package:louvor_app/features/songs/domain/song_models.dart';
import 'package:louvor_app/features/songs/domain/song_sections.dart';

Song cantico(String title) => Song(id: title, title: title);

Song hino(int numero) =>
    Song(id: 'h$numero', title: 'Hino $numero', hymnNumber: numero);

/// Só os rótulos dos marcadores, na ordem em que aparecem.
List<String> headers(List<SongSectionEntry> entries) => [
      for (final e in entries)
        if (e is SongSectionHeader) e.label,
    ];

/// Só os títulos, na ordem em que a lista os desenha.
List<String> titles(List<SongSectionEntry> entries) => [
      for (final e in entries)
        if (e is SongSectionItem) e.song.title,
    ];

/// Uma lista comprida o bastante para o agrupamento ligar.
List<Song> muitos(List<String> titulos) => [
      for (final t in titulos) cantico(t),
      for (var i = 0; i < 20; i++) cantico('Zzz $i'),
    ];

void main() {
  group('quando agrupar', () {
    test('lista curta nao ganha marcador', () {
      final entries = buildSongSections(
        [cantico('Amor'), cantico('Bondade')],
        filter: SongFilter.canticos,
        searching: false,
      );

      expect(headers(entries), isEmpty);
      expect(titles(entries), ['Amor', 'Bondade']);
    });

    test('buscando nao ganha marcador, e a ordem do servidor e mantida', () {
      // O servidor devolve por relevância; reordenar aqui destruiria isso.
      final resultado = muitos(['Oferta de Amor', 'Aleluia', 'Bondade']);

      final entries = buildSongSections(
        resultado,
        filter: SongFilter.canticos,
        searching: true,
      );

      expect(headers(entries), isEmpty);
      expect(titles(entries).first, 'Oferta de Amor');
    });

    test('lista longa ganha marcador por letra', () {
      final entries = buildSongSections(
        muitos(['Amor', 'Aleluia', 'Bondade']),
        filter: SongFilter.canticos,
        searching: false,
      );

      expect(headers(entries), ['A', 'B', 'Z']);
    });
  });

  group('ordem alfabetica', () {
    test('acento nao joga a musica para o fim da lista', () {
      // Sem normalizar, "Água" cai depois de "Zelo": o código de "á" é maior
      // que o de qualquer letra sem acento.
      final entries = buildSongSections(
        muitos(['Zelo', 'Água', 'Amor']),
        filter: SongFilter.canticos,
        searching: false,
      );

      expect(titles(entries).take(2), ['Água', 'Amor']);
      expect(headers(entries).first, 'A');
    });

    test('a mesma letra aparece uma vez so', () {
      // O cabeçalho repetido era o risco de confiar na ordem que veio pronta.
      final entries = buildSongSections(
        muitos(['Amor', 'Bondade', 'Aleluia', 'Bênção', 'Água']),
        filter: SongFilter.canticos,
        searching: false,
      );

      final letras = headers(entries);
      expect(letras.toSet().length, letras.length, reason: '$letras');
    });

    test('titulo que nao comeca com letra vai para "#"', () {
      final entries = buildSongSections(
        muitos(['1 Coríntios 13', 'Amor']),
        filter: SongFilter.canticos,
        searching: false,
      );

      expect(headers(entries), contains('#'));
    });
  });

  group('hinos', () {
    test('agrupam por centena e nao por letra', () {
      final entries = buildSongSections(
        [for (var n = 1; n <= 250; n += 10) hino(n)],
        filter: SongFilter.hinos,
        searching: false,
      );

      expect(headers(entries), ['1 – 99', '100 – 199', '200 – 299']);
    });

    test('a ordem numerica do provider e preservada', () {
      final entries = buildSongSections(
        [for (var n = 1; n <= 120; n += 5) hino(n)],
        filter: SongFilter.hinos,
        searching: false,
      );

      final numeros = [
        for (final e in entries)
          if (e is SongSectionItem) e.song.hymnNumber!,
      ];

      expect(numeros, orderedEquals([...numeros]..sort()));
    });
  });

  test('lista vazia devolve vazio, sem marcador solto', () {
    expect(
      buildSongSections(const [], filter: SongFilter.hinos, searching: false),
      isEmpty,
    );
  });
}
