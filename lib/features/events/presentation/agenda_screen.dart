import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/cache_stamp_banner.dart';
import '../../../shared/widgets/date_badge.dart';
import '../../../shared/widgets/you_highlight.dart';
import '../../auth/application/auth_controller.dart';
import '../../team/data/team_repository.dart';
import '../data/event_repository.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';
import 'duplicate_event_dialog.dart';

/// Saudação por horário. Detalhe pequeno, mas é o que separa uma tela de
/// listagem de um app que parece ter sido feito para aquela pessoa.
String greetingForHour(int hour) {
  if (hour < 12) return 'Bom dia';
  if (hour < 18) return 'Boa tarde';
  return 'Boa noite';
}

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

    return Scaffold(
      floatingActionButton: team.canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/agenda/novo'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova escala'),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _GreetingHeader(
              name: auth.user?.firstName ?? '',
              teamName: team.name,
            ),
            _ScopeSwitch(
              scope: _scope,
              onChanged: (value) => setState(() => _scope = value),
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
                  canManage: team.canManage,
                  membershipId: team.membershipId,
                  fromCache: cached.fromCache,
                  cachedAt: cached.cachedAt,
                  onRefresh: () =>
                      ref.refresh(eventsProvider((teamId, _scope)).future),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.name, required this.teamName});

  final String name;
  final String teamName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${greetingForHour(DateTime.now().hour)},',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      size: 14,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        teamName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // O avatar saiu daqui: virou a aba "Perfil" na barra inferior, e ter
          // os dois caminhos para o mesmo lugar na mesma tela era ruído.
        ],
      ),
    );
  }
}

/// Alternador leve entre próximos e passados. Um SegmentedButton pesava demais
/// para uma escolha de duas opções que muda a lista inteira.
class _ScopeSwitch extends StatelessWidget {
  const _ScopeSwitch({required this.scope, required this.onChanged});

