import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/suggestions/domain/song_suggestion.dart';
import 'package:louvor_app/features/suggestions/presentation/suggestions_screen.dart';
import 'package:louvor_app/shared/widgets/app_card.dart';

/// O cartão da sugestão, no tamanho de um celular de verdade.
///
/// Dois defeitos chegaram por print e voltam aqui como teste: o conteúdo
/// colado na borda (que fazia o canto arredondado comer a primeira letra do
/// título) e a lixeira caindo sozinha para a linha de baixo porque três botões
/// não cabiam numa linha de 375dp.
void main() {
  SongSuggestion sugestao({String? declineReason, String status = 'PENDING'}) =>
      SongSuggestion.fromJson({
        'id': 'sg1',
        'songId': null,
        // Título e artista reais do print, para o teste medir a mesma coisa
        // que a pessoa viu.
        'title': 'Louvores e Honras',
        'artist': 'Guilherme Kerr',
        'link': null,
        'targetDate': null,
        'reason': 'Linda canção.',
        'status': status,
        'declineReason': declineReason,
        'inRepertoire': false,
        'createdBy': {
          'membershipId': 'm1',
          'displayName': 'Você',
          'avatarUrl': null,
        },
        'createdAt': '2026-09-03T12:00:00.000Z',
        'alsoSuggestedBy': const [],
      });

  Future<void> montar(
    WidgetTester tester, {
    required bool canManage,
    SongSuggestion? item,
  }) async {
    // Celular comum. É a largura em que os três botões não cabiam.
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SuggestionCard(
                suggestion: item ?? sugestao(),
                teamId: 't1',
                canManage: canManage,
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
    await montar(tester, canManage: true);

    final cartao = tester.getTopLeft(find.byType(AppCard));
    final titulo = tester.getTopLeft(find.text('Louvores e Honras'));

    // Sem padding o título nascia em cima da borda e o Clip.antiAlias do canto
    // arredondado cortava o "L".
    expect(titulo.dx - cartao.dx, greaterThanOrEqualTo(16));
    expect(titulo.dy - cartao.dy, greaterThanOrEqualTo(16));

    final motivo = tester.getTopLeft(find.text('Linda canção.'));
    expect(motivo.dx - cartao.dx, greaterThanOrEqualTo(16));
  });

  testWidgets('excluir saiu da linha das decisões e foi para o cabeçalho',
      (tester) async {
    await montar(tester, canManage: true);

    final lixeira = tester.getCenter(
      find.byIcon(Icons.delete_outline_rounded),
    );
    final acolher = tester.getCenter(find.text('Acolher'));
    final recusar = tester.getCenter(find.text('Por enquanto não'));
    final titulo = tester.getCenter(find.text('Louvores e Honras'));

    // O defeito era a lixeira dividir a linha com os dois botões e ser
    // empurrada para baixo. Agora ela está no topo, na altura do título.
    //
    // Note que aqui NÃO se afirma que os dois botões cabem numa linha: a fonte
    // do ambiente de teste é bem mais larga que a Roboto do aparelho, e medir
    // largura de texto aqui diria respeito ao teste, não ao app.
    expect(lixeira.dy, lessThan(acolher.dy));
    expect(lixeira.dy, lessThan(recusar.dy));
    expect(lixeira.dy, closeTo(titulo.dy, 24));
  });

  testWidgets('o integrante vê só excluir, sem as decisões do líder',
      (tester) async {
    await montar(tester, canManage: false);

    expect(find.text('Acolher'), findsNothing);
    expect(find.text('Por enquanto não'), findsNothing);
    // A própria sugestão continua podendo ser excluída por quem a fez.
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
  });

  testWidgets('recusa sem motivo não desenha caixa vazia', (tester) async {
    await montar(
      tester,
      canManage: true,
      item: sugestao(status: 'DECLINED'),
    );

    // Um AppCard só: o de dentro só existe quando há motivo escrito. Campo em
    // branco é uso legítimo, e não pode virar um retângulo vazio na tela.
    expect(find.byType(AppCard), findsOneWidget);
    expect(find.text('Reabrir'), findsOneWidget);

    // "Por enquanto não" continua na tela -- como SELO de estado, não como
    // botão. É por isso que a busca é pelo TextButton, e não pelo texto.
    expect(
      find.widgetWithText(TextButton, 'Por enquanto não'),
      findsNothing,
    );
    expect(find.text('Por enquanto não'), findsOneWidget);
  });

  testWidgets('com motivo, o texto aparece para quem sugeriu', (tester) async {
    await montar(
      tester,
      canManage: true,
      item: sugestao(
        status: 'DECLINED',
        declineReason: 'Já temos duas músicas novas neste mês.',
      ),
    );

    expect(find.text('Já temos duas músicas novas neste mês.'), findsOneWidget);
    expect(find.byType(AppCard), findsNWidgets(2));
  });
}
