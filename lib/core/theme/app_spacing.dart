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

  /// Elementos pequenos dentro de um cartao (etiquetas, marcadores).
  static const double radiusSm = 8;

  /// **O raio padrao**: campos, botoes, dialogos, menus. Na duvida, este.
  static const double radiusMd = 12;

  /// Cartoes e superficies de conteudo.
  ///
  /// `radiusXl` (20) e `radiusHero` (28) sairam: o `radiusHero` nunca foi usado
  /// e o `radiusXl` sobrava num lugar so, o que dava ao app tres raios de
  /// cartao diferentes conforme a tela. Um raio por papel.
  static const double radiusLg = 16;

  /// Pilulas: chips, etiquetas, o destaque "VOCE".
  static const double radiusPill = 999;

  static const double screenPadding = 24;
  static const double listPadding = 16;

  /// Alvo minimo de toque (WCAG 2.5.8 pede 24, o Material pede 48; usamos 48).
  ///
  /// Vale para qualquer coisa tocavel, inclusive linha de lista: uma linha
  /// `dense` sem padding chega a 40 e escapa do dedo de quem esta segurando o
  /// instrumento.
  static const double touchTarget = 48;
}
