import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/songs/data/song_repository.dart';
import 'package:louvor_app/features/songs/domain/song_models.dart';
import 'package:louvor_app/features/songs/domain/song_themes.dart';
import 'package:louvor_app/features/songs/presentation/song_theme_picker.dart';

/// O tema é o que a igreja pergunta antes de montar o culto ("o que temos para
/// a Ceia?"). Estes testes seguram três coisas que quebram caladas:
///
/// - o vocabulário, que precisa continuar espelhando o enum do servidor;
/// - a busca sem acento, sem a qual "gracas" não acha "Ações de Graças";
/// - a combinação com os filtros que já existiam -- tema **soma**, não
///   substitui.
class _RepositorioFake extends SongRepository {
  _RepositorioFake(this.songs) : super(Dio());

  final List<Song> songs;

  /// Últimos temas que a tela mandou ao servidor. É o que prova que o filtro
  /// viaja na consulta em vez de ser peneirado depois.
  Set<String> ultimosTemas = const {};

  @override
  Future<List<Song>> list(
    String teamId, {
    String? search,
    bool includeArchived = false,
    Set<String> themes = const {},
  }) async {
    ultimosTemas = themes;
    return themes.isEmpty
        ? songs
        : songs.where((s) => s.themes.any(themes.contains)).toList();
  }
}

Song musica(
  String title, {
  List<String> themes = const [],
  int? hymnNumber,
  bool isNew = false,
}) =>
    Song(
      id: 'id-$title',
      title: title,
      themes: themes,
      hymnNumber: hymnNumber,
      isNew: isNew,
    );

