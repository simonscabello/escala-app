import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../features/events/domain/event_models.dart';
import 'position_icon.dart';

/// Destaque de "onde eu apareço".
///
/// Chip de uma linha no violeta da marca: é a única informação pessoal da
/// escala, e precisa saltar sem virar um bloco gordo.
///
/// Recebe as **funções**, não um texto pronto: o rótulo "VOCÊ:" é montado aqui.
class YouHighlight extends StatelessWidget {
  const YouHighlight({
    super.key,
    required this.positionNames,
    this.background,
    this.foreground,
  });

  /// Funções em que a pessoa está escalada nesta escala.
  ///
  /// Com exatamente uma, o ícone da função substitui a estrela — "você toca
  /// bateria" fica visível antes de ler o texto. Com duas ou mais não há ícone
  /// que represente o conjunto, e a estrela continua.
  final List<String> positionNames;

  /// A tinta do chip, quando ele não está sobre um cartão comum.
  ///
  /// A manchete da agenda é violeta escuro, e ali o `primaryContainer` do tema
  /// claro (lavanda) sobre o violeta produz duas manchas da mesma família sem
  /// contraste entre si. Sobre superfície escura o chip vira **claro sobre
  /// escuro**, que é o mesmo gesto lido ao contrário.
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = foreground ?? scheme.onPrimaryContainer;
    final single = positionNames.length == 1 ? positionNames.first : null;

    final Widget marker = single == null
        ? Icon(Icons.star_rounded, size: 15, color: ink)
        : PositionIcon(single, size: 13, color: ink);

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
          color: background ?? scheme.primaryContainer,
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
                  color: ink,
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
