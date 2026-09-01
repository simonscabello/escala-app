import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_brand_mark.dart';

/// Exibida enquanto o AuthController verifica se existe sessao salva.
/// O redirect do go_router tira o usuario daqui assim que o estado resolve.
///
/// É o primeiro frame do app, e por isso a única tela em que a marca aparece
/// grande. A rodinha saiu do centro das atenções e virou um fio no rodapé: ela
/// informa que algo acontece, mas não é o assunto — quando a sessão está salva
/// esta tela dura menos de um segundo, e um indicador girando no meio dela
/// transformava a abertura numa espera.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // A mesma cor da abertura nativa do Android: o primeiro frame do Flutter
      // substitui o splash do sistema sem um clarão ou uma troca de marca.
      backgroundColor: AppColors.lightPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 4),
              const AppBrandGlyph(size: 108, color: Colors.white),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Louve!',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sua escala, clara e no lugar certo.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.lightPrimaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 5),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  child: const LinearProgressIndicator(
                    minHeight: 3,
                    color: Colors.white,
                    backgroundColor: Color(0x4DFFFFFF),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
