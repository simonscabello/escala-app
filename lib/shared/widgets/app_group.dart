import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status_colors.dart';
import 'app_card.dart';
import 'section_header.dart';

/// Várias linhas, **uma** superfície.
///
/// Esta é a mudança estrutural do redesenho. O app resolvia toda lista dando um
/// cartão a cada item: no Perfil, três cartões para três linhas de texto; em
/// Gerenciar equipe, quatro; na equipe, um por pessoa. Cada um com sua borda,
/// sua sombra e sua margem, o que produzia uma pilha de caixinhas flutuando —
/// exatamente o "dashboardzão de cards" que denuncia interface montada com peça
/// pronta. E o custo não era só estético: quatro molduras dizem "quatro
/// assuntos", quando o que existe ali é **um** assunto com quatro linhas.
///
/// Aqui o grupo é o objeto e a linha é conteúdo dele. Uma borda em volta de
/// tudo, fios de cabelo entre as linhas.
///
/// **O fio começa onde o texto começa**, não na borda do cartão. É um detalhe
/// de meio centímetro e é o que separa uma lista desenhada de uma lista
/// dividida: alinhado ao texto, o fio parece organizar a leitura; encostado na
/// borda, parece cortar o cartão ao meio.
class AppGroup extends StatelessWidget {
  const AppGroup({
    super.key,
    required this.children,
    this.title,
    this.subtitle,
    this.trailing,
    this.dividerIndent = iconIndent,
  });

  final List<Widget> children;

  /// Cabeçalho acima do grupo. Sem ele, o grupo entra direto.
  final String? title;
  final String? subtitle;
  final Widget? trailing;

  /// Onde o fio de divisão começa. O padrão alinha com o texto de uma linha que
  /// tem ícone; use [textIndent] em grupos sem ícone.
  final double dividerIndent;

  /// Recuo das linhas com ícone: folga + ícone + intervalo.
  static const double iconIndent = AppSpacing.lg + 22 + AppSpacing.md;

  /// Recuo das linhas sem ícone.
  static const double textIndent = AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          SectionHeader(
            title: title!,
            subtitle: subtitle,
            trailing: trailing,
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.md,
            ),
          ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: dividerIndent,
                    color: scheme.outlineVariant,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Uma linha dentro de um [AppGroup].
///
/// O ícone perdeu o quadrado tingido que tinha antes. Um azulzinho arredondado
/// atrás de cada ícone é o enfeite mais comum de interface genérica: multiplica
/// a cor da marca por quantas linhas houver na tela e, de tanto aparecer, para
/// de significar qualquer coisa. Aqui o ícone é só o ícone, no cinza do texto
/// de apoio — e o azul fica livre para dizer "é aqui que **você** entra", que é
/// a única coisa que ele deveria dizer neste app.
class AppGroupRow extends StatelessWidget {
  const AppGroupRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.tone,
    this.showChevron = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Substitui a seta. Duas indicações de destino na mesma linha é uma a mais.
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Tinge ícone e título — só para linhas que **são** o estado que descrevem
  /// (sair da conta, excluir). Fora disso, nada de cor.
  final AppTone? tone;

  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette =
        tone == null ? null : AppStatusColors.of(context).resolve(tone!, scheme);
    final foreground = palette?.foreground ?? scheme.onSurface;

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 22,
              color: palette?.foreground ?? scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.md),
            trailing!,
          ] else if (showChevron && onTap != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              // Mais apagada que o texto de apoio: a seta é a peça menos
              // importante da linha e antes tinha o mesmo peso do subtítulo.
              color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          child: row,
        ),
      ),
    );
  }
}
