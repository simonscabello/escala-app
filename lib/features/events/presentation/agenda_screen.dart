import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_choice_bar.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_group.dart';
import '../../../shared/widgets/app_pressable.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/cache_stamp_banner.dart';
import '../../../shared/widgets/you_highlight.dart';
import '../../auth/application/auth_controller.dart';
import '../../team/data/team_repository.dart';
import '../data/event_repository.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';
import 'duplicate_event_dialog.dart';
import 'event_times.dart';

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

    // A equipe ATIVA, não `teams.first`. As duas coincidem em quem só tem uma
    // equipe -- que é quase todo mundo -- e divergem exatamente em quem toca em
    // duas: ali `first` decidia se o botão "Nova escala" aparecia usando o
    // papel na equipe errada. Um líder ficava sem o botão, um membro ganhava um
    // botão que o servidor recusaria.
    final team = auth.teams.where((t) => t.teamId == teamId).firstOrNull ??
        auth.teams.first;
    final events = ref.watch(eventsProvider((teamId, _scope)));

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
        child: AppContentWidth(
          child: Column(
            children: [
              _GreetingHeader(
                name: auth.user?.firstName ?? '',
                teamName: team.name,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: AppChoiceBar<String>(
                  value: _scope,
                  onChanged: (value) => setState(() => _scope = value),
                  options: const [
                    AppChoice(value: 'upcoming', label: 'Próximas'),
                    AppChoice(value: 'past', label: 'Passadas'),
                  ],
                ),
              ),
              Expanded(
                child: events.when(
                  // Esqueleto no formato dos cartões que vêm, em vez da rodinha
                  // centralizada: a tela já mostra que é uma lista de escalas
                  // enquanto carrega, e o conteúdo entra sem sacudir o layout.
                  loading: () => const AppListSkeleton(itemCount: 4),
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
      ),
    );
  }
}

/// Quem está usando e de que equipe.
///
/// Duas linhas, e não três: "Bom dia," e "Samuel" ocupavam uma linha cada por
/// pura estética, empurrando para baixo a única coisa que a pessoa abriu o app
/// para ver. O cumprimento continua ali, no lugar que ele merece — o de uma
/// linha só.
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.name, required this.teamName});

  final String name;
  final String teamName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final greeting = greetingForHour(DateTime.now().hour);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.isEmpty ? greeting : '$greeting, $name',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.groups_rounded, size: 14, color: scheme.primary),
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
        child: AppContentWidth(
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
                  'Você ainda não faz parte de uma equipe. Escolha por onde '
                  'começar.',
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
              color:
                  filled ? scheme.primaryContainer : scheme.secondaryContainer,
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
    final banner = fromCache && cachedAt != null
        ? CacheStampBanner(cachedAt: cachedAt!)
        : null;

    if (events.isEmpty) {
      return Column(
        children: [
          if (banner != null) banner,
          Expanded(
            child: RefreshableMessage(
              onRefresh: onRefresh,
              child: AppEmptyState(
                icon: Icons.event_available_outlined,
                title: showFeaturedEvent
                    ? 'Nenhuma escala marcada'
                    : 'Nenhuma escala passada',
                message: showFeaturedEvent
                    ? (canManage
                        ? 'Toque em "Nova escala" para criar a primeira da '
                            'equipe.'
                        : 'Quando o líder criar uma escala, ela aparece aqui.')
                    : 'As escalas que já aconteceram ficam guardadas aqui.',
              ),
            ),
          ),
        ],
      );
    }

    final featured = showFeaturedEvent ? events.first : null;
    final remaining = (showFeaturedEvent ? events.skip(1) : events).toList();

    return Column(
      children: [
        if (banner != null) banner,
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                // Espaço para o FAB não cobrir o último item.
                AppSpacing.xxxl * 2,
              ),
              children: [
                if (featured != null) ...[
                  _FeaturedEvent(
                    event: featured,
                    canManage: canManage,
                    membershipId: membershipId,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (remaining.isNotEmpty) ...[
                    // Um fio separa a manchete da lista. É a única divisória da
                    // tela, e por isso não precisa de mais nada em volta.
                    Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ],
                if (remaining.isNotEmpty)
                  AppGroup(
                    title: showFeaturedEvent ? 'Depois dessa' : 'Passadas',
                    dividerIndent: AppGroup.textIndent,
                    children: [
                      for (final event in remaining)
                        _EventRow(
                          event: event,
                          canManage: canManage,
                          membershipId: membershipId,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A próxima escala: a manchete da tela, **dentro de uma superfície**.
///
/// Esta é a razão de o app existir — quem abre quer saber quando é e onde entra
/// em dois segundos —, e por isso ela leva a tipografia de manchete: data em
/// 32px com espacejamento apertado, muito acima do corpo das escalas seguintes.
///
/// Já esteve **sem** cartão, solta na página, para levar a hierarquia ao limite:
/// uma coisa grande, uma lista quieta. Em aparelho real não funcionou. Sem
/// fundo, o bloco parava de se ler como um objeto e virava texto derramado
/// entre o cumprimento acima e a lista abaixo — e, pior, um objeto tocável sem
/// nada delimitando onde ele começa e termina.
///
/// O cartão voltou, com folga interna maior que a das linhas seguintes. A lição
/// vale para o resto do app: **a hierarquia se faz pelo tamanho do texto e pela
/// folga, não pela ausência de moldura.** Tirar a moldura não promove o
/// conteúdo; só tira o chão dele.
class _FeaturedEvent extends ConsumerWidget {
  const _FeaturedEvent({
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
      // Folga de manchete: `xl` contra os `md` das linhas do grupo abaixo. É
      // parte do que a distingue, junto com o corpo da data.
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PRÓXIMA ESCALA', style: AppTypography.eyebrow(context)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  formatEventWeekdayDate(event.startsAt, timezone),
                  style: theme.textTheme.displaySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (canManage && FeatureFlags.duplicateSchedule)
                _HeroMenu(event: event)
              else
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
            ],
          ),
          // A data é a identidade da escala e fica sempre na mesma posição; o
          // título só existe em culto especial e entra abaixo, em azul, para
          // se ler como exceção.
          if (event.hasTitle)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                event.title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          // A mesma frase do detalhe: abrir a escala não deve reapresentar a
          // mesma informação num formato diferente.
          EventTimesList(event: event, timezone: timezone),
          if (youPositions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
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
      tooltip: 'Mais opções desta escala',
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

/// Uma escala seguinte, como linha do grupo.
///
/// Perdeu a moldura própria e o ícone de relógio: dentro de um grupo, a
/// separação já vem do fio, e o relógio era decoração diante de uma linha que
/// começa literalmente com um horário.
class _EventRow extends ConsumerWidget {
  const _EventRow({
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

    return AppPressable(
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
                  // A data por extenso abre o item: é o que identifica a
                  // escala, e fica na mesma posição em todos, o que deixa a
                  // lista legível de cima a baixo.
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
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 3),
                  Text(
                    // "Manhã 08:30 · Noite 19:00 · Ensaio sáb 19:00".
                    // No item da lista os horários seguem em linha: aqui a
                    // pergunta é "qual escala é esta?", e a coluna alinhada da
                    // manchete gastaria três linhas por item.
                    [
                      for (final service in event.displayServices)
                        '${service.label} '
                            '${formatEventTime(service.startsAt, timezone)}',
                      if (event.rehearsalAt == null)
                        'Sem ensaio'
                      else
                        // Com o dia abreviado quando o ensaio é em outro dia:
                        // antes esta linha mostrava só a hora, e um ensaio de
                        // sábado parecia ser no dia do culto.
                        'Ensaio ${formatRehearsalTime(
                          event.rehearsalAt!,
                          event.startsAt,
                          timezone,
                        )}',
                    ].join('  ·  '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                  if (youPositions.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    YouHighlight(positionNames: youPositions),
                  ],
                ],
              ),
            ),
            // O menu do item só existe por causa de "Duplicar escala"; com a
            // funcionalidade escondida, a linha volta a ser só um atalho.
            if (canManage && FeatureFlags.duplicateSchedule)
              PopupMenuButton<String>(
                tooltip: 'Mais opções desta escala',
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
                  size: 20,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
