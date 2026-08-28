import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/songs/data/song_repository.dart';
import 'package:louvor_app/features/songs/domain/song_models.dart';

/// O repertorio virou dois acervos: 581 hinos do Cantor Cristao ao lado de 280
/// canticos. O que estes testes protegem e a separacao -- sem ela, dois tercos
/// de tudo o que se rola e hino, e procurar um cantico vira garimpo.
class _RepositorioFake extends SongRepository {
  _RepositorioFake(this.songs) : super(Dio());

  final List<Song> songs;

  /// Faz o papel do servidor, inclusive no filtro por tema: ele acontece na
  /// consulta (`hasSome`), e nao na lista ja recebida, entao um fake que
  /// devolvesse tudo esconderia justamente o que o `SongQuery` precisa levar
  /// ate la.
  @override
  Future<List<Song>> list(
    String teamId, {
    String? search,
    bool includeArchived = false,
    Set<String> themes = const {},
  }) async =>
      themes.isEmpty
          ? songs
          : songs.where((s) => s.themes.any(themes.contains)).toList();
}

Song cantico(
  String title, {
  bool isNew = false,
  List<String> themes = const [],
}) =>
    Song(
      id: 'c-$title',
      title: title,
      artist: 'Aline Barros',
      isNew: isNew,
      themes: themes,
    );

Song hino(
  int numero,
  String title, {
  bool isNew = false,
  List<String> themes = const [],
}) =>
    Song(
      id: 'h-$numero',
      title: title,
      artist: 'Cantor Cristão',
      kind: 'HYMN',
      hymnNumber: numero,
      isNew: isNew,
      themes: themes,
    );

Future<List<Song>> filtrar(
  List<Song> acervo,
  SongFilter filtro, {
  Set<String> themes = const {},
}) async {
  final container = ProviderContainer(
    overrides: [
      songRepositoryProvider.overrideWithValue(_RepositorioFake(acervo)),
    ],
  );
  addTearDown(container.dispose);

  return container.read(
    songsProvider(
      SongQuery(teamId: 't1', filter: filtro, themes: themes),
    ).future,
  );
}

void main() {
  final acervo = [
    cantico('Consagração'),
    hino(142, 'Pão da Vida'),
    hino(1, 'Antífona'),
    cantico('Bondade de Deus', isNew: true),
    hino(581, 'A Única Esperança', isNew: true),
    hino(93, 'Só No Sangue'),
  ];

  group('Song', () {
    test('o numero identifica o hino, e cantico nao tem numero', () {
      expect(hino(142, 'Pão da Vida').isHymn, isTrue);
      expect(hino(142, 'Pão da Vida').hymnNumber, 142);
      expect(cantico('Consagração').isHymn, isFalse);
      expect(cantico('Consagração').hymnNumber, isNull);
    });

    test('le o numero do JSON, e ausente e cantico', () {
      final doServidor = Song.fromJson({
        'id': 's1',
        'title': 'Pão da Vida',
        'hymnNumber': 142,
      });
      expect(doServidor.isHymn, isTrue);
      expect(doServidor.hymnNumber, 142);

      final semNumero = Song.fromJson({'id': 's2', 'title': 'Consagração'});
      expect(semNumero.isHymn, isFalse);
    });
  });

  group('separação dos acervos', () {
    test('Cânticos exclui os hinos', () async {
      final lista = await filtrar(acervo, SongFilter.canticos);

      expect(lista.map((s) => s.title), ['Consagração', 'Bondade de Deus']);
      expect(lista.any((s) => s.isHymn), isFalse);
    });

    test('Hinos traz só hinos, e em ordem de número', () async {
      final lista = await filtrar(acervo, SongFilter.hinos);

      // Ordem do hinario impresso, e nao alfabetica: e assim que se procura um
      // hino que se sabe de cor pelo numero.
      expect(lista.map((s) => s.hymnNumber), [1, 93, 142, 581]);
      expect(lista.every((s) => s.isHymn), isTrue);
    });

    test('Novas atravessa os dois acervos', () async {
      final lista = await filtrar(acervo, SongFilter.novas);

      // Um hino pode estar sendo aprendido tanto quanto um cantico -- separar
      // aqui obrigaria a equipe a olhar em dois lugares antes do ensaio.
      expect(
        lista.map((s) => s.title),
        containsAll(<String>['Bondade de Deus', 'A Única Esperança']),
      );
      expect(lista, hasLength(2));
    });
  });
}
