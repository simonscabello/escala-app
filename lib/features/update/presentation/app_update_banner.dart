import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../data/version_repository.dart';

class AppUpdateBanner extends ConsumerWidget {
  const AppUpdateBanner({super.key});

  Future<void> _download(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    final opened = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showAppSnackBar(
        context,
        'Não foi possível abrir o download do APK.',
        tone: AppTone.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(appUpdateProvider).valueOrNull;
    if (update == null || !update.updateAvailable) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final url = update.apkUrl;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.system_update_rounded, color: scheme.onPrimaryContainer),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              url == null
                  ? 'Versão ${update.latestVersion} disponível. Peça o APK '
                      'atualizado ao líder.'
                  : 'Versão ${update.latestVersion} disponível.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (url != null)
            TextButton(
              onPressed: () => _download(context, url),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onPrimaryContainer,
              ),
              child: const Text('Atualizar'),
            ),
        ],
      ),
    );
  }
}
