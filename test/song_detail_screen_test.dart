import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/core/theme/app_theme.dart';
import 'package:louvor_app/features/auth/application/auth_controller.dart';
import 'package:louvor_app/features/auth/domain/auth_models.dart';
import 'package:louvor_app/features/songs/data/song_repository.dart';
import 'package:louvor_app/features/songs/domain/song_history.dart';
import 'package:louvor_app/features/songs/domain/song_models.dart';
import 'package:louvor_app/features/songs/presentation/song_detail_screen.dart';
import 'package:louvor_app/shared/widgets/section_header.dart';

/// A tela de uma música do repertório.
///
/// O que estes testes protegem: a ordem da leitura (o que a música é, como
/// ensaiar, a letra, e por último o uso nas escalas), as quatro portas de
/// preparação sempre no mesmo lugar, a letra comprida em prévia sem perder o
/// texto inteiro — e nenhum estouro de layout do celular pequeno ao monitor.
class _FakeAuthController extends AuthController {
  _FakeAuthController(super.ref, this._initial) {
    state = _initial;
  }

  final AuthState _initial;

  @override
  Future<void> bootstrap() async {
    state = _initial;
  }
}

final _letraLonga = List.generate(
  24,
  (i) => i.isOdd ? '' : 'Há paz que cobre as trevas, verso ${i ~/ 2 + 1}',
).join('\n');

Song _musica({
  String? defaultKey = 'A',
  String? lyrics,
  String? lyricsUrl,
  String? chordsUrl = 'https://www.cifraclub.com.br/novo-canto/cristo-venceu/',
  String? youtubeUrl,
  String? spotifyUrl = 'https://open.spotify.com/track/x',
  List<String> themes = const ['CRUZ', 'DEPENDENCIA_DE_DEUS', 'FE'],
}) =>
    Song.fromJson({
      'id': 's1',
      'title': 'Cristo Venceu',
      'artist': 'Novo Canto',
      'kind': 'SONG',
      'pace': 'MODERATE',
      'defaultKey': defaultKey,
      'originalKey': 'G',
      'lyrics': lyrics,
      'lyricsUrl': lyricsUrl,
      'chordsUrl': chordsUrl,
      'youtubeUrl': youtubeUrl,
      'spotifyUrl': spotifyUrl,
      'isNew': true,
      'themes': themes,
    });

