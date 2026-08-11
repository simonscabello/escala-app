import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/shared/widgets/app_content_width.dart';

/// `AppContentWidth` limita a **largura**. Ele não pode reivindicar altura.
///
/// O teste existe porque a primeira versão reivindicava: era um `Align` sem
/// `heightFactor`, e um `Align` sem fator ocupa **todo** o espaço disponível
/// nos dois eixos. Dentro de uma barra inferior isso fazia a barra crescer até
/// a altura da tela inteira, o corpo do `Scaffold` ficar com zero pixel e o
/// botão de salvar aparecer colado no topo, sozinho, com a tela vazia embaixo.
/// Foi assim que "Escalar equipe" e "Repertório da escala" quebraram.
void main() {
  testWidgets('não ocupa altura além da do filho', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: AppContentWidth(
            child: Container(height: 72, color: const Color(0xFF000000)),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(AppContentWidth)).height,
      72,
      reason: 'a barra inferior tem a altura do conteúdo, não a da tela',
    );
  });

  testWidgets('o corpo do Scaffold continua com a tela toda menos a barra',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppContentWidth(child: ListView(children: const [Text('oi')])),
          bottomNavigationBar: AppContentWidth(
            child: Container(height: 72, color: const Color(0xFF000000)),
          ),
        ),
      ),
    );

    final screen = tester.getSize(find.byType(Scaffold)).height;
    final body = tester.getSize(find.byType(ListView)).height;

    expect(body, screen - 72);
  });

  testWidgets('segura a largura na tela grande e não na pequena',
      (tester) async {
    Future<void> pumpAt(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppContentWidth(child: SizedBox.expand()),
          ),
        ),
      );
    }

    await pumpAt(const Size(1400, 900));
    expect(tester.getSize(find.byType(SizedBox)).width, 640);

    await pumpAt(const Size(360, 800));
    expect(tester.getSize(find.byType(SizedBox)).width, 360);
  });
}
