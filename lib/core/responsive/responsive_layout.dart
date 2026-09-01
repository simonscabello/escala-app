import 'package:flutter/widgets.dart';

import 'app_breakpoints.dart';

/// Entrega o [FormFactor] a quem precisa decidir **como** desenhar.
///
/// Usa `LayoutBuilder`, e não `MediaQuery`, de propósito: dentro da casca com
/// barra lateral a janela tem 1600px mas o conteúdo tem 1300, e quem pergunta
/// "cabem duas colunas aqui?" precisa da resposta sobre o **espaço que
/// recebeu** — não sobre o monitor. É o que evita a segunda coluna espremida
/// que aparece quando a conta é feita com a largura da tela.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, FormFactor form) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => builder(
        context,
        // Sem restrição de largura (dentro de uma linha rolável, por exemplo)
        // não há o que medir: cai no formato da janela.
        constraints.hasBoundedWidth
            ? AppBreakpoints.fromWidth(constraints.maxWidth)
            : AppBreakpoints.of(context),
      ),
    );
  }
}

/// Uma árvore por formato, para quando a diferença é **estrutural**.
///
/// Só vale a pena quando o desenho muda de verdade — uma lista que vira tabela,
/// uma tela que vira duas colunas. Diferença de espaçamento ou de largura
/// máxima **não** justifica duas árvores: para isso existem os tokens de
/// `AppBreakpoints` e o `ResponsiveBuilder`.
///
/// [tablet] é opcional e cai em [mobile] quando ausente; [desktop] cai em
/// [tablet]. Assim uma tela que só se importa com "estreito × largo" declara
/// duas coisas, não três.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, form) => switch (form) {
        FormFactor.desktop => (desktop ?? tablet ?? mobile)(context),
        FormFactor.tablet => (tablet ?? mobile)(context),
        FormFactor.mobile => mobile(context),
      },
    );
  }
}