Future<void> _abrir(
  WidgetTester tester, {
  required Song song,
  String role = 'LEADER',
  Map<String, SongHistory> history = const {},
  Size size = const Size(390, 844),
  ThemeData? theme,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        songProvider.overrideWith((ref, args) async => song),
        songHistoryProvider.overrideWith((ref, teamId) async => history),
        authControllerProvider.overrideWith(
          (ref) => _FakeAuthController(
            ref,
            AuthState.signedIn(
              const AuthUser(
                id: '1',
                name: 'Simon',
                email: 'simon@teste.com',
                mustChangePassword: false,
              ),
              [
                TeamSummary(
                  membershipId: 'm1',
                  teamId: 't1',
                  name: 'Louvor',
                  role: role,
                  displayName: 'Simon',
                ),
              ],
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: const SongDetailScreen(teamId: 't1', songId: 's1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _topo(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder).dy;

/// O título de um bloco, e não o texto solto: "Preparação" e "Uso nas escalas"
/// têm cabeçalho próprio, e "Letra" é também o nome de uma das portas.
Finder _secao(String titulo) => find.widgetWithText(SectionHeader, titulo);

void main() {
  testWidgets('a ordem da leitura: fatos, preparação, letra e uso',
      (tester) async {
    await _abrir(
      tester,
      song: _musica(lyrics: _letraLonga),
      size: const Size(390, 3000),
    );

    expect(find.text('Cristo Venceu'), findsOneWidget);
    expect(find.text('NOVO CANTO'), findsOneWidget);
    expect(find.text('Nova'), findsOneWidget);
    expect(find.text('Cântico'), findsOneWidget);
    expect(find.text('Moderada'), findsOneWidget);
    expect(find.text('Cruz'), findsOneWidget);

    expect(
      _topo(tester, find.text('Tom')),
      lessThan(_topo(tester, _secao('Preparação'))),
    );
    expect(
      _topo(tester, _secao('Preparação')),
      lessThan(_topo(tester, find.text('Ver completa'))),
    );
    expect(
      _topo(tester, find.text('Ver completa')),
      lessThan(_topo(tester, _secao('Uso nas escalas'))),
    );
  });

  testWidgets('as quatro portas aparecem sempre; a que falta fica apagada',
      (tester) async {
    await _abrir(tester, song: _musica(), size: const Size(390, 2000));

    expect(find.text('Abrir cifra'), findsOneWidget);
    expect(find.text('Ouvir no Spotify'), findsOneWidget);
    // Sem letra e sem link de letra, sem YouTube: continuam no lugar.
    expect(find.text('Letra'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Sem link'), findsNWidgets(2));
  });

  testWidgets('letra só em link: a porta abre o site', (tester) async {
    await _abrir(
      tester,
      song: _musica(lyricsUrl: 'https://www.letras.mus.br/x/'),
      size: const Size(390, 2000),
    );

    expect(find.text('Abrir no site'), findsOneWidget);
    // Sem letra guardada não há bloco de letra.
    expect(find.text('Ver completa'), findsNothing);
  });

  testWidgets('letra comprida vira prévia e abre inteira', (tester) async {
    await _abrir(
      tester,
      song: _musica(
        lyrics: _letraLonga,
        lyricsUrl: 'https://www.letras.mus.br/x/',
      ),
      size: const Size(390, 2000),
    );

    expect(find.text('Ler no app'), findsOneWidget);
    expect(find.text('Ver completa'), findsOneWidget);

    await tester.tap(find.text('Ver completa'));
    await tester.pumpAndSettle();

    expect(find.byType(SongLyricsScreen), findsOneWidget);
    expect(find.textContaining('verso 12'), findsOneWidget);
    // O link do site continua a um toque, agora na tela da letra.
    expect(find.byTooltip('Abrir no site'), findsOneWidget);
  });

  testWidgets('a porta "Letra" abre a letra guardada', (tester) async {
    await _abrir(
      tester,
      song: _musica(lyrics: _letraLonga),
      size: const Size(390, 2000),
    );

    await tester.tap(find.text('Ler no app'));
    await tester.pumpAndSettle();

    expect(find.byType(SongLyricsScreen), findsOneWidget);
    expect(find.byTooltip('Abrir no site'), findsNothing);
  });

  testWidgets('letra curta aparece inteira, sem "Ver completa"',
      (tester) async {
    await _abrir(
      tester,
      song: _musica(lyrics: 'Cristo venceu\nA morte e o pecado'),
      size: const Size(390, 2000),
    );

    expect(find.text('Ver completa'), findsNothing);
    expect(find.text('Cristo venceu\nA morte e o pecado'), findsOneWidget);
  });

  testWidgets('uso nas escalas é de quem lidera', (tester) async {
    await _abrir(
      tester,
      song: _musica(),
      role: 'MEMBER',
      size: const Size(390, 2000),
    );

    expect(find.text('Uso nas escalas'), findsNothing);
    expect(find.byTooltip('Editar'), findsNothing);
  });

  testWidgets('uso nas escalas mostra o histórico quando há', (tester) async {
    await _abrir(
      tester,
      song: _musica(),
      size: const Size(390, 2000),
      history: {
        's1': SongHistory(
          songId: 's1',
          lastPlayedAt: DateTime.now().toUtc().subtract(const Duration(days: 3)),
          playCount: 5,
          last6Months: 2,
        ),
      },
    );

    expect(find.text('Cantada há 3 dias'), findsOneWidget);
    expect(find.text('Ainda não entrou em escala publicada'), findsNothing);
  });

  testWidgets('tom anotado antes da lista aparece como está', (tester) async {
    await _abrir(
      tester,
      song: _musica(defaultKey: 'G (capo 2)'),
      size: const Size(390, 2000),
    );

    expect(find.text('G (capo 2)'), findsOneWidget);
  });

  testWidgets('sem tom da equipe, a gravação aparece como sugestão',
      (tester) async {
    await _abrir(
      tester,
      song: _musica(defaultKey: null),
      size: const Size(390, 2000),
    );

    expect(find.text('gravação: G'), findsOneWidget);
  });

  group('sem estouro de layout', () {
    for (final (nome, size) in [
      ('celular pequeno', const Size(320, 640)),
      ('celular comum', const Size(360, 780)),
      ('celular grande', const Size(412, 915)),
      ('monitor', const Size(1280, 800)),
    ]) {
      for (final escuro in [false, true]) {
        for (final escala in [1.0, 1.3]) {
          testWidgets(
              '$nome, ${escuro ? 'escuro' : 'claro'}, fonte ${escala}x',
              (tester) async {
            await _abrir(
              tester,
              song: _musica(
                defaultKey: 'G (capo 2)',
                lyrics: _letraLonga,
                youtubeUrl: 'https://youtu.be/x',
              ),
              size: size,
              theme: escuro ? AppTheme.dark : AppTheme.light,
              textScale: escala,
            );

            await tester.drag(
              find.byType(ListView),
              const Offset(0, -2000),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
