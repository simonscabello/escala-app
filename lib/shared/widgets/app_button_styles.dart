import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Botões do tamanho da ação.
///
/// O tema dá a todo botão preenchido 52px de altura — é o peso certo para o
/// botão que salva um formulário, e o errado para "Adicionar ao culto" dentro
/// de uma linha da faixa de sugestões, ou "Convidar" ao lado de um nome.
/// Ali cada ação de linha pesava como a ação da tela.
///
/// [compact] e [compactText] ficam com 40px desenhados; a área de toque
/// continua com 48, que o Material acrescenta em volta.
abstract final class AppButtonStyles {
  /// Para `FilledButton` e `FilledButton.tonal` dentro de linha ou cartão.
  static final ButtonStyle compact = FilledButton.styleFrom(
    minimumSize: const Size(0, AppSpacing.compactButtonHeight),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
  );

  /// Para `TextButton` dentro de linha ou cartão.
  static final ButtonStyle compactText = TextButton.styleFrom(
    minimumSize: const Size(0, AppSpacing.compactButtonHeight),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
  );
}
