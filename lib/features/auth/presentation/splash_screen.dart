import 'package:flutter/material.dart';

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
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 3),
              const AppBrandMark(size: 60),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Escalas de Louvor',
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sua escala, clara e no lugar certo.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: scheme.surfaceContainerHigh,
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
