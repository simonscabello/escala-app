import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// O cabeçalho de uma tela de detalhe: título grande, etiquetas na mesma
/// linha, e linhas de apoio embaixo.
///
/// **Sem fundo.** O modelo é a tela da música: o título se sustenta pelo corpo
/// da letra, e a hierarquia contra os blocos de baixo vem do tamanho e da
/// folga. O fundo violeta cheio é da manchete da Home, e só dela — uma tela de
/// detalhe que abre com a mesma manchete parece uma segunda Home.
///
/// A mesma peça abre a música, a escala, o evento e a sugestão.
class AppDetailHeader extends StatelessWidget {
  const AppDetailHeader({
    super.key,
    required this.title,
    this.badges = const [],
    this.overline,
    this.lines = const [],
  });

  final String title;

  /// Etiquetas ao lado do título ("Nova", "Rascunho"). Descem inteiras quando
  /// o título ocupa a linha.
  final List<Widget> badges;

  /// A linha em versalete logo abaixo do título (artista).
  final String? overline;

  /// Linhas de apoio, na ordem (hinários, "Para o repertório", local).
  final List<Widget> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // `Wrap` e não `Row`: título longo ocupa duas linhas, e a etiqueta
        // desce inteira em vez de espremer o nome.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Text(title, style: theme.textTheme.headlineMedium),
            ...badges,
          ],
        ),
        if (overline != null && overline!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          SmallCapsLine(overline!),
        ],
        for (final line in lines) ...[
          const SizedBox(height: AppSpacing.xs),
          line,
        ],
      ],
    );
  }
}

/// Texto em versalete: o artista abaixo do nome da música.
///
/// Caixa alta **só no desenho**: o leitor de tela recebe o texto como foi
/// escrito, senão soletraria "M-I-N-I-S-T-É-R-I-O".
class SmallCapsLine extends StatelessWidget {
  const SmallCapsLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      text.toUpperCase(),
      semanticsLabel: text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// Uma linha de apoio com ícone: local, destino da sugestão.
class DetailMetaLine extends StatelessWidget {
  const DetailMetaLine({
    super.key,
    required this.icon,
    required this.text,
    this.maxLines = 2,
  });

  final IconData icon;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: muted),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}
