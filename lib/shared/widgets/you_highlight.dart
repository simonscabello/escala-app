import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/events/domain/event_models.dart';
import 'position_icon.dart';

/// Destaque de "onde eu apareço".
///
/// Usa o acento dourado, e não o verde da marca: numa tela inteira em verde,
/// mais verde não destaca nada. Esta é a única informação da escala que é
/// pessoal, e ela precisa ser encontrada sem procurar.
///
/// Recebe as **funções**, não um texto pronto: a versão grande já tem "VOCÊ"
/// como sobretítulo, e receber "VOCÊ: Bateria" fazia a palavra aparecer duas
/// vezes, uma embaixo da outra. Quem monta o texto é o widget, que sabe qual
/// das duas formas está desenhando.
class YouHighlight extends StatelessWidget {
  const YouHighlight({
    super.key,
    required this.positionNames,
    this.compact = false,
    this.onDarkSurface = false,
  });

  /// Funções em que a pessoa está escalada nesta escala.
  ///
  /// Com exatamente uma, o ícone da função substitui a estrela — "você toca
  /// bateria" fica visível antes de ler o texto. Com duas ou mais não há ícone
  /// que represente o conjunto, e a estrela continua.
  final List<String> positionNames;

  /// Versão para dentro de listas e cards menores.
  final bool compact;

  /// Sobre o gradiente do cartão herói, onde o container claro precisa ceder
  /// lugar a uma superfície translúcida.
  final bool onDarkSurface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final background = onDarkSurface
        ? Colors.white.withValues(alpha: 0.18)
        : AppColors.accentContainer(scheme);
    final foreground =
        onDarkSurface ? Colors.white : AppColors.onAccentContainer(scheme);
    final single = positionNames.length == 1 ? positionNames.first : null;

    Widget markerIcon(double size) {
      if (single == null) {
        return Icon(Icons.star_rounded, size: size, color: foreground);
      }
      return PositionIcon(single, size: size * 0.85, color: foreground);
    }

    if (compact) {
      // Uma linha só: aqui não há sobretítulo, então o "VOCÊ:" precisa vir
      // junto do nome da função.
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            markerIcon(15),
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
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: onDarkSurface
                  ? Colors.white.withValues(alpha: 0.22)
                  : AppColors.accent(scheme).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Center(child: markerIcon(20)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VOCÊ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                // Só as funções: o "VOCÊ" já está na linha de cima.
                Text(
                  positionNames.join(', '),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