void main() {
  group('catálogo de temas', () {
    test('tem os 82 temas do índice, sem repetir rótulo', () {
      expect(songThemes.length, 82);
      expect(songThemes.values.toSet().length, 82);
    });

    test('a chave é o valor do enum do servidor, não o rótulo', () {
      // MAIÚSCULAS, sem acento e com "_" no lugar do espaço: é assim que o
      // Postgres guarda, e mandar o rótulo faria o servidor responder 400.
      for (final value in songThemeValues) {
        expect(
          RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(value),
          isTrue,
          reason: '$value não tem a forma de um valor de enum',
        );
      }
      expect(songThemes['ACOES_DE_GRACAS'], 'Ações de Graças');
      expect(songThemes['UNIAO_COM_CRISTO'], 'União com Cristo');
    });

    test('a ordem é a alfabética do índice impresso', () {
      expect(songThemeValues.first, 'ACOES_DE_GRACAS');
      expect(songThemeValues.last, 'VIDA_ETERNA');
    });

    test('tema que este app ainda não conhece vira rótulo legível', () {
      // Migration aplicada no servidor, APK antigo no celular do músico: a
      // etiqueta continua aparecendo, sem acento, em vez de a música parecer
      // não classificada.
      expect(songThemeLabel('BATISMO_DE_FOGO'), 'Batismo De Fogo');
      expect(songThemeLabel('CEIA'), 'Ceia');
    });
  });

  group('busca de tema', () {
    test('sem busca, mostra o vocabulário inteiro', () {
      expect(searchSongThemes('').length, 82);
      expect(searchSongThemes('   ').length, 82);
    });

    test('acha sem acento e por trecho, que é como se digita no celular', () {
      expect(searchSongThemes('gracas'), contains('ACOES_DE_GRACAS'));
      expect(searchSongThemes('espirito'), contains('ESPIRITO_SANTO'));
      expect(searchSongThemes('PASCOA'), contains('PASCOA'));
      // Trecho no meio do nome também vale: "vinda" acha "Segunda Vinda".
      expect(searchSongThemes('vinda'), contains('SEGUNDA_VINDA'));
    });

    test('"deus" traz os vários temas que falam dele, não só um', () {
      final resultado = searchSongThemes('deus');
      expect(resultado, contains('DEUS'));
      expect(resultado, contains('BONDADE_DE_DEUS'));
      expect(resultado, contains('PODER_DE_DEUS'));
      expect(resultado.length, greaterThan(5));
    });

    test('nome que não existe devolve vazio, e não a lista inteira', () {
      expect(searchSongThemes('zzz'), isEmpty);
    });
  });

  group('Song', () {
    test('lê os temas do JSON; ausente é lista vazia', () {
      final classificada = Song.fromJson({
        'id': 's1',
        'title': 'Consagração',
        'themes': ['ENTREGA', 'CONSAGRACAO_INEXISTENTE'],
      });
      // O app não filtra o que o servidor mandou: valor desconhecido continua
      // na lista e ganha rótulo legível na tela.
      expect(classificada.themes, ['ENTREGA', 'CONSAGRACAO_INEXISTENTE']);

      // Ausente vale vazio: é o que o cache gravado antes desta versão guarda.
      final semTema = Song.fromJson({'id': 's2', 'title': 'Qualquer'});
      expect(semTema.themes, isEmpty);
    });
  });

  group('SongQuery', () {
    test('o mesmo conjunto de temas é a mesma chave, em qualquer ordem', () {
      // Sem isto, cada reconstrução da tela viraria uma consulta nova: `Set`
      // não tem igualdade estrutural em Dart.
      const a = SongQuery(teamId: 't1', themes: {'CEIA', 'ADORACAO'});
      const b = SongQuery(teamId: 't1', themes: {'ADORACAO', 'CEIA'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('temas diferentes são consultas diferentes', () {
      const a = SongQuery(teamId: 't1', themes: {'CEIA'});
      const b = SongQuery(teamId: 't1', themes: {'CEIA', 'ADORACAO'});
      const semTema = SongQuery(teamId: 't1');
      expect(a == b, isFalse);
      expect(a == semTema, isFalse);
    });
  });

  group('filtro por tema na lista', () {
    final acervo = [
      musica('Santo Espírito', themes: ['ESPIRITO_SANTO', 'ADORACAO']),
      musica('Teu Sangue', themes: ['CEIA', 'SANGUE_DE_CRISTO']),
      musica('Noite Feliz', hymnNumber: 30, themes: ['NATAL', 'ENCARNACAO']),
      musica('Pão da Vida', hymnNumber: 142, themes: ['CEIA']),
      musica('Sem tema nenhum'),
    ];

    Future<(List<Song>, _RepositorioFake)> filtrar(
      SongFilter filtro,
      Set<String> temas,
    ) async {
      final repositorio = _RepositorioFake(acervo);
      final container = ProviderContainer(
        overrides: [
          songRepositoryProvider.overrideWithValue(repositorio),
        ],
      );
      addTearDown(container.dispose);

      final lista = await container.read(
        songsProvider(
          SongQuery(teamId: 't1', filter: filtro, themes: temas),
        ).future,
      );
      return (lista, repositorio);
    }

    test('os temas viajam na consulta, não são peneirados depois', () async {
      final (_, repositorio) = await filtrar(SongFilter.canticos, {'CEIA'});
      expect(repositorio.ultimosTemas, {'CEIA'});
    });

    test('dois temas marcados são um OU, não um E', () async {
      // Com E, "Natal" mais "Ceia" -- duas datas que não caem no mesmo culto
      // -- devolveria zero, e o filtro pareceria quebrado.
      final (lista, _) = await filtrar(SongFilter.hinos, {'NATAL', 'CEIA'});
      expect(lista.map((s) => s.title), ['Noite Feliz', 'Pão da Vida']);
    });

    test('o tema soma à aba em vez de substituí-la', () async {
      // "Ceia" tem um cântico e um hino; em Hinos só o hino aparece.
      final (hinos, _) = await filtrar(SongFilter.hinos, {'CEIA'});
      expect(hinos.map((s) => s.title), ['Pão da Vida']);

      final (canticos, _) = await filtrar(SongFilter.canticos, {'CEIA'});
      expect(canticos.map((s) => s.title), ['Teu Sangue']);
    });

    test('sem tema marcado, nada muda no que já existia', () async {
      final (lista, repositorio) = await filtrar(SongFilter.canticos, {});
      expect(repositorio.ultimosTemas, isEmpty);
      expect(lista.length, 3); // os três que não são hino
    });
  });

  group('seletor de temas', () {
    /// Abre o seletor e devolve o que ele entregou.
    Future<Set<String>?> abrir(
      WidgetTester tester, {
      Set<String> selecionados = const {},
      required Future<void> Function(WidgetTester tester) interagir,
    }) async {
      Set<String>? resultado;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  resultado = await showSongThemePicker(
                    context,
                    selected: selecionados,
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await interagir(tester);
      return resultado;
    }

    testWidgets('mostra o vocabulário sem exigir busca', (tester) async {
      await abrir(
        tester,
        interagir: (tester) async {
          // A lista aparece inteira: quem não sabe o nome do tema precisa vê-lo
          // para poder escolher.
          expect(find.text('Adoração'), findsOneWidget);
          expect(find.text('Ceia'), findsOneWidget);
          // E o teclado não rouba a tela na abertura.
          expect(
            tester.testTextInput.isVisible,
            isFalse,
            reason: 'o campo de busca não deve tomar foco sozinho',
          );
        },
      );
    });

    testWidgets('busca sem acento e marca o tema encontrado', (tester) async {
      final resultado = await abrir(
        tester,
        interagir: (tester) async {
          await tester.enterText(find.byType(TextField), 'gracas');
          await tester.pumpAndSettle();

          expect(find.text('Ações de Graças'), findsOneWidget);
          expect(find.text('Adoração'), findsNothing);

          await tester.tap(find.text('Ações de Graças'));
          await tester.pumpAndSettle();

          // O botão conta o que está marcado.
          expect(find.text('Pronto · 1 tema'), findsOneWidget);
          await tester.tap(find.text('Pronto · 1 tema'));
          await tester.pumpAndSettle();
        },
      );

      expect(resultado, {'ACOES_DE_GRACAS'});
    });

    testWidgets('fechar pelo botão voltar aplica o que foi marcado', (
      tester,
    ) async {
      // Arrastar a folha para baixo e apertar voltar são o mesmo gesto de
      // "terminei". Descartar cinco toques por causa disso seria um castigo
      // que ninguém entende -- e aqui não há nada destrutivo a confirmar.
      final resultado = await abrir(
        tester,
        interagir: (tester) async {
          await tester.tap(find.text('Ceia'));
          await tester.pumpAndSettle();

          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        },
      );

      expect(resultado, {'CEIA'});
    });

    testWidgets('o que já estava marcado volta marcado, e desmarca', (
      tester,
    ) async {
      final resultado = await abrir(
        tester,
        selecionados: {'CEIA', 'NATAL'},
        interagir: (tester) async {
          expect(find.text('Escolhidos'), findsOneWidget);
          expect(find.text('Pronto · 2 temas'), findsOneWidget);

          // "Limpar" tira todos de uma vez -- é o caminho de quem errou a
          // pergunta inteira, não uma etiqueta.
          await tester.tap(find.text('Limpar'));
          await tester.pumpAndSettle();

          expect(find.text('Pronto'), findsOneWidget);
          await tester.tap(find.text('Pronto'));
          await tester.pumpAndSettle();
        },
      );

      expect(resultado, isEmpty);
    });
  });
}
