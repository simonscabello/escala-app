import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// O título de um bloco da tela.
///
/// Era o mesmo elemento escrito de três formas: este widget no detalhe da
/// escala, um `_SectionTitle` privado nos convites e `Text(..., titleMedium)`
/// solto no perfil e nos formulários. Diferiam no espaço abaixo e em ter ou não
/// linha de apoio, o que fazia dois blocos vizinhos parecerem de níveis
/// diferentes sem serem.
///
/// O [trailing] existe porque quase todo bloco tem uma ação sua ("Editar" no
/// repertório, a contagem em "Cultos"), e sem lugar previsto ela acabava
/// empurrada para dentro do conteúdo ou solta numa `Row` montada na hora.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.md),
  });

  final String title;
  final String? subtitle;

  /// Ação ou contagem à direita do título.
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // O título e a ação dividem uma linha centralizada na vertical; a linha de
    // apoio vai embaixo, na largura toda. Com tudo encostado no topo, o botão
    // (48px de área de toque) deixava "Editar" mais baixo que o título.
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                // `header: true` faz o leitor de tela anunciar "cabeçalho" e
                // permite pular de bloco em bloco, em vez de percorrer a tela
                // linha a linha.
                child: Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
