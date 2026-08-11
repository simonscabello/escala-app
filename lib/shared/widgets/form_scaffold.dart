import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status_colors.dart';
import 'app_brand_mark.dart';

/// Moldura comum das telas de formulario (login, cadastro, troca de senha).
class FormScaffold extends StatelessWidget {
  const FormScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.appBar,
    this.showBrand = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final PreferredSizeWidget? appBar;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        // Alinhado ao topo quando há AppBar: centralizar deixava um vazio
        // grande entre a barra e o título do formulário.
        child: Align(
          alignment:
              appBar == null ? Alignment.center : Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.formMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showBrand) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: AppBrandLockup(),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                  Text(title, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Faixa de erro exibida acima dos botoes dos formularios.
///
/// `liveRegion: true` é o que faz o leitor de tela **anunciar** o erro quando
/// ele aparece. Sem isso, quem toca em "Entrar" com a senha errada não recebe
/// resposta nenhuma: o foco continua no botão, a faixa surge fora do caminho, e
/// o app parece ter ignorado o toque.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppStatusColors.of(context).danger;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.container,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border(
            // Barra à esquerda, como na faixa de indisponibilidade do detalhe
            // da escala: é a mesma ideia visual de "atenção neste bloco", e
            // tê-la em dois desenhos diferentes fazia parecerem coisas
            // distintas.
            left: BorderSide(color: palette.foreground, width: 4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 20,
              color: palette.onContainer,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.onContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
