import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// O bloco de data que abre uma linha de agenda: dia da semana em cima,
/// número embaixo.
///
/// **Existe para a lista ser varrida, não lida.** A data por extenso
/// ("Domingo, 13 de setembro") continua sendo o título da linha e é o que
/// identifica a escala; mas quem rola uma agenda de trinta datas procura um
/// número, e um número dentro de uma frase obriga a ler a frase inteira. O
/// bloco põe esse número numa coluna fixa, sempre no mesmo lugar — é a mesma
/// razão de as folhinhas de parede existirem.
///
/// **Duas linhas e nada mais.** Já teve o mês; ele repetia o cabeçalho do
/// grupo logo acima ("Setembro 2026") em cada uma das linhas abaixo dele.
///
/// O número é tabular: numa coluna, "1" e "20" precisam ocupar a mesma
/// largura, senão a pilha de blocos desalinha e a coluna deixa de parecer uma
/// coluna.
class AppDateBadge extends StatelessWidget {
  const AppDateBadge({
    super.key,
    required this.weekday,
    required this.day,
    this.tone = DateBadgeTone.normal,
    this.semanticsLabel,
  });

  /// "DOM", "QUI" — já em caixa alta (ver `formatEventBadgeWeekday`).
  final String weekday;

  /// "13" — o número do dia.
  final String day;

  final DateBadgeTone tone;

  /// O que o leitor de tela anuncia no lugar de "DOM 13".
  ///
  /// A data por extenso vem escrita ao lado, então o padrão é **calar**: sem
  /// isto, cada linha da agenda era anunciada como "D O M, treze, Domingo 13
  /// de setembro".
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (background, foreground, dayColor) = switch (tone) {
      DateBadgeTone.normal => (
          scheme.surfaceContainerHigh,
          scheme.onSurfaceVariant,
          scheme.onSurface,
        ),
      DateBadgeTone.primary => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          scheme.onPrimaryContainer,
        ),
      // Data em aberto é uma proposta, não um compromisso: o bloco fica no
      // preenchimento discreto e o número perde o peso cheio, para a linha
      // não competir com as escalas que já existem.
      DateBadgeTone.muted => (
          scheme.surfaceContainerLow,
          scheme.onSurfaceVariant,
          scheme.onSurfaceVariant,
        ),
    };

    final badge = Container(
      // Largura fixa: é o que faz os títulos de todas as linhas começarem na
      // mesma coluna. Sem ela, "3" e "27" empurrariam o texto para lugares
      // diferentes e a lista perderia o prumo.
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            weekday,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          Text(
            day,
            maxLines: 1,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: dayColor,
              fontWeight: tone == DateBadgeTone.muted
                  ? FontWeight.w600
                  : FontWeight.w700,
              fontFeatures: AppTypography.tabular,
              height: 1.1,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: badge,
    );
  }
}

/// Quanto o bloco pesa na linha.
enum DateBadgeTone {
  /// O padrão: escala marcada.
  normal,

  /// Tingido de violeta — para o que já é sobre você.
  primary,

  /// Apagado: proposta, data ainda sem escala.
  muted,
}
