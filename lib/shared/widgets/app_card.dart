import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Superfície padrão de conteúdo.
///
/// Duas variantes: `elevated` (sombra suave, sem borda) para o conteúdo
/// principal e `outlined` para blocos secundários. A sombra cria hierarquia
/// sem gastar mais cor.
///
/// **A sombra não é o que faz o cartão existir.** Ela é sutil de propósito, e
/// sozinha não segurava a forma: o que separa o cartão da página é a diferença
/// entre a cor dele e a do fundo, garantida na paleta (ver `AppColors`). A
/// sombra só arredonda a transição. Por isso o cartão continua legível com
/// "reduzir transparência/animações" ligado no sistema, e em impressão.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.color,
    this.margin,
    this.elevated = true,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final EdgeInsetsGeometry? margin;
  final bool elevated;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(borderRadius ?? AppSpacing.radiusLg);
    final background = color ?? scheme.surfaceContainerLowest;

    final content =
        padding == null ? child : Padding(padding: padding!, child: child);

    return Container(
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: elevated ? null : Border.all(color: scheme.outlineVariant),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.03),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}
