import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'app_card.dart';

/// Um fato de [AppFactsStrip]: rótulo pequeno em cima, valor em destaque.
class AppFact {
  const AppFact({
    required this.label,
    required this.value,
    this.icon,
    this.hint,
    this.highlight = false,
    this.wrapValue = false,
    this.maxLines = 2,
    this.probeValues,
  });

  final String label;
  final String value;
  final IconData? icon;

  /// Linha de apoio embaixo do valor ("gravação: G").
  final String? hint;

  /// Valor na cor da marca — o que é decisão da equipe, ou sobre você.
  final bool highlight;

  /// O valor quebra em até [maxLines] linhas em vez de encolher. Para valores
  /// de comprimento livre (uma anotação antiga de tom). Um valor com `\n`
  /// (um culto por linha) ignora isto: cada linha aparece inteira.
  final bool wrapValue;
  final int maxLines;

  /// Os valores que esta coluna pode assumir, para decidir se cabe ícone.
  ///
  /// Medir contra o vocabulário inteiro, e não contra o valor de agora, é o
  /// que impede a faixa de mudar de desenho de uma música para outra no mesmo
  /// aparelho ("Calma" com ícone, "Moderada" sem). Nulo mede só o valor.
  final List<String>? probeValues;
}

/// Os fatos que respondem à primeira pergunta de uma tela, numa faixa só.
///
/// Nasceu na tela da música (Tom · Tipo · Andamento) e passou a ser o
/// cabeçalho das telas de detalhe: a escala (Culto · Ensaio · Sua função) e o
/// evento (Data · Horário). Um cartão, colunas iguais separadas por
/// fios — **um** objeto, e não três selos soltos disputando atenção.
///
/// **Nada aqui vira reticências.** "Modera…" não diz se é moderada. Primeiro
/// saem os ícones — ajudam a achar a coluna, mas é o valor que a pessoa veio
/// ler —, e se nem assim couber o texto encolhe um pouco em vez de ser cortado.
/// A decisão dos ícones é medida com a fonte e a escala do aparelho, como faz a
/// `AppChoiceBar`.
class AppFactsStrip extends StatelessWidget {
  const AppFactsStrip({super.key, required this.facts});

  final List<AppFact> facts;

  static const _dividerWidth = AppSpacing.md;

  bool _iconsFit(BuildContext context, double column) {
    if (!facts.any((fact) => fact.icon != null)) return false;
    final theme = Theme.of(context);

    final texts = <(String, TextStyle?)>[
      for (final fact in facts) ...[
        (fact.label, _FactCell.labelStyle(theme)),
        for (final value in fact.probeValues ?? fact.value.split('\n'))
          (value, _FactCell.valueStyle(theme)),
      ],
    ];

    return texts.every((entry) {
      final painter = TextPainter(
        text: TextSpan(text: entry.$1, style: entry.$2),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final fits =
          painter.width + _FactCell.iconSpace + AppSpacing.xs <= column;
      painter.dispose();
      return fits;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = facts.length;
          final column =
              (constraints.maxWidth - (count - 1) * _dividerWidth) / count;
          final showIcons = _iconsFit(context, column);
          final divider = VerticalDivider(
            width: _dividerWidth,
            thickness: 1,
            color: theme.colorScheme.outlineVariant,
          );

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) divider,
                  Expanded(
                    child: _FactCell(fact: facts[i], showIcon: showIcons),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FactCell extends StatelessWidget {
  const _FactCell({required this.fact, required this.showIcon});

  final AppFact fact;
  final bool showIcon;

  static const _iconSize = 20.0;

  /// O que o ícone ocupa na coluna, com o intervalo até o texto.
  static const iconSpace = _iconSize + AppSpacing.sm;

  static TextStyle? labelStyle(ThemeData theme) =>
      theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );

  static TextStyle? valueStyle(ThemeData theme) =>
      theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget oneLine(String text, TextStyle? style) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(text, maxLines: 1, style: style),
        );

    final valueColored = valueStyle(theme)?.copyWith(
      color: fact.highlight ? scheme.primary : scheme.onSurface,
    );

    // Um valor com várias linhas (um culto por linha) mostra **todas**: cada
    // uma encolhe se não couber, em vez de quebrar. Quebrando, "Manhã 08:30"
    // virava duas linhas numa coluna estreita e o limite de linhas cortava o
    // culto da noite fora.
    final valueLines = fact.value.split('\n');

    // **Centralizado na coluna e encostado no topo.** O bloco (ícone + textos)
    // fica no meio da coluna, mas os textos dentro dele seguem alinhados entre
    // si; e com uma coluna de duas linhas (dois cultos) os rótulos das outras
    // continuam na mesma altura, em vez de descerem para o meio.
    return Align(
      alignment: Alignment.topCenter,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showIcon && fact.icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                fact.icon,
                size: _iconSize,
                color:
                    fact.highlight ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                oneLine(fact.label, labelStyle(theme)),
                if (valueLines.length > 1)
                  for (final line in valueLines) oneLine(line, valueColored)
                else if (fact.wrapValue)
                  Text(
                    fact.value,
                    maxLines: fact.maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: valueColored,
                  )
                else
                  oneLine(fact.value, valueColored),
                if (fact.hint != null) oneLine(fact.hint!, labelStyle(theme)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
