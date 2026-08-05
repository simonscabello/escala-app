import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/cache_stamp_banner.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../data/event_repository.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';
import '../domain/schedule_share_text.dart';
import 'duplicate_event_dialog.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final teams = ref.watch(authControllerProvider).teams;
    final canManage = teams.firstOrNull?.canManage ?? false;

    return eventAsync.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Escala')),
        body: AppErrorState(
          message: error is ApiException
              ? error.message
              : 'Não foi possível carregar o culto.',
          onRetry: () => ref.invalidate(eventProvider(eventId)),
        ),
      ),
      data: (cached) {
        final event = cached.data;
        final myMembershipId = teams
            .where((t) => t.teamId == event.teamId)
            .map((t) => t.membershipId)
            .firstOrNull;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Escala'),
            actions: [
              IconButton(
                tooltip: 'Compartilhar escala',
                onPressed: () => SharePlus.instance.share(
                  ShareParams(text: buildScheduleShareText(event)),
                ),
                icon: const Icon(Icons.share_outlined),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'assign':
                        context.push('/agenda/${event.id}/escalar');
                      case 'edit':
                        context.push('/agenda/${event.id}/editar');
                      case 'duplicate':
                        await showDuplicateEventDialog(
                          context: context,
                          ref: ref,
                          source: event,
                        );
                      case 'delete':
                        await _confirmDelete(context, ref, event);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'assign',
                      child: Text('Escalar equipe'),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Editar culto'),
                    ),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Text('Duplicar culto'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Excluir culto'),
                    ),
                  ],
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => ref.refresh(eventProvider(eventId).future),
            child: _EventDetailBody(
              event: event,
              myMembershipId: myMembershipId,
              fromCache: cached.fromCache,
              cachedAt: cached.cachedAt,
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Event event,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir culto?'),
        content: Text('O culto "${event.title}" será removido.'),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => dialogContext.pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(eventRepositoryProvider).remove(event.id);
      ref.invalidate(eventsProvider((event.teamId, 'upcoming')));
      ref.invalidate(eventsProvider((event.teamId, 'past')));
      ref.invalidate(eventProvider(event.id));
      if (context.mounted) context.pop();
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }
}

class _EventDetailBody extends StatelessWidget {
  const _EventDetailBody({
    required this.event,
    required this.myMembershipId,
    required this.fromCache,
    required this.cachedAt,
  });

  final Event event;
  final String? myMembershipId;
  final bool fromCache;
  final DateTime? cachedAt;

  @override
  Widget build(BuildContext context) {
    final timezone =
        event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final youLabel =
        youAssignmentLabel(event.positionsForMembership(myMembershipId));
    final hasPalette = event.colorPalette?.isNotEmpty ?? false;
    final hasNotes = event.notes?.isNotEmpty ?? false;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        if (fromCache && cachedAt != null)
          CacheStampBanner(cachedAt: cachedAt!),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.xl,
            AppSpacing.screenPadding,
            AppSpacing.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (youLabel != null) ...[
                YouAssignmentBanner(label: youLabel),
                const SizedBox(height: AppSpacing.xl),
              ],
              Text(
                formatEventWeekdayDate(event.startsAt, timezone),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(event.title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xl),
              _ScheduleHero(
                startsAt: event.startsAt,
                rehearsalAt: event.rehearsalAt,
                location: event.location,
                timezone: timezone,
              ),
              if (hasPalette || hasNotes) ...[
                const SizedBox(height: AppSpacing.xl),
                _PaletteNotesCard(
                  palette: hasPalette ? event.colorPalette : null,
                  notes: hasNotes ? event.notes : null,
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              const SectionHeader(title: 'Equipe escalada'),
              if (event.assignments.isEmpty)
                Text(
                  'Ninguém escalado ainda. O líder pode montar a escala pelo menu.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                for (final group in event.assignments) ...[
                  _AssignmentGroupTile(group: group),
                  const SizedBox(height: AppSpacing.sm),
                ],
              const SizedBox(height: AppSpacing.xl),
              Card(
                color: scheme.surfaceContainerLow,
                child: ListTile(
                  leading: Icon(
                    Icons.music_note_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                  title: Text(
                    'Músicas',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  subtitle: Text(
                    'Em breve — repertório do culto.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleHero extends StatelessWidget {
  const _ScheduleHero({
    required this.startsAt,
    required this.rehearsalAt,
    required this.location,
    required this.timezone,
  });

  final DateTime startsAt;
  final DateTime? rehearsalAt;
  final String? location;
  final String timezone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          _DetailItem(
            icon: Icons.calendar_today_outlined,
            label: 'Culto',
            value:
                '${formatEventWeekdayDate(startsAt, timezone)} às ${formatEventTime(startsAt, timezone)}',
            emphasized: true,
          ),
          if (rehearsalAt != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Divider(color: scheme.outlineVariant, height: 1),
            const SizedBox(height: AppSpacing.lg),
            _DetailItem(
              icon: Icons.schedule_rounded,
              label: 'Ensaio',
              value:
                  '${formatEventWeekdayDate(rehearsalAt!, timezone)} às ${formatEventTime(rehearsalAt!, timezone)}',
            ),
          ],
          if (location?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.lg),
            Divider(color: scheme.outlineVariant, height: 1),
            const SizedBox(height: AppSpacing.lg),
            _DetailItem(
              icon: Icons.location_on_outlined,
              label: 'Local',
              value: location!,
            ),
          ],
        ],
      ),
    );
  }
}

class _PaletteNotesCard extends StatelessWidget {
  const _PaletteNotesCard({this.palette, this.notes});

  final String? palette;
  final String? notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        color: scheme.tertiaryContainer.withValues(alpha: 0.45),
        border: Border(
          left: BorderSide(color: scheme.tertiary, width: 4),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (palette != null) ...[
            Row(
              children: [
                Icon(
                  Icons.palette_outlined,
                  size: 18,
                  color: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Paleta',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              palette!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (palette != null && notes != null)
            const SizedBox(height: AppSpacing.md),
          if (notes != null) ...[
            Text(
              'Observações',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(notes!, style: theme.textTheme.bodyLarge),
          ],
        ],
      ),
    );
  }
}

/// Destaque "onde eu apareço" — visível sem rolar.
class YouAssignmentBanner extends StatelessWidget {
  const YouAssignmentBanner({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(
                Icons.person_pin_circle_rounded,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentGroupTile extends StatelessWidget {
  const _AssignmentGroupTile({required this.group});

  final AssignmentGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.positionName,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final member in group.members) ...[
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: scheme.secondaryContainer,
                    foregroundColor: scheme.onSecondaryContainer,
                    child: Text(
                      member.displayName.isNotEmpty
                          ? member.displayName[0].toUpperCase()
                          : '?',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      member.displayName,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  if (!member.isRegisteredForPosition)
                    Text(
                      'fora do cadastro',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.tertiary,
                      ),
                    ),
                ],
              ),
              if (member.note?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 36,
                    top: 2,
                    bottom: AppSpacing.xs,
                  ),
                  child: Text(
                    member.note!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                const SizedBox(height: AppSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: emphasized ? scheme.primary : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: (emphasized
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.bodyLarge)
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
