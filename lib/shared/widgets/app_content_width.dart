import 'package:flutter/material.dart';

import '../../core/responsive/app_breakpoints.dart';
import '../../core/theme/app_spacing.dart';

enum _Variant { fixed, reading, wide }

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
/// **Três larguras, uma decisão por tela.** O construtor comum é a coluna de
/// 640px de sempre e continua sendo o padrão. `AppContentWidth.reading` e
/// `AppContentWidth.wide` crescem no monitor:
///
///  - `reading` (até 820) para o que se lê de cima a baixo — o detalhe da
///    escala, uma música, o perfil. Coluna larga demais cansa a leitura, e
///    esticar essas telas até a borda seria exatamente o "app de celular
///    ampliado" que a versão Web precisa não parecer.
///  - `wide` (até 1180) para o que tem **colunas** — a agenda, a lista de
///    integrantes, a montagem da escala. Ali a largura vira informação: mais
///    campos por linha, menos rolagem.
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
  }) : _variant = _Variant.fixed;

  /// Telas de leitura: cresce até 820 no monitor.
  const AppContentWidth.reading({super.key, required this.child})
      : maxWidth = AppSpacing.contentMaxWidth,
        _variant = _Variant.reading;

  /// Telas com colunas: cresce até 1180 no monitor.
  const AppContentWidth.wide({super.key, required this.child})
      : maxWidth = AppSpacing.contentMaxWidth,
        _variant = _Variant.wide;

  final Widget child;
  final double maxWidth;
  final _Variant _variant;

  double _resolve(BuildContext context) {
    if (_variant == _Variant.fixed) return maxWidth;
    return switch (AppBreakpoints.of(context)) {
      FormFactor.mobile => AppSpacing.contentMaxWidth,
      FormFactor.tablet => _variant == _Variant.wide
          ? AppBreakpoints.readingContentMaxWidth
          : AppSpacing.contentMaxWidth,
      FormFactor.desktop => _variant == _Variant.wide
          ? AppBreakpoints.wideContentMaxWidth
          : AppBreakpoints.readingContentMaxWidth,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _resolve(context)),
        child: child,
      ),
    );
  }
}
