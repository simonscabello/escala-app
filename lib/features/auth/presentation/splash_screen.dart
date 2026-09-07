import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_brand_mark.dart';

/// Exibida enquanto o AuthController verifica se existe sessao salva.
/// O redirect do go_router tira o usuario daqui assim que o estado resolve.
///
/// É o primeiro frame do app, e por isso a única tela em que a marca aparece
/// grande. O indicador fica no mesmo bloco da marca, no centro da viewport —
/// um `Column` solto no `Scaffold` encolhe à largura do texto e encosta à
/// esquerda, que é o que fazia a abertura parecer desalinhada em tablet e no
/// navegador.
///
/// **Nada anima aqui além do indicador.** A abertura é o intervalo entre tocar
/// no ícone e ver a escala; qualquer coisa que precise de tempo para acontecer
/// só faz esse intervalo parecer maior.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // A mesma cor da abertura nativa do Android e do boot da Web: o primeiro
      // frame do Flutter substitui o splash do sistema sem um clarão ou uma
      // troca de marca.
      backgroundColor: AppColors.brandDeepViolet,
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
                const AppBrandGlyph(size: 96, onDark: true),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'PAUTA',
                  style: AppTypography.wordmark(
                    context,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Sua equipe no mesmo ritmo.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.brandLavender,
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
