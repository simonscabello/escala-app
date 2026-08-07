import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/cache_stamp_banner.dart';
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
                  : scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Icon(
              icon,
              color: filled
                  ? scheme.onPrimaryContainer
                  : scheme.onSecondaryContainer,
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
/// então concentra tudo que ela precisa saber sem abrir nada: quando e onde
/// ela entra.
///
/// Layout alinhado ao resumo do detalhe da escala: badge, título, horários e
/// chip "VOCÊ" — sem rótulo "próxima escala" nem ícone decorativo.
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

    return AppCard(
      onTap: () => context.push('/agenda/${event.id}'),
      borderRadius: AppSpacing.radiusLg,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sem selo de data: ele repetia, em três siglas, a mesma data que a
          // linha ao lado já escrevia por extenso.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRÓXIMA ESCALA',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatEventWeekdayDate(event.startsAt, timezone),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // A data é a identidade da escala e fica sempre na mesma
                    // posição; o título só existe em culto especial e entra
                    // abaixo, em azul, para se ler como exceção.
                    if (event.hasTitle)
                      Text(
                        event.title!,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (canManage && FeatureFlags.duplicateSchedule)
                _HeroMenu(event: event),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Fora da coluna à direita do selo: ali sobravam ~250px e cada
          // etiqueta pedia ~150, então as três caíam uma por linha. Na largura
          // do cartão elas cabem em uma ou duas.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 6,
            children: [
              for (final service in event.displayServices)
                _HeroTimePill(
                  icon: Icons.church_rounded,
                  label: '${service.label} '
                      '${formatEventTime(service.startsAt, timezone)}',
                  emphasized: true,
                ),
              if (event.rehearsalAt != null)
                _HeroTimePill(
                  icon: Icons.music_note_rounded,
                  label: isSameLocalDay(
                    event.rehearsalAt!,
                    event.startsAt,
                    timezone,
                  )
                      ? 'Ensaio ${formatEventTime(event.rehearsalAt!, timezone)}'
                      : 'Ensaio ${formatEventWeekdayDate(event.rehearsalAt!, timezone)} '
                          '${formatEventTime(event.rehearsalAt!, timezone)}',
                )
              else
                // Ausência de ensaio é informação, não vazio.
                const _HeroTimePill(
                  icon: Icons.music_off_rounded,
                  label: 'Sem ensaio',
                ),
            ],
          ),
          if (youPositions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: YouHighlight(positionNames: youPositions),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroMenu extends ConsumerWidget {
  const _HeroMenu({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
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
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground =
        emphasized ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.primaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A data por extenso abre o item: é o que identifica a escala,
                // e fica na mesma posição em todos, o que deixa a lista legível
                // de cima a baixo.
                Text(
                  formatEventWeekdayDate(event.startsAt, timezone),
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (event.hasTitle)
                  Text(
                    event.title!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
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
                  YouHighlight(positionNames: youPositions),
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
