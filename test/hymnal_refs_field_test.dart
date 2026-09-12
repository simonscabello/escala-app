import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/songs/data/hymnal_repository.dart';
import 'package:louvor_app/features/songs/domain/hymnal_models.dart';
import 'package:louvor_app/features/songs/presentation/hymnal_refs_field.dart';

/// A seção "Hinários" do cadastro de uma música.
///
/// O que ela precisa fazer, e que a coluna "Número do Cantor Cristão" não
/// sabia: mais de uma referência na mesma música, o livro já usado fora do
/// seletor, e o teto do número vindo do próprio hinário — e não de um 581
/// escrito no app.
void main() {
  const cantorCristao = Hymnal(
    id: 'h-cc',
    slug: 'cantor-cristao',
    name: 'Cantor Cristão',
    abbreviation: 'CC',
    maxNumber: 581,
  );
  const hcc = Hymnal(
    id: 'h-hcc',
    slug: 'hinario-para-o-culto-cristao',
    name: 'Hinário para o Culto Cristão',
    abbreviation: 'HCC',
  );

  /// A última lista que o campo devolveu. É o que a tela de cadastro guardaria
  /// para mandar ao servidor.
  late List<HymnalRef> gravadas;

  Widget campo(List<HymnalRef> refs) {
    gravadas = refs;
    return ProviderScope(
      overrides: [
        hymnalsProvider.overrideWith((ref) async => [cantorCristao, hcc]),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => HymnalRefsField(
              refs: gravadas,
              enabled: true,
              onChanged: (novas) => setState(() => gravadas = novas),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('música sem hinário mostra só o botão', (tester) async {
    await tester.pumpWidget(campo(const []));
    await tester.pumpAndSettle();

    // Nenhuma música é obrigada a ter hinário: a maioria do repertório é
    // cântico.
    expect(find.text('Hinários'), findsOneWidget);
    expect(find.text('Adicionar referência'), findsOneWidget);
  });

  testWidgets('adicionar grava número e hinário', (tester) async {
    await tester.pumpWidget(campo(const []));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar referência'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Número'), '314');
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(gravadas.single.number, 314);
    expect(gravadas.single.abbreviation, 'CC');
    // Com uma referência só não há o que escolher: ela é a principal, e é dela
    // que a escala tira "314 CC".
    expect(gravadas.single.isPrimary, isTrue);
    expect(find.text('Cantor Cristão 314'), findsOneWidget);
  });

  testWidgets('número acima do fim do hinário é recusado ali mesmo', (
    tester,
  ) async {
    await tester.pumpWidget(campo(const []));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar referência'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Número'), '600');
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    // O teto é do livro, e não do app: era isso que amarrava tudo ao Cantor
    // Cristão.
    expect(find.text('Cantor Cristão vai até 581.'), findsOneWidget);
    expect(gravadas, isEmpty);
  });

  testWidgets('hinário sem fim conferido aceita qualquer número', (
    tester,
  ) async {
    await tester.pumpWidget(campo(const []));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar referência'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<Hymnal>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hinário para o Culto Cristão').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Número'), '900');
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    // `maxNumber` nulo é "ninguém contou as páginas", e não "sem limite": o
    // caminho honesto é aceitar, em vez de recusar cadastro certo por um teto
    // chutado.
    expect(gravadas.single.abbreviation, 'HCC');
    expect(gravadas.single.number, 900);
  });

  testWidgets('o hinário que a música já tem sai do seletor', (tester) async {
    await tester.pumpWidget(
      campo(const [
        HymnalRef(
          hymnalId: 'h-cc',
          name: 'Cantor Cristão',
          abbreviation: 'CC',
          number: 314,
          isPrimary: true,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar referência'));
    await tester.pumpAndSettle();

    // O hino não tem dois números no mesmo livro, e o servidor recusaria.
    await tester.tap(find.byType(DropdownButtonFormField<Hymnal>));
    await tester.pumpAndSettle();
    expect(find.text('Cantor Cristão'), findsNothing);
    expect(find.text('Hinário para o Culto Cristão'), findsWidgets);
  });

  testWidgets('a segunda referência não rouba a principal', (tester) async {
    await tester.pumpWidget(
      campo(const [
        HymnalRef(
          hymnalId: 'h-cc',
          name: 'Cantor Cristão',
          abbreviation: 'CC',
          number: 5,
          isPrimary: true,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar referência'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Número'), '12');
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(gravadas, hasLength(2));
    expect(gravadas.where((r) => r.isPrimary).single.abbreviation, 'CC');
    // Com duas, a escolha de qual aparece na escala passa a existir.
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
  });

  testWidgets('trocar a principal deixa exatamente uma marcada', (
    tester,
  ) async {
    await tester.pumpWidget(
      campo(const [
        HymnalRef(
          hymnalId: 'h-cc',
          name: 'Cantor Cristão',
          abbreviation: 'CC',
          number: 5,
          isPrimary: true,
        ),
        HymnalRef(
          hymnalId: 'h-hcc',
          name: 'Hinário para o Culto Cristão',
          abbreviation: 'HCC',
          number: 12,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.star_outline_rounded));
    await tester.pumpAndSettle();

    expect(gravadas.where((r) => r.isPrimary).single.abbreviation, 'HCC');
  });

  testWidgets('remover a principal promove a que sobrou', (tester) async {
    await tester.pumpWidget(
      campo(const [
        HymnalRef(
          hymnalId: 'h-cc',
          name: 'Cantor Cristão',
          abbreviation: 'CC',
          number: 5,
          isPrimary: true,
        ),
        HymnalRef(
          hymnalId: 'h-hcc',
          name: 'Hinário para o Culto Cristão',
          abbreviation: 'HCC',
          number: 12,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.close_rounded).first);
    await tester.pumpAndSettle();

    // Sem isto a lista ficaria sem nenhuma principal, e a escala não teria o
    // que mostrar até a próxima ida à rede.
    expect(gravadas.single.abbreviation, 'HCC');
    expect(gravadas.single.isPrimary, isTrue);
  });
}
