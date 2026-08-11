import 'package:flutter/material.dart';

import '../../core/storage/read_cache.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_status_colors.dart';
import '../../features/events/domain/event_datetime.dart';

/// Faixa discreta quando a tela está mostrando dados do cache local.
///
/// Ardósia (`info`), e não âmbar nem vermelho: estar sem rede na igreja é
/// comum, e o que a escala mostra continua **válido**. A faixa informa a idade
/// do que está na tela; ela não pede providência nenhuma.
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
    final palette = AppStatusColors.of(context).info;

    return Semantics(
      // Aparecer e sumir é o próprio conteúdo desta faixa: quem usa leitor de
      // tela precisa ouvir que o que está lendo veio do aparelho, não da rede.
      liveRegion: true,
      child: Material(
        color: palette.container,
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
                color: palette.onContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Sem conexão. Atualizado às $hh:$mm',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.onContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
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
