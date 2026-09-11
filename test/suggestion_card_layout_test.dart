import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/core/theme/app_theme.dart';
import 'package:louvor_app/features/suggestions/domain/song_suggestion.dart';
import 'package:louvor_app/features/suggestions/presentation/suggestions_screen.dart';
import 'package:louvor_app/shared/widgets/app_card.dart';

/// O cartão da sugestão, no tamanho de um celular de verdade.
///
/// O cartão nasceu grande — justificativa inteira, dois botões de decisão — e
/// numa equipe ativa cada sugestão ocupava meia tela. Aqui se protege o que a
/// densidade comprou: quatro linhas curtas, nenhuma decisão de raspão, e o
/// cartão inteiro levando ao detalhe.
void main() {
  SongSuggestion sugestao({
    String status = 'PENDING',
    String? targetDate,
    String? lyricsUrl = 'https://www.cifraclub.com.br/x/',
    String? spotifyUrl,
    String? youtubeUrl,
    List<String> alsoSuggestedBy = const [],
  }) =>
      SongSuggestion.fromJson({
        'id': 'sg1',
        'songId': null,
        'title': 'Louvores e Honras',
        'artist': 'Guilherme Kerr',
        'lyricsUrl': lyricsUrl,
        'spotifyUrl': spotifyUrl,
        'youtubeUrl': youtubeUrl,
        'targetDate': targetDate,
        // Longa de propósito: é ela que precisa caber numa linha só.
        'reason': 'A igreja já canta essa nos cultos de oração e a letra fala '
            'exatamente do que o pastor tem pregado neste mês.',
        'status': status,
        'declineReason': null,
        'inRepertoire': false,
        'createdBy': {
          'membershipId': 'm1',
          'displayName': 'Você',
          'avatarUrl': null,
        },
        'createdAt': '2026-09-03T12:00:00.000Z',
        'alsoSuggestedBy': alsoSuggestedBy,
      });

  Future<void> montar(
    WidgetTester tester, {
    SongSuggestion? item,
    ThemeData? theme,
    Size size = const Size(375 * 3, 812 * 3),
  }) async {
    // Celular comum, e é nele que a densidade importa.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SuggestionCard(
                suggestion: item ?? sugestao(),
                teamId: 't1',
                isMine: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('o conteúdo não encosta na borda do cartão', (tester) async {
    await montar(tester);

    final cartao = tester.getTopLeft(find.byType(AppCard));
    final titulo = tester.getTopLeft(find.text('Louvores e Honras'));

    // Sem padding o título nascia em cima da borda e o Clip.antiAlias do canto
    // arredondado cortava o "L".
    expect(titulo.dx - cartao.dx, greaterThanOrEqualTo(12));
    expect(titulo.dy - cartao.dy, greaterThanOrEqualTo(8));
  });

  testWidgets('cabe em pouca altura: é índice, não é a sugestão inteira',
      (tester) async {
    await montar(tester);

    // Dezenas de sugestões precisam caber numa rolagem curta. O teto é generoso
    // de propósito — a fonte do ambiente de teste é mais larga que a do
    // aparelho —, mas o cartão antigo, com o motivo inteiro e dois botões,
    // passava com folga daqui.
    expect(tester.getSize(find.byType(AppCard)).height, lessThan(150));
  });

  testWidgets('o motivo é truncado numa linha', (tester) async {
    await montar(tester);

    final motivo = tester.widget<Text>(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').startsWith('A igreja já canta'),
      ),
    );
    expect(motivo.maxLines, 1);
    expect(motivo.overflow, TextOverflow.ellipsis);
  });

  testWidgets('nenhuma decisão no cartão: o toque abre os detalhes',
      (tester) async {
    await montar(tester);

    // Decidir de raspão numa lista é decidir sem ler o motivo, e o motivo é a
    // razão de o campo ser obrigatório.
    expect(find.text('Acolher'), findsNothing);
    expect(find.text('Aceitar sugestão'), findsNothing);
    expect(find.text('Por enquanto não'), findsNothing);
    expect(find.text('Recusar'), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);

    expect(tester.widget<AppCard>(find.byType(AppCard)).onTap, isNotNull);
  });

  testWidgets('os materiais viram pontinhos, e só os que existem',
      (tester) async {
    await montar(
      tester,
      item: sugestao(spotifyUrl: 'https://open.spotify.com/track/x'),
    );

    expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    expect(find.byIcon(Icons.headphones_rounded), findsOneWidget);
    // Link que ninguém mandou não vira ícone apagado: seria promessa falsa.
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsNothing);
  });

  testWidgets('sem material nenhum, não sobra ícone solto', (tester) async {
    await montar(tester, item: sugestao(lyricsUrl: null));

    expect(find.byType(SuggestionMaterialDots), findsOneWidget);
    expect(find.byIcon(Icons.article_outlined), findsNothing);
    expect(find.byIcon(Icons.headphones_rounded), findsNothing);
  });

  testWidgets('a data manda no selo; sem data, é o repertório', (tester) async {
    await montar(tester, item: sugestao(targetDate: '2026-09-13'));
    expect(find.text('13 set'), findsOneWidget);

    await montar(tester);
    expect(find.text('Repertório'), findsOneWidget);
  });

  testWidgets('repetida vira contagem, não lista de nomes', (tester) async {
    await montar(tester, item: sugestao(alsoSuggestedBy: ['Ana', 'João']));

    // Os nomes não caberiam na linha; o que o líder usa para priorizar é o
    // número. Eles voltam por extenso na tela de detalhes.
    expect(find.text('Você · +2 pessoas'), findsOneWidget);
  });

  testWidgets('a linha não estoura no celular estreito, nem no escuro',
      (tester) async {
    await montar(
      tester,
      theme: AppTheme.dark,
      size: const Size(320 * 3, 640 * 3),
      item: sugestao(
        targetDate: '2026-09-13',
        spotifyUrl: 'https://open.spotify.com/track/x',
        youtubeUrl: 'https://youtu.be/x',
        status: 'ACCEPTED',
        alsoSuggestedBy: const ['Ana', 'João'],
      ),
    );

    // A linha de baixo é a que mais aperta: avatar, nome, três ícones e o
    // selo. Overflow aqui vira exceção, que é o aviso que só chegaria pelo
    // print de alguém.
    expect(tester.takeException(), isNull);
    expect(find.byType(SuggestionMaterialDots), findsOneWidget);
  });

  testWidgets('encerrada mostra o estado, sem dizer quem resolveu',
      (tester) async {
    await montar(tester, item: sugestao(status: 'DECLINED'));

    expect(find.text('Recusada'), findsOneWidget);
  });
}
