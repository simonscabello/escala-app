import 'package:flutter/material.dart';

import '../../core/storage/read_cache.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/events/domain/event_datetime.dart';

/// Faixa discreta quando a tela está mostrando dados do cache local.
class CacheStampBanner extends StatelessWidget {
  const CacheStampBanner({super.key, required this.cachedAt});

  final DateTime cachedAt;

  @override
  Widget build(BuildContext context) {
    final local = eventLocalTime(
      cachedAt.toUtc(),
      'America/Sao_Paulo',
    );
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 18,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Sem conexão. Atualizado às $hh:$mm',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatCacheStamp(DateTime cachedAt) {
  final local = eventLocalTime(cachedAt.toUtc(), 'America/Sao_Paulo');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return 'atualizado às $hh:$mm';
}

extension CachedValueX<T> on CachedValue<T> {
  String? get stampLabel {
    if (!fromCache || cachedAt == null) return null;
    return formatCacheStamp(cachedAt!);
  }
}
