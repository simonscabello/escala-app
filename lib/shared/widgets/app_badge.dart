import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status_colors.dart';

/// Etiqueta curta: papel na equipe, tom da música, "avisou que não pode".
///
/// **Por que virou um componente.** A mesma coisa estava desenhada em cinco
/// lugares com cinco receitas: `primary` com 12% de alfa na lista de
/// integrantes, `errorContainer` na indisponibilidade, `surfaceContainerHighest`
/// no tom da escala, texto âmbar solto em "fora do cadastro". Todas diziam
/// "esta informação é uma etiqueta" — em quatro alturas e três raios
/// diferentes.
///
/// A cor sai de [AppTone], então escolher o tom é escolher o significado, e não
/// escolher um valor de cor.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppTone.neutral,
    this.icon,
    this.semanticsLabel,
    this.emphasis = BadgeEmphasis.soft,
  });

  final String label;
  final AppTone tone;
  final IconData? icon;

  /// O que o leitor de tela anuncia no lugar de [label].
  ///
  /// Serve para os rótulos que só fazem sentido com a cor junto: "F#" é o tom,
  /// mas quem não distingue o âmbar do azul precisa ouvir "tom sugerido pela
  /// gravação, ainda não escolhido pela equipe".
  final String? semanticsLabel;

  final BadgeEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppStatusColors.of(context).resolve(tone, theme.colorScheme);
    final solid = emphasis == BadgeEmphasis.solid;
    final background = solid ? palette.foreground : palette.container;
    final foreground = solid ? palette.onForeground : palette.onContainer;

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: icon == null ? AppSpacing.sm : 6,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: foreground),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
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

/// `soft` é o padrão: fundo do container, texto escuro. `solid` é para quando a
/// etiqueta precisa ser vista antes de tudo na linha — e é raro.
enum BadgeEmphasis { soft, solid }
