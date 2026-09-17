import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'app_content_width.dart';

/// A barra presa ao rodapé com a ação principal da tela.
///
/// **Formulário longo salva aqui; formulário curto salva no fim.** A regra é
/// essa porque o botão de salvar no fim de um formulário que rola duas telas
/// fica longe de onde a pessoa acabou de mexer — e, com o teclado aberto, some.
/// Nos curtos (login, nome da equipe) o fim já está à vista, e uma barra fixa
/// seria uma moldura a mais.
///
/// Era a mesma barra montada à mão em três telas (escalação, repertório da
/// escala, publicação), com folgas quase iguais.
///
/// [leading] fica à esquerda do botão quando os dois cabem lado a lado — o
/// progresso da escalação, o estado do rascunho. Quando não cabem, ele sobe
/// para cima do botão, que continua com a largura inteira.
class AppBottomActionBar extends StatelessWidget {
  const AppBottomActionBar({
    super.key,
    required this.action,
    this.leading,
    this.sideBySideFrom = 460,
  });

  final Widget action;
  final Widget? leading;

  /// Largura a partir da qual [leading] divide a linha com o botão. Um botão
  /// de uma palavra ("Publicar") cabe ao lado do texto em qualquer celular, e
  /// passa 0.
  final double sideBySideFrom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: AppContentWidth.reading(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.md,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (leading == null) {
                  return SizedBox(width: double.infinity, child: action);
                }
                if (constraints.maxWidth >= sideBySideFrom) {
                  return Row(
                    children: [
                      Expanded(child: leading!),
                      const SizedBox(width: AppSpacing.lg),
                      action,
                    ],
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    leading!,
                    const SizedBox(height: AppSpacing.sm),
                    action,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
