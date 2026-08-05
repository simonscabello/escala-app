import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/cache_stamp_banner.dart';
import '../../auth/application/auth_controller.dart';
import '../../team/data/team_repository.dart';
import '../data/event_repository.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';
import 'duplicate_event_dialog.dart';

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  String _scope = 'upcoming';

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final teamId = ref.watch(activeTeamIdProvider);

    if (auth.teams.isEmpty || teamId == null) {
      return const _AgendaOnboarding();
    }

    final events = ref.watch(eventsProvider((teamId, _scope)));
    final team = auth.teams.first;
    final canManage = team.canManage;
    final membershipId = team.membershipId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              tooltip: 'Criar culto',
              onPressed: () => context.push('/agenda/novo'),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.listPadding,
              AppSpacing.md,
              AppSpacing.listPadding,
              AppSpacing.sm,
            ),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'upcoming',
                  label: Text('Próximos'),
                  icon: Icon(Icons.upcoming_outlined, size: 18),
                ),
                ButtonSegment(
                  value: 'past',
                  label: Text('Passados'),
                  icon: Icon(Icons.history_rounded, size: 18),
                ),
              ],
              selected: {_scope},
              onSelectionChanged: (selection) {
                setState(() => _scope = selection.first);
              },
            ),
          ),
          Expanded(
            child: events.when(
              loading: () => const AppLoading(),
              error: (error, _) => AppErrorState(
                message: error is ApiException
                    ? error.message
                    : 'Não foi possível carregar a agenda.',
                onRetry: () =>
                    ref.invalidate(eventsProvider((teamId, _scope))),
              ),
              data: (cached) => _EventsList(
                events: cached.data,
                showFeaturedEvent: _scope == 'upcoming',
                canManage: canManage,
                membershipId: membershipId,
                fromCache: cached.fromCache,
                cachedAt: cached.cachedAt,
                onRefresh: () =>
                    ref.refresh(eventsProvider((teamId, _scope)).future),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaOnboarding extends ConsumerWidget {
  const _AgendaOnboarding();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(authControllerProvider.notifier).reloadTeams(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Text(
              'Olá, ${user?.firstName ?? ''}',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Crie uma equipe ou entre com um convite para ver suas escalas.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const _OnboardingCards(),
          ],
        ),
      ),
    );
  }
}

class _OnboardingCards extends StatelessWidget {
  const _OnboardingCards();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OnboardingCard(
          icon: Icons.groups_rounded,
          title: 'Sou o líder da equipe',
          message:
              'Crie a equipe e cadastre os integrantes. Ninguém precisa ter conta ainda.',
          actionLabel: 'Criar equipe',
          filled: true,
          onAction: () => context.push('/equipe/nova'),
          iconBackground: scheme.primaryContainer,
          iconColor: scheme.onPrimaryContainer,
        ),
        const SizedBox(height: AppSpacing.lg),
        _OnboardingCard(
          icon: Icons.link_rounded,
          title: 'Recebi um convite',
          message: 'Cole o código que o líder da equipe enviou para você.',
          actionLabel: 'Entrar com código',
          filled: false,
          onAction: () => context.push('/convite'),
          iconBackground: scheme.secondaryContainer,
          iconColor: scheme.onSecondaryContainer,
        ),
      ],
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.filled,
    required this.onAction,
    required this.iconBackground,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final bool filled;
  final VoidCallback onAction;
  final Color iconBackground;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (filled)
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel),
              )
            else
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventsList extends StatelessWidget {
  const _EventsList({
    required this.events,
    required this.showFeaturedEvent,
    required this.canManage,
    required this.membershipId,
    required this.fromCache,
    required this.cachedAt,
    required this.onRefresh,
  });

  final List<Event> events;
  final bool showFeaturedEvent;
  final bool canManage;
  final String membershipId;
  final bool fromCache;
  final DateTime? cachedAt;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (fromCache && cachedAt != null)
              CacheStampBanner(cachedAt: cachedAt!),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: AppEmptyState(
                icon: Icons.event_available_outlined,
                title: 'Nenhum culto por aqui',
                message: canManage
                    ? 'Toque em + para criar o primeiro culto da equipe.'
                    : 'Quando o líder cadastrar um culto, ele aparece aqui.',
              ),
            ),
          ],
        ),
      );
    }

    final featuredEvent = showFeaturedEvent ? events.first : null;
    final remainingEvents = showFeaturedEvent ? events.skip(1) : events;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.listPadding,
          fromCache ? 0 : AppSpacing.sm,
          AppSpacing.listPadding,
          96,
        ),
        children: [
          if (fromCache && cachedAt != null) ...[
            CacheStampBanner(cachedAt: cachedAt!),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (featuredEvent != null) ...[
            _FeaturedEventCard(
              event: featuredEvent,
              canManage: canManage,
              membershipId: membershipId,
            ),
            if (remainingEvents.isNotEmpty)
              const SizedBox(height: AppSpacing.lg),
          ],
          ...remainingEvents.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _EventTile(
                event: event,
                canManage: canManage,
                membershipId: membershipId,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YouChip extends StatelessWidget {
  const _YouChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_pin_circle_rounded,
            size: 16,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedEventCard extends ConsumerWidget {
  const _FeaturedEventCard({
    required this.event,
    required this.canManage,
    required this.membershipId,
  });

  final Event event;
  final bool canManage;
  final String membershipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timezone =
        event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone;
    final hasPalette = event.colorPalette?.isNotEmpty ?? false;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final youLabel =
        youAssignmentLabel(event.positionsForMembership(membershipId));

    return Card(
      child: InkWell(
        onTap: () => context.push('/agenda/${event.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasPalette)
              Container(
                color: scheme.tertiaryContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.sm + 2,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 18,
                      color: scheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        event.colorPalette!,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatEventWeekdayDate(event.startsAt, timezone),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (canManage)
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'duplicate') {
                              await showDuplicateEventDialog(
                                context: context,
                                ref: ref,
                                source: event,
                              );
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'duplicate',
                              child: Text('Duplicar culto'),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(event.title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.lg),
                    _TimeRow(
                    icon: Icons.event_available_rounded,
                    label: 'Culto',
                    value: formatEventTime(event.startsAt, timezone),
                    emphasized: true,
                  ),
                  if (event.rehearsalAt != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _TimeRow(
                      icon: Icons.schedule_rounded,
                      label: 'Ensaio',
                      value: formatEventTime(event.rehearsalAt!, timezone),
                    ),
                  ],
                  if (youLabel != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _YouChip(label: youLabel),
                  ],
                  if (event.notes?.isNotEmpty ?? false) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      event.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
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
      children: [
        Icon(
          icon,
          size: 20,
          color: emphasized ? scheme.primary : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$label ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: (emphasized ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge)
              ?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _EventTile extends ConsumerWidget {
  const _EventTile({
    required this.event,
    required this.canManage,
    required this.membershipId,
  });

  final Event event;
  final bool canManage;
  final String membershipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timezone =
        event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final youLabel =
        youAssignmentLabel(event.positionsForMembership(membershipId));

    return Card(
      child: InkWell(
        onTap: () => context.push('/agenda/${event.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatEventWeekdayDate(event.startsAt, timezone),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(event.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Culto ${formatEventTime(event.startsAt, timezone)}'
                      '${event.rehearsalAt == null ? '' : ' · Ensaio ${formatEventTime(event.rehearsalAt!, timezone)}'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (youLabel != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _YouChip(label: youLabel),
                    ],
                  ],
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'duplicate') {
                      await showDuplicateEventDialog(
                        context: context,
                        ref: ref,
                        source: event,
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Text('Duplicar culto'),
                    ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
