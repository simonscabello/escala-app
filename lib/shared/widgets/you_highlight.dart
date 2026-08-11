import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../features/events/domain/event_models.dart';
import 'position_icon.dart';

/// Destaque de "onde eu apareço".
///
/// Chip de uma linha no azul da marca: e a unica informacao pessoal da escala,
/// e precisa saltar sem virar um bloco gordo.
///
/// Recebe as **funcoes**, nao um texto pronto: o rotulo "VOCE:" e montado aqui.
class YouHighlight extends StatelessWidget {
  const YouHighlight({
    super.key,
    required this.positionNames,
  });

  /// Funcoes em que a pessoa esta escalada nesta escala.
  ///
  /// Com exatamente uma, o icone da funcao substitui a estrela — "voce toca
  /// bateria" fica visivel antes de ler o texto. Com duas ou mais nao ha icone
  /// que represente o conjunto, e a estrela continua.
  final List<String> positionNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = scheme.onPrimaryContainer;
    final single = positionNames.length == 1 ? positionNames.first : null;

    final Widget marker = single == null
        ? Icon(Icons.star_rounded, size: 15, color: foreground)
        : PositionIcon(single, size: 13, color: foreground);

    // O rótulo na tela é curto ("VOCÊ: Bateria") porque cabe numa linha de
    // cartão. Para quem ouve, a frase inteira: é a única informação pessoal da
    // escala, e "VOCÊ dois pontos bateria" não é como se diz isso.
    return Semantics(
      label: positionNames.isEmpty
          ? null
          : positionNames.length == 1
              ? 'Você está escalado em ${positionNames.first}'
              : 'Você está escalado em ${positionNames.join(' e ')}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            marker,
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                youAssignmentLabel(positionNames) ?? '',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
