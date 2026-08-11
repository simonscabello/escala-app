import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Segura a largura do conteúdo em telas grandes.
///
/// O app foi desenhado para a mão, mas roda em tablet e no navegador — e lá
/// cada tela se esticava até a borda. Uma linha de 1400px força o olho a
/// procurar onde a próxima começa, e o cartão de uma escala ficava com dois
/// palmos de vazio entre "Domingo, 9 de agosto" e "09:00", que é justamente o
/// par que precisa ser lido junto.
///
/// No celular não faz nada: a restrição só entra quando sobra espaço.
///
/// **Ele limita a largura e não reivindica altura nenhuma.** O `heightFactor`
/// não é detalhe: um `Align` sem fator ocupa todo o espaço disponível nos
/// **dois** eixos, e a primeira versão deste widget não tinha o fator. No corpo
/// de uma tela isso passava despercebido — o filho já era ganancioso e ocupava
/// tudo de qualquer forma. Dentro de um `bottomNavigationBar`, onde o
/// `Scaffold` entrega uma restrição frouxa de "até a tela inteira", a barra
/// crescia até a altura da tela, o corpo ficava com zero pixel e a tela inteira
/// virava um botão colado no topo com o vazio embaixo. Quebrou "Escalar equipe"
/// e "Repertório da escala" exatamente assim.
///
/// Com `heightFactor: 1` a altura passa a ser a do filho. Onde o filho é
/// ganancioso (uma lista, uma `Column` que se estica) nada muda; onde ele tem
/// altura própria, o widget para de inventar espaço. `test/app_content_width_test.dart`
/// trava as duas situações.
class AppContentWidth extends StatelessWidget {
  const AppContentWidth({
    super.key,
    required this.child,
    this.maxWidth = AppSpacing.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
