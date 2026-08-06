import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_spacing.dart';
import '../../features/events/domain/event_datetime.dart';

/// Bloco de data no padrao de aplicativos de calendario: numero grande, dia da
/// semana e mes em cima e embaixo.
///
/// Numa agenda, o olho procura o dia antes do titulo. Uma linha corrida
/// ("Domingo, 9 de agosto") obriga a ler; o bloco se reconhece de relance.
class DateBadge extends StatelessWidget {
  const DateBadge({
    super.key,
    required this.date,
    required this.timezone,
    this.background,
    this.foreground,
    this.muted,
    this.size = DateBadgeSize.medium,
  });

  final DateTime date;
  final String timezone;
  final Color? background;
  final Color? foreground;

  /// Cor do dia da semana e do mes.
  final Color? muted;
  final DateBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final local = eventLocalTime(date, timezone);

    final weekday = DateFormat('EEE', 'pt_BR')
        .format(local)
        .replaceAll('.', '')
        .toUpperCase();
    final month = DateFormat('MMM', 'pt_BR')
        .format(local)
        .replaceAll('.', '')
        .toUpperCase();

    final isLarge = size == DateBadgeSize.large;
    final bg = background ?? scheme.surfaceContainerHigh;
    final fg = foreground ?? scheme.onSurface;
    final dim = muted ?? scheme.onSurfaceVariant;

    return Container(
      width: isLarge ? 68 : 56,
      padding: EdgeInsets.symmetric(vertical: isLarge ? 12 : 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            weekday,
            style: theme.textTheme.labelSmall?.copyWith(
              color: dim,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '${local.day}',
            style: (isLarge
                    ? theme.textTheme.headlineMedium
                    : theme.textTheme.headlineSmall)
                ?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            month,
            style: theme.textTheme.labelSmall?.copyWith(
              color: dim,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

enum DateBadgeSize { medium, large }
