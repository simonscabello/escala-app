import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/core/theme/app_theme.dart';
import 'package:louvor_app/features/auth/application/auth_controller.dart';
import 'package:louvor_app/features/auth/domain/auth_models.dart';
import 'package:louvor_app/features/suggestions/data/suggestion_repository.dart';
import 'package:louvor_app/features/suggestions/domain/song_suggestion.dart';
import 'package:louvor_app/features/suggestions/presentation/suggestion_detail_screen.dart';

/// A tela de detalhes da sugestão.
///
/// Ela é o lugar onde a sugestão é lida inteira e respondida — a lista virou
/// índice justamente para isto caber aqui. O que estes testes protegem: só o
/// material que existe vira botão, o motivo aparece sem cortar, as decisões só
/// existem para quem pode decidir, e o nome de quem resolveu não vaza.
class _RepositorioFake extends SuggestionRepository {
  _RepositorioFake(this._suggestion) : super(Dio());

  final SongSuggestion _suggestion;

  String? aceitaComSongId;
  bool chamouAceitar = false;

  @override
  Future<SongSuggestion> find(String teamId, String id) async => _suggestion;

  @override
  Future<SongSuggestion> accept(
    String teamId,
    String id, {
    String? songId,
  }) async {
    chamouAceitar = true;
    aceitaComSongId = songId;
    return _suggestion;
  }
}

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

SongSuggestion _sugestao({
  String status = 'PENDING',
  String? songId,
  String? lyricsUrl = 'https://www.cifraclub.com.br/x/',
  String? spotifyUrl,
  String? youtubeUrl,
  String? declineReason,
  String? targetDate,
  List<String> alsoSuggestedBy = const [],
}) =>
    SongSuggestion.fromJson({
      'id': 'sg1',
      'songId': songId,
      'title': 'Bondade de Deus',
      'artist': 'Isaías Saad',
      'lyricsUrl': lyricsUrl,
      'spotifyUrl': spotifyUrl,
      'youtubeUrl': youtubeUrl,
      'targetDate': targetDate,
      'reason': 'A igreja já canta essa nos cultos de oração e a letra fala '
          'exatamente do que o pastor tem pregado neste mês.',
      'status': status,
      'declineReason': declineReason,
      'inRepertoire': songId != null,
      'createdBy': {
        'membershipId': 'm-maria',
        'displayName': 'Maria',
        'avatarUrl': null,
      },
      'createdAt': '2026-09-03T12:00:00.000Z',
      'alsoSuggestedBy': alsoSuggestedBy,
    });

