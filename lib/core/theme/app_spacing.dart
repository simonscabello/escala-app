/// Escala de espacamento e raio da identidade visual.
///
/// Escala de 4 em 4 ate `lg` e depois em saltos maiores: valores intermediarios
/// (10, 14, 18) nao se distinguem na tela e so criam variacao sem intencao.
/// Quando um valor da escala nao servir, o problema costuma ser o layout, nao a
/// escala.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  // --- Raio ---
  //
  // **O raio acompanha o tamanho do elemento**, numa proporção de mais ou menos
  // um terço da altura. Não é tabela decorada: é o que faz um selo de 22px e um
  // cartão de 120px parecerem da mesma família em vez de duas decisões
  // separadas. Cantos iguais em coisas de tamanhos muito diferentes é o que dá
  // aquele ar de template — o selo fica com cara de botão, o cartão com cara de
  // caixa de diálogo.
  //
  // A consequência prática é que peça dentro de peça sempre decresce: folha
  // (28) > cartão (20) > botão (14) > selo (8). Quando duas superfícies
  // encostam, a de dentro tem o canto menor, e é isso que faz o encaixe parecer
  // desenhado.

  /// Selos, etiquetas, marcadores — coisas de ~20 a 26px de altura.
  static const double radiusXs = 8;

  /// Campos, chips e ladrilhos de ícone — ~36 a 44px.
  static const double radiusSm = 12;

  /// **O raio de controle**: botões e o que se toca com o polegar, ~48 a 56px.
  static const double radiusMd = 14;

  /// Cartões e superfícies agrupadas.
  static const double radiusLg = 20;

  /// Folhas, diálogos e o que cobre a tela. Só aqui — um cartão com este raio
  /// parece um balão de conversa.
  static const double radiusXl = 28;

  /// Pilulas: o destaque "VOCÊ", os segmentos de escolha.
  static const double radiusPill = 999;

  static const double screenPadding = 24;
  static const double listPadding = 16;

  /// Largura máxima de uma coluna de leitura.
  ///
  /// O app roda em celular, em tablet e no navegador. Sem teto, a mesma lista
  /// que cabe na mão vira linhas de 1400px no monitor — o olho perde o começo
  /// da linha seguinte, e o cartão de uma escala fica com dois palmos de vazio
  /// entre o nome e a hora. O conteúdo centraliza e para de crescer aqui.
  static const double contentMaxWidth = 640;

  /// Largura máxima de um formulário. Mais estreita que [contentMaxWidth]:
  /// campo largo demais atrapalha até em monitor.
  static const double formMaxWidth = 420;

  /// A partir daqui a tela deixa de ser "um celular" e sobra margem lateral.
  static const double wideBreakpoint = 720;

  /// Alvo minimo de toque (WCAG 2.5.8 pede 24, o Material pede 48; usamos 48).
  ///
  /// Vale para qualquer coisa tocavel, inclusive linha de lista: uma linha
  /// `dense` sem padding chega a 40 e escapa do dedo de quem esta segurando o
  /// instrumento.
  static const double touchTarget = 48;

  /// Altura do botão de ação principal.
  ///
  /// Acima do mínimo de toque de propósito: o botão que salva é o objeto mais
  /// pesado da tela e precisa parecer isso. 52 é o ponto em que ele ganha
  /// presença sem virar uma barra.
  static const double buttonHeight = 52;
}
