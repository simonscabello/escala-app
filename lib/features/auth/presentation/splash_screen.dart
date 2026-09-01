import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_brand_mark.dart';

/// Exibida enquanto o AuthController verifica se existe sessao salva.
/// O redirect do go_router tira o usuario daqui assim que o estado resolve.
///
/// É o primeiro frame do app, e por isso a única tela em que a marca aparece
/// grande. O indicador fica no mesmo bloco da marca, no centro da viewport —
/// um `Column` solto no `Scaffold` encolhe à largura do texto e encosta à
/// esquerda, que é o que fazia a abertura parecer desalinhada em tablet e no
/// navegador.
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                const SizedBox(height: AppSpacing.xxl),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                    backgroundColor: Color(0x4DFFFFFF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