  final String scope;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          _ScopeTab(
            label: 'Próximos',
            selected: scope == 'upcoming',
            onTap: () => onChanged('upcoming'),
          ),
          const SizedBox(width: AppSpacing.sm),
          _ScopeTab(
            label: 'Passados',
            selected: scope == 'past',
            onTap: () => onChanged('past'),
          ),
        ],
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(authControllerProvider.notifier).reloadTeams(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            children: [
              Text(
                '${greetingForHour(DateTime.now().hour)}, '
                '${user?.firstName ?? ''}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Você ainda não faz parte de uma equipe.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _OnboardingCard(
                icon: Icons.groups_rounded,
                title: 'Sou o líder da equipe',
                message: 'Crie a equipe e cadastre os integrantes. '
                    'Ninguém precisa ter conta ainda.',
                actionLabel: 'Criar equipe',
                filled: true,
                onAction: () => context.push('/equipe/nova'),
              ),
              const SizedBox(height: AppSpacing.lg),
              _OnboardingCard(
                icon: Icons.link_rounded,
                title: 'Recebi um convite',
                message: 'Cole o código que o líder da equipe enviou.',
                actionLabel: 'Entrar com código',
                filled: false,
                onAction: () => context.push('/convite'),
              ),
            ],
          ),
        ),
      ),
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
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final bool filled;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: filled
                  ? scheme.primaryContainer
                  : AppColors.accentContainer(scheme),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Icon(
              icon,
              color: filled
                  ? scheme.onPrimaryContainer
                  : AppColors.onAccentContainer(scheme),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (filled)
            FilledButton(onPressed: onAction, child: Text(actionLabel))
          else
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
        ],
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
              height: MediaQuery.sizeOf(context).height * 0.5,
              child: AppEmptyState(
                icon: Icons.event_available_outlined,
                title: 'Nenhuma escala por aqui',
                message: canManage
                    ? 'Toque em "Nova escala" para criar a primeira da equipe.'
                    : 'Quando o líder criar uma escala, ela aparece aqui.',
              ),
            ),
          ],
        ),
      );
    }

    final featured = showFeaturedEvent ? events.first : null;
    final remaining =
        (showFeaturedEvent ? events.skip(1) : events).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xxxl * 2,
        ),
        children: [
          if (fromCache && cachedAt != null) ...[
            CacheStampBanner(cachedAt: cachedAt!),
            const SizedBox(height: AppSpacing.md),
          ],
          if (featured != null) ...[
            _FeaturedEventCard(
              event: featured,
              canManage: canManage,
              membershipId: membershipId,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          if (remaining.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xs,
                bottom: AppSpacing.md,
              ),
              child: Text(
                showFeaturedEvent ? 'Depois dessa' : 'Escalas passadas',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            ...remaining.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _EventTile(
                  event: event,
                  canManage: canManage,
                  membershipId: membershipId,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Cartão do próximo culto. É a primeira coisa que a pessoa vê ao abrir o app,
/// então concentra tudo que ela precisa saber sem abrir nada: quando, onde ela
/// entra, e se a escala já está montada.
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final timezone =
        event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone;
    final youPositions = event.positionsForMembership(membershipId);
    final gradient = AppColors.heroGradient(scheme);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusHero),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.32),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/agenda/${event.id}'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DateBadge(
                      date: event.startsAt,
                      timezone: timezone,
                      size: DateBadgeSize.large,
                      background: Colors.white.withValues(alpha: 0.16),
                      foreground: Colors.white,
                      muted: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRÓXIMA ESCALA',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            event.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canManage && FeatureFlags.duplicateSchedule)
                      _HeroMenu(event: event),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                // Wrap e não Row: com dois cultos mais o ensaio são três
                // pílulas, e numa Row a terceira estouraria a largura.
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final service in event.displayServices)
                      _HeroTimePill(
                        icon: Icons.church_rounded,
                        label: service.label,
                        value: formatEventTime(service.startsAt, timezone),
                      ),
                    if (event.rehearsalAt != null)
                      _HeroTimePill(
                        icon: Icons.music_note_rounded,
                        label: 'Ensaio',
                        value: formatEventTime(event.rehearsalAt!, timezone),
                      )
                    else
                      // Ausência de ensaio é informação, não vazio: sem a tag
                      // fica a dúvida se ninguém marcou ou se não vai ter.
                      const _HeroTimePill(
                        icon: Icons.music_off_rounded,
                        label: 'Sem ensaio',
                        value: '',
                      ),
                  ],
                ),
                if (youPositions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  YouHighlight(
                    positionNames: youPositions,
                    onDarkSurface: true,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                const SizedBox(height: AppSpacing.md),
                // Wrap, e nao Row: com paleta longa os dois itens brigavam pela
                // mesma linha e o texto quebrava no meio.
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _HeroFooterItem(
                      icon: event.scheduledMemberCount == 0
                          ? Icons.person_off_outlined
                          : Icons.groups_rounded,
                      label: _scheduleLabel(event.scheduledMemberCount),
                    ),
                    if (event.colorPalette?.isNotEmpty ?? false)
                      _HeroFooterItem(
                        icon: Icons.palette_outlined,
                        label: event.colorPalette!,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _scheduleLabel(int count) {
  if (count == 0) return 'Ninguém escalado ainda';
  if (count == 1) return '1 pessoa escalada';
  return '$count pessoas escaladas';
}

class _HeroFooterItem extends StatelessWidget {
  const _HeroFooterItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final white = Colors.white.withValues(alpha: 0.9);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: white),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: white),
        ),
      ],
    );
  }
}

class _HeroMenu extends ConsumerWidget {
  const _HeroMenu({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        color: Colors.white.withValues(alpha: 0.9),
      ),
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
        PopupMenuItem(value: 'duplicate', child: Text('Duplicar escala')),
      ],
    );
  }
}

class _HeroTimePill extends StatelessWidget {
  const _HeroTimePill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          if (value.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final timezone =
        event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone;
    final youPositions = event.positionsForMembership(membershipId);

    return AppCard(
      onTap: () => context.push('/agenda/${event.id}'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateBadge(date: event.startsAt, timezone: timezone),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        // "Manhã 08:30 · Noite 19:00 · Ensaio 13:00". Com um
                        // culto só a linha fica igual à de antes.
                        [
                          for (final service in event.displayServices)
                            '${service.label} '
                                '${formatEventTime(service.startsAt, timezone)}',
                          if (event.rehearsalAt == null)
                            'Sem ensaio'
                          else
                            'Ensaio '
                                '${formatEventTime(event.rehearsalAt!, timezone)}',
                        ].join('  ·  '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                if (youPositions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  YouHighlight(positionNames: youPositions, compact: true),
                ],
              ],
            ),
          ),
          // O menu do item só existe por causa de "Duplicar escala"; com a
          // funcionalidade escondida, o card volta a ser só um atalho.
          if (canManage && FeatureFlags.duplicateSchedule)
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
                  child: Text('Duplicar escala'),
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm, right: 4),
              child: Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
