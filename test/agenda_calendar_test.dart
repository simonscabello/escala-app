import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:louvor_app/core/theme/app_theme.dart';
import 'package:louvor_app/features/events/presentation/agenda_calendar.dart';

/// O mês precisa ser lido de relance.
///
/// O que se protege aqui são os **quatro estados** do dia — comum, hoje, com
/// compromisso, selecionado — e a garantia de que nenhum apaga o outro: quem
/// toca num domingo cheio não pode perder de vista que ele tem escala, e hoje
/// não pode sumir dentro de um mês pintado.
void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('o dia com compromisso ganha fundo e traço; o vazio, nenhum',
      (tester) async {
    await _pump(tester, markedDays: const {'2026-09-13': 1});

    expect(_fundoDoDia(tester, '2026-09-13'), isNot(Colors.transparent));
    expect(_tracos(tester, '2026-09-13'), 1);

    expect(_fundoDoDia(tester, '2026-09-14'), Colors.transparent);
    expect(_tracos(tester, '2026-09-14'), 0);
  });

  testWidgets('dois compromissos, dois traços; muitos param em três',
      (tester) async {
    await _pump(
      tester,
      markedDays: const {'2026-09-13': 2, '2026-09-20': 9},
    );

    expect(_tracos(tester, '2026-09-13'), 2);
    expect(_tracos(tester, '2026-09-20'), AgendaCalendar.maxMarks);
  });

  /// O dia selecionado é o fundo cheio da marca; o dia com compromisso é o
  /// fundo claro. Se as duas pinturas fossem a mesma, selecionar um dia vazio
  /// o faria parecer cheio.
  testWidgets('selecionado e com compromisso são pinturas diferentes',
      (tester) async {
    await _pump(
      tester,
      selected: DateTime(2026, 9, 14),
      markedDays: const {'2026-09-13': 1},
    );

    final selecionado = _fundoDoDia(tester, '2026-09-14');
    final comEscala = _fundoDoDia(tester, '2026-09-13');
    expect(selecionado, isNot(comEscala));
    expect(selecionado, isNot(Colors.transparent));
  });

  testWidgets('selecionar um dia com compromisso não apaga o traço',
      (tester) async {
    await _pump(
      tester,
      selected: DateTime(2026, 9, 13),
      markedDays: const {'2026-09-13': 2},
    );

    expect(_tracos(tester, '2026-09-13'), 2);
  });

  /// Hoje é moldura, e continua sendo nos quatro estados: é o único sinal que
  /// não disputa com o fundo.
  testWidgets('hoje tem moldura, esteja ele marcado, selecionado ou nenhum',
      (tester) async {
    for (final marcados in [
      const <String, int>{},
      const {'2026-09-09': 1},
    ]) {
      for (final selecionado in [DateTime(2026, 9, 9), DateTime(2026, 9, 14)]) {
        await _pump(tester, selected: selecionado, markedDays: marcados);
        expect(
          _moldura(tester, '2026-09-09').style,
          BorderStyle.solid,
          reason: 'hoje sem moldura com marcados=$marcados',
        );
        expect(_moldura(tester, '2026-09-14').style, BorderStyle.none);
      }
    }
  });

  testWidgets('a leitura de tela diz quantos compromissos o dia tem',
      (tester) async {
    await _pump(tester, markedDays: const {'2026-09-13': 1, '2026-09-20': 3});

    expect(_semantica(tester, '2026-09-13'), contains('1 compromisso'));
    expect(_semantica(tester, '2026-09-20'), contains('3 compromissos'));
    expect(_semantica(tester, '2026-09-09'), contains('hoje'));
    expect(_semantica(tester, '2026-09-14'), isNot(contains('compromisso')));
  });

  for (final width in [320.0, 360.0, 375.0, 768.0]) {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets('não estoura em ${width.toInt()}px a ${scale}x',
          (tester) async {
        await _pump(
          tester,
          size: Size(width, 900),
          textScale: scale,
          markedDays: const {'2026-09-13': 3, '2026-09-20': 1},
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

}

Color? _fundoDoDia(WidgetTester tester, String dia) {
  final material = tester.widget<Material>(
    find.descendant(
      of: find.byKey(ValueKey('agenda-day-$dia')),
      matching: find.byType(Material),
    ),
  );
  return material.color;
}

BorderSide _moldura(WidgetTester tester, String dia) {
  final material = tester.widget<Material>(
    find.descendant(
      of: find.byKey(ValueKey('agenda-day-$dia')),
      matching: find.byType(Material),
    ),
  );
  return (material.shape! as RoundedRectangleBorder).side;
}

/// Os traços são `Container`s de 6x4 dentro da célula do dia.
int _tracos(WidgetTester tester, String dia) {
  return tester
      .widgetList<Container>(
        find.descendant(
          of: find.byKey(ValueKey('agenda-day-$dia')),
          matching: find.byType(Container),
        ),
      )
      .where((c) => c.constraints?.maxWidth == 6)
      .length;
}

String _semantica(WidgetTester tester, String dia) {
  final semantics = tester.widget<Semantics>(
    find.byKey(ValueKey('agenda-day-$dia')),
  );
  return semantics.properties.label ?? '';
}

Future<void> _pump(
  WidgetTester tester, {
  Map<String, int> markedDays = const {},
  DateTime? selected,
  Size size = const Size(400, 900),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: SingleChildScrollView(
            child: AgendaCalendar(
              month: DateTime(2026, 9),
              selectedDay: selected ?? DateTime(2026, 9, 9),
              today: DateTime(2026, 9, 9),
              markedDays: markedDays,
              onSelected: (_) {},
              onMonthChanged: (_) {},
              onToday: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
