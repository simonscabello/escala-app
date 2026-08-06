import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Destaque de "onde eu apareço".
///
/// Usa o acento dourado, e não o verde da marca: numa tela inteira em verde,
/// mais verde não destaca nada. Esta é a única informação da escala que é
/// pessoal, e ela precisa ser encontrada sem procurar.
class YouHighlight extends StatelessWidget {
  const YouHighlight({
    super.key,
    required this.label,
    this.compact = false,
    this.onDarkSurface = false,
  });

  final String label;

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

    if (compact) {
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
            Icon(Icons.star_rounded, size: 15, color: foreground),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
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
            child: Icon(Icons.star_rounded, size: 20, color: foreground),
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
                Text(
                  label,
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
