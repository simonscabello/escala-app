import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_card.dart';

/// A manchete: o bloco violeta que abre uma tela.
///
/// **Existe porque agora há duas.** A agenda sempre teve a sua
/// (`ScheduleHeroCard`, a próxima escala da equipe) e a Home ganhou a dela (a
/// próxima escala **sua**). São conteúdos diferentes com a mesma casca — o
/// gradiente da marca, o recorte, as duas manchas de luz, a folga interna —, e
/// deixar isso copiado garantiria que as duas divergissem no primeiro ajuste.
///
/// A casca mora aqui; o conteúdo é de quem chama. Nada de decisão editorial
/// neste arquivo: ele não sabe o que é uma escala.
///
/// Sobre a rampa não há borda — quem separa o bloco da página é a própria
/// diferença de tinta (ver [AppCard]).
class AppHeroCard extends StatelessWidget {
  const AppHeroCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      gradient: AppColors.heroGradient(scheme),
      child: Stack(
        children: [
          // Duas manchas de luz, e nada mais. O recorte do cartão corta o que
          // passa da borda, então elas leem como um brilho vindo de fora e não
          // como dois círculos desenhados dentro do bloco. 5% e 4%: abaixo
          // disso não se percebe, acima vira textura de papel de parede.
          const Positioned(
            right: -70,
            top: -90,
            child: _Glow(size: 210, alpha: 0.05),
          ),
          const Positioned(
            right: 20,
            bottom: -120,
            child: _Glow(size: 190, alpha: 0.04),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// A ação de uma manchete: "Ver detalhes →", "Ver escala →".
///
/// Contida e à direita, e não larga na base do cartão: um botão que atravessa a
/// manchete inteira compete com a data pelo primeiro olhar, e a data é que
/// identifica a escala. À direita ele fica no fim natural da leitura e no
/// alcance do polegar.
class HeroActionButton extends StatelessWidget {
  const HeroActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        // A tinta clara da marca sobre o violeta escuro: o mesmo par do botão
        // primário do tema escuro, que é o contexto em que este botão vive
        // mesmo quando o app está no tema claro.
        backgroundColor: AppColors.brandLavender,
        foregroundColor: AppColors.brandDeepViolet,
        // Menor que o botão principal de um formulário (52): aqui ele é a ação
        // de um cartão, não a ação da tela.
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        textStyle: theme.textTheme.labelLarge,
      ).copyWith(
        overlayColor: WidgetStatePropertyAll(
          theme.colorScheme.shadow.withValues(alpha: 0.08),
        ),
      ),
      // A seta segue o texto; `iconAlignment` é o que evita montar uma `Row`
      // à mão só para inverter a ordem.
      iconAlignment: IconAlignment.end,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// Uma mancha de luz atrás do conteúdo da manchete.
class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.onHero.withValues(alpha: alpha),
        ),
      ),
    );
  }
}
