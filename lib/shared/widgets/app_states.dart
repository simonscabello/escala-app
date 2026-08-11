import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status_colors.dart';

/// Indicador de carregamento centralizado.
///
/// Sobrou para o que não tem forma previsível (abrir uma escala, um formulário
/// buscando o que vai editar). Onde o que vem é uma **lista**, use
/// `AppListSkeleton`: ele mostra o formato do conteúdo em vez de só pedir para
/// esperar.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado vazio.
///
/// Um vazio bem escrito responde três coisas: **o que deveria estar aqui**, por
/// que não está, e o que fazer agora. Sem a terceira ele vira uma tela morta —
/// e era o caso do repertório, que dizia "Nenhuma música" a quem não tem
/// permissão de acrescentar nenhuma.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.tone = AppTone.primary,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// A ação principal. Só aparece com [onAction] junto — antes um rótulo sem
  /// callback (ou o contrário) sumia sem aviso, e a tela ficava sem saída.
  final String? actionLabel;
  final VoidCallback? onAction;

  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = AppStatusColors.of(context).resolve(tone, scheme);
    final hasAction = actionLabel != null && onAction != null;
    final hasSecondary = secondaryLabel != null && onSecondary != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          // Sem teto, a mensagem virava uma linha só atravessando o tablet.
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: palette.container,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: Icon(icon, size: 34, color: palette.onContainer),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (hasAction) ...[
                const SizedBox(height: AppSpacing.xl),
                // Preenchido, e não tonal: é a única coisa a fazer na tela, e
                // o tonal claro lia-se como botão desabilitado.
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
              if (hasSecondary) ...[
                const SizedBox(height: AppSpacing.xs),
                TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado de erro com nova tentativa.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.title = 'Algo deu errado',
    required this.message,
    this.onRetry,
    this.retryLabel = 'Tentar de novo',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = AppStatusColors.of(context).danger;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: palette.container,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: Icon(
                    Icons.cloud_off_rounded,
                    size: 34,
                    color: palette.onContainer,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(retryLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Mensagem que ocupa a tela **e** aceita "puxar para atualizar".
///
/// Substitui o truque que estava copiado em quatro listas: um `ListView` com um
/// `SizedBox(height: altura da tela * 0.5)` em volta do vazio. Aquilo chutava a
/// altura — em paisagem e em tablet a mensagem saía do centro, e num aparelho
/// baixo ela era cortada. Aqui o `LayoutBuilder` usa a altura real disponível.
/// A faixa de cache, quando existe, fica **fora** daqui: o chamador a põe numa
/// `Column` acima, onde ela permanece visível em vez de rolar junto.
class RefreshableMessage extends StatelessWidget {
  const RefreshableMessage({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          // Sem isto não há o que arrastar numa tela sem conteúdo, e "puxar
          // para atualizar" — a saída óbvia de um vazio que não deveria estar
          // vazio — simplesmente não responde.
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      ),
    );
  }
}
