import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../domain/agenda_entry.dart';
import '../domain/event_datetime.dart';
import 'duplicate_event_dialog.dart';

class AgendaEntryCard extends ConsumerWidget {
  const AgendaEntryCard({
    super.key,
    required this.entry,
    required this.membershipId,
    required this.canManage,
  });

  final AgendaEntry entry;
  final String membershipId;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final event = entry.event;
    final positions = event.positionsForMembership(membershipId);
    final people = {
      for (final group in event.assignments)
        for (final member in group.members) member.membershipId,
    }.length;
    final songs = entry.service.songCount;

    return AppCard(
      onTap: () => context.push('/agenda/${event.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      formatEventTime(entry.startsAt, entry.timezone),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                    if (event.hasTitle)
                      Text(
                        entry.service.label,
                        style: theme.textTheme.bodySmall,
                      ),
                    if (event.isDraft)
                      const AppBadge(label: 'Rascunho', tone: AppTone.warning),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(entry.title, style: theme.textTheme.titleSmall),
                if (positions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Você: ${positions.join(' · ')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (people > 0 || songs != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    [
                      if (people > 0)
                        '$people ${people == 1 ? 'pessoa' : 'pessoas'}',
                      if (songs != null)
                        songs == 0
                            ? 'Músicas a definir'
                            : '$songs ${songs == 1 ? 'música' : 'músicas'}',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                if (event.rehearsalAt != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Ensaio ${formatEventShortDate(event.rehearsalAt!, entry.timezone)} · ${formatEventTime(event.rehearsalAt!, entry.timezone)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          if (canManage && FeatureFlags.duplicateSchedule)
            PopupMenuButton<String>(
              tooltip: 'Mais opções desta escala',
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              onSelected: (_) => showDuplicateEventDialog(
                context: context,
                ref: ref,
                source: event,
              ),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'duplicate',
                  child: Text('Duplicar escala'),
                ),
              ],
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}