Future<_RepositorioFake> _montar(
  WidgetTester tester, {
  required SongSuggestion suggestion,
  String role = 'OWNER',
  ThemeData? theme,
  Size size = const Size(375 * 3, 812 * 3),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final repositorio = _RepositorioFake(suggestion);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        suggestionRepositoryProvider.overrideWithValue(repositorio),
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
                  membershipId: 'm-simon',
                  teamId: 't1',
                  name: 'Louvor SIBB',
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
        home: SuggestionDetailScreen(
          teamId: 't1',
          suggestionId: 'sg1',
          initial: suggestion,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repositorio;
}

void main() {
  testWidgets('mostra a música, o motivo inteiro e quem sugeriu',
      (tester) async {
    await _montar(tester, suggestion: _sugestao());

    expect(find.text('Bondade de Deus'), findsOneWidget);
    expect(find.text('Isaías Saad'), findsOneWidget);
    // O motivo é o conteúdo da sugestão: aqui ele não é cortado.
    expect(
      find.textContaining('exatamente do que o pastor tem pregado'),
      findsOneWidget,
    );
    expect(find.text('Sugerida por Maria'), findsOneWidget);
    expect(find.text('Para o repertório'), findsOneWidget);
  });

  testWidgets('só os links que existem viram botão', (tester) async {
    await _montar(
      tester,
      suggestion: _sugestao(youtubeUrl: 'https://youtu.be/x'),
    );

    expect(find.widgetWithText(ActionChip, 'Letra ou cifra'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'YouTube'), findsOneWidget);
    // Link que ninguém mandou não vira botão apagado: promessa falsa.
    expect(find.widgetWithText(ActionChip, 'Spotify'), findsNothing);
  });

  testWidgets('sem link nenhum, a faixa de materiais some', (tester) async {
    await _montar(tester, suggestion: _sugestao(lyricsUrl: null));

    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('as decisões são de quem lidera', (tester) async {
    await _montar(tester, suggestion: _sugestao(), role: 'MEMBER');

    expect(find.text('Aceitar sugestão'), findsNothing);
    expect(find.text('Recusar'), findsNothing);
    // Quem sugeriu continua lendo a própria sugestão -- é para isso que a tela
    // é de todo mundo.
    expect(find.textContaining('A igreja já canta'), findsOneWidget);
  });

  testWidgets('música já no repertório: aceitar é um toque só', (tester) async {
    final repositorio = await _montar(
      tester,
      suggestion: _sugestao(songId: 's1'),
    );

    expect(find.text('Já está no repertório'), findsOneWidget);

    await tester.tap(find.text('Aceitar sugestão'));
    await tester.pumpAndSettle();

    // Nenhum diálogo de cadastro pelo caminho: a música já existe.
    expect(repositorio.chamouAceitar, isTrue);
    expect(repositorio.aceitaComSongId, 's1');
  });

  testWidgets('sem cadastro, aceitar oferece adicionar ao repertório',
      (tester) async {
    final repositorio = await _montar(tester, suggestion: _sugestao());

    await tester.tap(find.text('Aceitar sugestão'));
    await tester.pumpAndSettle();

    expect(find.text('Adicionar ao repertório?'), findsOneWidget);

    // Desistir não aceita nada: acolher uma música que ninguém cadastrou
    // deixaria a sugestão acolhida apontando para o vazio.
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repositorio.chamouAceitar, isFalse);
  });

  testWidgets('encerrada mostra a resposta e o caminho de volta',
      (tester) async {
    await _montar(
      tester,
      suggestion: _sugestao(
        status: 'DECLINED',
        declineReason: 'Já temos duas músicas novas neste mês.',
      ),
    );

    expect(find.text('Recusada'), findsOneWidget);
    expect(find.text('Já temos duas músicas novas neste mês.'), findsOneWidget);
    // Reabrir existe para o toque errado não virar beco sem saída.
    expect(find.text('Reabrir'), findsOneWidget);
    expect(find.text('Aceitar sugestão'), findsNothing);
  });

  testWidgets('recusa sem motivo não desenha caixa vazia', (tester) async {
    await _montar(tester, suggestion: _sugestao(status: 'DECLINED'));

    // Campo em branco é uso legítimo: às vezes o motivo certo é uma conversa
    // pessoal, e o app não é o canal.
    expect(find.text('Resposta'), findsNothing);
  });

  testWidgets('cabe no celular estreito e no tema escuro', (tester) async {
    // 320dp é o mais apertado que ainda existe em uso. Um `Row` que não coube
    // vira exceção de overflow e derruba este teste -- que é exatamente o
    // aviso que não chega de outro jeito antes do aparelho.
    await _montar(
      tester,
      suggestion: _sugestao(
        targetDate: '2026-09-13',
        spotifyUrl: 'https://open.spotify.com/track/x',
        youtubeUrl: 'https://youtu.be/x',
        alsoSuggestedBy: const ['Ana', 'João', 'Pedro'],
      ),
      theme: AppTheme.dark,
      size: const Size(320 * 3, 640 * 3),
    );

    expect(tester.takeException(), isNull);

    // As decisões ficam no fim da página, depois do motivo — é a ordem em que
    // a decisão acontece de verdade —, então aqui se rola até elas.
    await tester.scrollUntilVisible(
      find.text('Recusar'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Aceitar sugestão'), findsOneWidget);
    expect(find.text('Recusar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quem resolveu não aparece; quem mais sugeriu, sim',
      (tester) async {
    await _montar(
      tester,
      suggestion: _sugestao(alsoSuggestedBy: const ['Ana', 'João']),
    );

    expect(
      find.text('Sugerida por Maria · Ana e João também sugeriram'),
      findsOneWidget,
    );
    // Recusa com o nome do líder do lado azeda a equipe.
    expect(find.textContaining('Simon'), findsNothing);
  });
}
