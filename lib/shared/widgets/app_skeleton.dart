import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Bloco cinza no lugar do conteúdo que ainda não chegou.
///
/// **Por que não um rodinha centralizada.** A rodinha diz "espere" e nada mais:
/// a tela fica vazia, salta para cheia, e o olho recomeça a leitura do zero. O
/// esqueleto já mostra a forma do que vem — a pessoa sabe que é uma lista de
/// escalas antes de os dados chegarem, e o conteúdo entra sem sacudir o layout.
///
/// A pulsação **para** quando o sistema pede menos animação
/// (`MediaQuery.disableAnimations`, que é o que "reduzir movimento" liga no
/// Android e no iOS). Movimento repetitivo na tela inteira é justamente o que
/// incomoda quem ativou essa opção, e o esqueleto continua se explicando parado.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppSpacing.radiusSm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);

    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );

    if (still) return box;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: box,
    );
  }
}

/// Lista carregando: cartões com a mesma altura e o mesmo ritmo dos de verdade.
class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({
    super.key,
    this.itemCount = 4,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.sm,
      AppSpacing.xl,
      AppSpacing.xl,
    ),
    this.leadingBlock = false,
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  /// Um quadrado à esquerda, para as listas que abrem com avatar ou com o tom
  /// da música. Sem isto o esqueleto prometeria uma forma diferente da que vem.
  final bool leadingBlock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ExcludeSemantics(
      child: ListView.separated(
        padding: padding,
        itemCount: itemCount,
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, index) => Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leadingBlock) ...[
                const AppSkeleton(
                  width: 44,
                  height: 44,
                  radius: AppSpacing.radiusMd,
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Larguras diferentes por item: barras idênticas leem-se
                    // como uma tabela travada, não como texto chegando.
                    AppSkeleton(width: index.isEven ? 170 : 210, height: 15),
                    const SizedBox(height: AppSpacing.sm),
                    AppSkeleton(width: index.isEven ? 230 : 190, height: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
