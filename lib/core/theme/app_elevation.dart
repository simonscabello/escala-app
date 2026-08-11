import 'package:flutter/material.dart';

/// Sombra, e quando **não** usar sombra.
///
/// A regra do app é curta: **só projeta sombra o que de fato flutua sobre o
/// conteúdo.** Um cartão numa lista não flutua — ele é a lista. Uma folha que
/// sobe por cima da tela, sim; o botão flutuante, sim; a barra que fica presa
/// no rodapé enquanto o conteúdo passa por baixo, sim.
///
/// Antes todo cartão vinha com duas camadas de sombra, e uma agenda com seis
/// escalas empilhava doze sombras numa tela: a impressão era de peças soltas
/// pairando, não de uma página. Sem sombra, quem separa o cartão da página é a
/// **cor** — por isso a página desceu um passo em `AppColors` — mais um fio de
/// borda no tema claro, onde branco sobre quase-branco precisa de ajuda.
///
/// Sombra colorida, não preta: preto puro sobre um fundo azulado acinzenta a
/// área embaixo da peça e suja o matiz da paleta inteira.
class AppElevation {
  const AppElevation._();

  /// O padrão de quase tudo.
  static const List<BoxShadow> none = [];

  /// Encostado na página, mas acima dela: barra de rodapé, cartão em arraste.
  static List<BoxShadow> raised(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return [
      BoxShadow(
        color: scheme.shadow.withValues(alpha: dark ? 0.44 : 0.06),
        blurRadius: 12,
        offset: const Offset(0, -1),
      ),
    ];
  }

  /// Flutua de verdade: botão flutuante, menu, snackbar.
  static List<BoxShadow> floating(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return [
      BoxShadow(
        color: scheme.shadow.withValues(alpha: dark ? 0.52 : 0.10),
        blurRadius: 20,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: scheme.shadow.withValues(alpha: dark ? 0.32 : 0.05),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];
  }

  /// Cobre a tela: folha inferior, diálogo.
  static List<BoxShadow> overlay(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return [
      BoxShadow(
        color: scheme.shadow.withValues(alpha: dark ? 0.60 : 0.16),
        blurRadius: 40,
        offset: const Offset(0, 12),
      ),
    ];
  }
}
