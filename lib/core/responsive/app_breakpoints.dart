import 'package:flutter/widgets.dart';

/// O formato da janela, em três faixas.
///
/// O app nasceu para a mão e passou a rodar também no navegador. As duas
/// experiências compartilham telas, providers e regras — o que muda é o
/// **formato**: onde cabe uma barra inferior de três abas, onde cabe uma barra
/// lateral, e quanto de largura o conteúdo pode ocupar sem a linha virar uma
/// travessia de monitor.
///
/// A faixa vem da **largura da janela**, não da plataforma. Um celular deitado
/// e um tablet em pé ganham o mesmo tratamento, e o Chrome redimensionado passa
/// pelas três sem nenhum `kIsWeb` no caminho.
enum FormFactor {
  /// Celular em pé. Navegação por barra inferior, uma coluna, botão largo.
  mobile,

  /// Tablet, celular deitado, janela estreita de navegador. Barra lateral
  /// recolhida (só ícones) e conteúdo com folga lateral.
  tablet,

  /// Monitor. Barra lateral aberta, conteúdo em duas colunas onde faz sentido.
  desktop;

  bool get isMobile => this == FormFactor.mobile;

  /// Verdadeiro em tablet **e** desktop: é a pergunta que a maioria das telas
  /// faz ("tem espaço para uma segunda coluna / uma barra lateral?").
  bool get isWide => this != FormFactor.mobile;

  bool get isDesktop => this == FormFactor.desktop;
}

/// Os números do layout, em um lugar só.
///
/// Nenhuma tela deve escrever `MediaQuery.sizeOf(context).width > 900`. Quando
/// um valor precisar mudar, ele muda aqui — e não em doze arquivos que ninguém
/// lembra de procurar.
class AppBreakpoints {
  const AppBreakpoints._();

  /// A partir daqui a janela deixa de ser um celular em pé.
  static const double tablet = 600;

  /// A partir daqui cabe barra lateral aberta e conteúdo em duas colunas.
  static const double desktop = 1024;

  /// Largura da barra lateral aberta.
  static const double sideNavWidth = 268;

  /// Largura da barra lateral recolhida (só ícones).
  static const double sideNavRailWidth = 76;

  /// Teto de uma tela de **conteúdo largo** (listas com colunas, montagem da
  /// escala, relatórios). Acima disso o olho perde onde a linha seguinte
  /// começa, e a tela vira um campo de futebol com texto no canto.
  static const double wideContentMaxWidth = 1180;

  /// Teto de um **formulário** no monitor.
  ///
  /// `AppSpacing.formMaxWidth` (420) é a largura de um formulário na mão, e
  /// continua valendo no celular e no tablet. Num monitor de 1920px aquela
  /// coluna parecia a captura de tela de um celular colada no meio da página —
  /// e o formulário de escala, que tem data e três horários, ficava com tudo
  /// empilhado sem necessidade. 520 é o ponto em que dois campos curtos cabem
  /// lado a lado sem que uma linha de texto vire uma travessia.
  static const double formMaxWidthDesktop = 520;

  /// Teto de uma tela de **leitura** (detalhe da escala, música, perfil). Mais
  /// estreito de propósito: ali se lê de cima a baixo, e coluna larga cansa.
  static const double readingContentMaxWidth = 820;

  static FormFactor of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  static FormFactor fromWidth(double width) {
    if (width >= desktop) return FormFactor.desktop;
    if (width >= tablet) return FormFactor.tablet;
    return FormFactor.mobile;
  }
}

/// Açúcar para não repetir `AppBreakpoints.of(context)` em cada `build`.
extension FormFactorContext on BuildContext {
  FormFactor get formFactor => AppBreakpoints.of(this);

  bool get isWideLayout => formFactor.isWide;

  bool get isDesktopLayout => formFactor.isDesktop;
}
