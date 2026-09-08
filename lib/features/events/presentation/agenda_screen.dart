import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/push/push_service.dart';
import '../../../core/responsive/app_breakpoints.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_choice_bar.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_group.dart';
import '../../../shared/widgets/app_pressable.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/cache_stamp_banner.dart';
import '../../auth/application/auth_controller.dart';
import '../../team/data/team_repository.dart';
import '../../team/domain/service_template.dart';
import '../../update/presentation/app_update_banner.dart';
import '../data/event_repository.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';
import '../domain/open_date.dart';
import 'agenda_event_tile.dart';
import 'agenda_hero_card.dart';

/// Saudação por horário. Detalhe pequeno, mas é o que separa uma tela de
/// listagem de um app que parece ter sido feito para aquela pessoa.
String greetingForHour(int hour) {
  if (hour < 12) return 'Bom dia';
  if (hour < 18) return 'Boa tarde';
  return 'Boa noite';
}

/// O fuso da equipe, pelas fontes na ordem em que valem.
///
/// O cadastro da equipe é a resposta certa, mas ele chega numa requisição
/// própria e pode ainda não ter voltado. Enquanto isso as escalas já carregam o
/// fuso junto, e usá-lo evita que as datas em aberto apareçam um dia deslocadas
/// no primeiro quadro. O padrão do app só entra numa equipe sem escala nenhuma.
String _agendaTimezone(String? teamTimezone, List<Event> events) {
  if (teamTimezone != null && teamTimezone.isNotEmpty) return teamTimezone;
  for (final event in events) {
    if (event.timezone.isNotEmpty) return event.timezone;
  }
  return 'America/Sao_Paulo';
}

/// O fuso de uma escala, com o mesmo padrão do resto da tela.
String _eventTimezone(Event event) =>
    event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone;

/// As escalas separadas por mês, na ordem em que já vieram.
///
/// **A chave é o ano-mês, e não o rótulo.** Agrupar pelo texto juntaria
/// "Setembro 2026" com "Setembro 2027" — improvável na aba das próximas, certo
/// na das passadas, que é justamente onde a lista atravessa anos.
List<({String key, String label, List<Event> events})> groupEventsByMonth(
  List<Event> events,
) {
  final ordem = <String>[];
  final porMes = <String, List<Event>>{};
  final rotulos = <String, String>{};

  for (final event in events) {
    final timezone = _eventTimezone(event);
    final key = eventMonthKey(event.startsAt, timezone);
    if (!porMes.containsKey(key)) {
      ordem.add(key);
      porMes[key] = <Event>[];
      rotulos[key] = formatEventMonthYear(event.startsAt, timezone);
    }
    porMes[key]!.add(event);
  }

  return [
    for (final key in ordem)
      (key: key, label: rotulos[key]!, events: porMes[key]!),
  ];
}

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  String _scope = 'upcoming';
  bool _askedForNotifications = false;

  /// Pede a permissao de notificacao **depois de a agenda ter conteudo**.
  ///
  /// Nao no primeiro boot: quem ainda nao viu uma escala nao tem como decidir
  /// se quer ser avisado sobre escalas, e um "nao" dado ali e caro -- o Android
  /// so volta a perguntar mais uma vez. Com a agenda na tela, a pergunta tem
  /// contexto.
  ///
  /// O proprio sistema lembra a resposta: chamar de novo em outra sessao nao
  /// mostra dialogo nenhum, entao a guarda aqui e so para nao repetir a
  /// chamada a cada reconstrucao.
  void _maybeAskForNotifications() {
    if (_askedForNotifications || !PushService.isSupported) return;
    _askedForNotifications = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(pushServiceProvider).requestPermission());
    });
  }

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
    if (events.hasValue) _maybeAskForNotifications();
    // A grade de cultos e o fuso da equipe só interessam a quem monta escala, e
    // só na aba das próximas — é ali que faz sentido mostrar as datas que ainda
    // não viraram escala. Para o resto, estes dois providers nem são
    // observados, e a agenda continua custando uma requisição.
    final planning = team.canManage && _scope == 'upcoming';
    final templates = planning
        ? ref.watch(serviceTemplatesProvider(teamId)).valueOrNull ??
            const <ServiceTemplate>[]
        : const <ServiceTemplate>[];
    final teamTimezone =
        planning ? ref.watch(teamProvider(teamId)).valueOrNull?.timezone : null;
    // Largura da **janela**: o botão de criar escala muda de lugar (canto
    // inferior no celular, cabeçalho no monitor), e essa decisão é sobre o
    // formato da tela, não sobre o espaço que a lista recebeu.
    final wide = AppBreakpoints.of(context).isWide;

    return Scaffold(
      // No monitor o botão flutuante some: ele existe porque no celular o canto
      // inferior direito é onde o polegar chega. Com mouse, a ação principal
      // pertence ao cabeçalho, junto do título da tela — e um círculo flutuando
      // sobre 1400px de conteúdo é o carimbo de "app de celular esticado".
      floatingActionButton: team.canManage && !wide
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/agenda/novo'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova escala'),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: AppContentWidth.wide(
          child: Column(
            children: [
              _GreetingHeader(
                name: auth.user?.firstName ?? '',
                teamName: team.name,
                activeTeamId: teamId,
                showTeamSwitcher: !wide,
                onCreate: team.canManage && wide
                    ? () => context.push('/agenda/novo')
                    : null,
                teams: [
                  for (final item in auth.teams)
                    (id: item.teamId, name: item.name),
                ],
                onTeamChanged: (id) =>
                    ref.read(activeTeamIdProvider.notifier).select(id),
              ),
              const AppUpdateBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    // No celular a barra ocupa a linha inteira. Num monitor,
                    // dois segmentos esticados por 1180px viram dois botões
                    // gigantes dizendo "Próximas" e "Passadas".
                    constraints: BoxConstraints(
                      maxWidth: wide ? 360 : double.infinity,
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
                ),
              ),
              Expanded(
                child: events.when(
                  // Esqueleto no formato do que vem — manchete e linhas —, em
                  // vez da rodinha centralizada: a tela já mostra que é uma
                  // agenda enquanto carrega, e o conteúdo entra sem sacudir o
                  // layout.
                  loading: () => const _AgendaSkeleton(),
                  error: (error, _) => AppErrorState(
                    message: error is ApiException
                        ? error.message
                        : 'Não foi possível carregar a agenda.',
                    onRetry: () =>
                        ref.invalidate(eventsProvider((teamId, _scope))),
                  ),
                  data: (cached) => _EventsList(
                    teamId: teamId,
                    events: cached.data,
                    openDates: planning
                        ? openDates(
                            templates: templates,
                            events: cached.data,
                            timezone: _agendaTimezone(
                              teamTimezone,
                              cached.data,
                            ),
                            now: DateTime.now(),
                          )
                        : const [],
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
///
/// **A saudação subiu de corpo e o cabeçalho ganhou folga.** Ele é a abertura
/// da tela principal do app, e estava com o mesmo tamanho de um título de
/// bloco; a diferença entre "esta é a sua agenda" e "esta é mais uma lista"
/// está quase toda aqui.
///
/// No monitor o cabeçalho recebe a ação principal à direita, e o seletor de
/// equipe sai daqui: ele passou para a barra lateral, onde vale para o app
/// inteiro em vez de só para esta tela.
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.name,
    required this.teamName,
    required this.activeTeamId,
    required this.teams,
    required this.onTeamChanged,
    required this.showTeamSwitcher,
    this.onCreate,
  });

  final String name;
  final String teamName;
  final String activeTeamId;
  final List<({String id, String name})> teams;
  final ValueChanged<String> onTeamChanged;
  final bool showTeamSwitcher;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final greeting = greetingForHour(DateTime.now().hour);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? greeting : '$greeting, $name',
                  style: theme.textTheme.headlineMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(Icons.groups_rounded, size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        teamName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (showTeamSwitcher && teams.length > 1)
                      PopupMenuButton<String>(
                        tooltip: 'Trocar equipe',
                        initialValue: activeTeamId,
                        onSelected: onTeamChanged,
                        icon: const Icon(Icons.unfold_more_rounded, size: 18),
                        itemBuilder: (context) => [
                          for (final team in teams)
                            PopupMenuItem(
                              value: team.id,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    child: team.id == activeTeamId
                                        ? Icon(
                                            Icons.check_rounded,
                                            size: 18,
                                            color: scheme.primary,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Flexible(child: Text(team.name)),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (onCreate != null) ...[
            const SizedBox(width: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nova escala'),
            ),
          ],
        ],
      ),
    );
  }
}

/// A agenda carregando, na forma que ela vai ter.
///
/// A manchete é um bloco alto; as escalas seguintes são linhas com o bloco de
/// data à esquerda, dentro de uma superfície só. Um esqueleto de quatro cartões
/// soltos prometia outra tela — e a promessa quebrada é o que faz o conteúdo
/// "pular" quando chega.
class _AgendaSkeleton extends StatelessWidget {
  const _AgendaSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ExcludeSemantics(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          // A manchete: um bloco, e não barras de texto. Ela é uma superfície
          // inteira de cor, e é isso que a pessoa vê chegar.
          Container(
            height: 210,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: AppGroup.textIndent,
                      color: scheme.outlineVariant,
                    ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        const AppSkeleton(
                          width: 54,
                          height: 52,
                          radius: AppSpacing.radiusSm,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Larguras diferentes por linha: barras idênticas
                              // leem-se como tabela travada, não como texto
                              // chegando.
                              AppSkeleton(
                                width: i.isEven ? 180 : 150,
                                height: 15,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              AppSkeleton(
                                width: i.isEven ? 210 : 240,
                                height: 11,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
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
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AppContentWidth.reading(
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
                  style: theme.textTheme.headlineMedium,
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
                // Lado a lado onde cabe: são duas escolhas do mesmo peso, e
                // empilhadas num monitor a segunda cai abaixo da dobra.
                _OnboardingChoices(
                  cards: [
                    _OnboardingCard(
                      icon: Icons.groups_rounded,
                      title: 'Sou o líder da equipe',
                      message: 'Crie a equipe e cadastre os integrantes. '
                          'Ninguém precisa ter conta ainda.',
                      actionLabel: 'Criar equipe',
                      filled: true,
                      onAction: () => context.push('/equipe/nova'),
                    ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empilhadas no celular, lado a lado onde couber.
class _OnboardingChoices extends StatelessWidget {
  const _OnboardingChoices({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.tablet) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.lg),
                cards[i],
              ],
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.lg),
                Expanded(child: cards[i]),
              ],
            ],
          ),
        );
      },
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

/// A lista da agenda, em três degraus.
///
/// **A próxima escala, a seguinte, e o resto por mês.** É a ordem em que a
/// pergunta aparece: "quando é a próxima?" tem uma resposta só e ela é a
/// manchete; "e depois dessa?" tem uma segunda resposta e merece o próprio
/// bloco, porque é o que a pessoa consulta para se organizar na semana; daí em
/// diante a pergunta muda de natureza — vira "como está o mês" —, e a resposta
/// é uma lista agrupada, não mais um destaque.
///
/// Nenhuma escala aparece duas vezes: a manchete sai da lista, a seguinte sai
/// do agrupamento por mês, e os meses recebem o que sobrou.
class _EventsList extends StatefulWidget {
  const _EventsList({
    required this.teamId,
    required this.events,
    required this.openDates,
    required this.showFeaturedEvent,
    required this.canManage,
    required this.membershipId,
    required this.fromCache,
    required this.cachedAt,
    required this.onRefresh,
  });

  final String teamId;
  final List<Event> events;

  /// As datas da grade ainda sem escala. Vazio para quem não gerencia — ver
  /// [_OpenDatesGroup].
  final List<OpenDate> openDates;

  final bool showFeaturedEvent;
  final bool canManage;
  final String membershipId;
  final bool fromCache;
  final DateTime? cachedAt;
  final Future<void> Function() onRefresh;

  @override
  State<_EventsList> createState() => _EventsListState();
}

class _EventsListState extends State<_EventsList> {
  /// Onde "Ver todas" leva. O primeiro cabeçalho de mês é o começo da lista
  /// completa; a âncora existe para o atalho ter destino real em vez de virar
  /// um rótulo decorativo.
  final _monthsAnchor = GlobalKey();

  void _showAll() {
    final context = _monthsAnchor.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  @override
  Widget build(BuildContext context) {
    final banner = widget.fromCache && widget.cachedAt != null
        ? CacheStampBanner(cachedAt: widget.cachedAt!)
        : null;

    if (widget.events.isEmpty) {
      return _EmptyAgenda(
        teamId: widget.teamId,
        openDates: widget.openDates,
        showFeaturedEvent: widget.showFeaturedEvent,
        canManage: widget.canManage,
        banner: banner,
        onRefresh: widget.onRefresh,
      );
    }

    final events = widget.events;
    final featured = widget.showFeaturedEvent ? events.first : null;
    // A "seguinte" só existe quando há manchete: na aba das passadas todas as
    // escalas são iguais entre si, e eleger a segunda não significaria nada.
    final afterNext =
        featured != null && events.length > 1 ? events.elementAt(1) : null;
    final rest = featured == null
        ? events
        : events.skip(afterNext == null ? 1 : 2).toList();
    final months = groupEventsByMonth(rest);

    return Column(
      children: [
        if (banner != null) banner,
        Expanded(
          // A largura de que a **lista** dispõe, e não a da janela: dentro da
          // casca com barra lateral aberta sobram ~900px de 1200, e é esse o
          // número que decide se cabem duas colunas.
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 880 e o ponto em que as colunas da linha (data, horarios,
              // "voce", menu) cabem sem espremer nenhuma. Abaixo disso a
              // linha volta a se empilhar -- inclusive num tablet de 600px com
              // a barra lateral recolhida, onde sobram ~500px de lista.
              final wide = constraints.maxWidth >= 880;
              final twoColumns = featured != null && wide;

              return RefreshIndicator(
                onRefresh: widget.onRefresh,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    // Espaço para o FAB não cobrir o último item. Sem botão
                    // flutuante (monitor), o rodapé volta ao normal.
                    wide ? AppSpacing.xxl : AppSpacing.xxxl * 2,
                  ),
                  children: [
                    if (featured != null) ...[
                      if (twoColumns)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: ScheduleHeroCard(
                                event: featured,
                                canManage: widget.canManage,
                                membershipId: widget.membershipId,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              flex: 2,
                              child: _AgendaSummary(
                                events: events,
                                membershipId: widget.membershipId,
                                canManage: widget.canManage,
                              ),
                            ),
                          ],
                        )
                      else
                        ScheduleHeroCard(
                          event: featured,
                          canManage: widget.canManage,
                          membershipId: widget.membershipId,
                        ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    if (afterNext != null) ...[
                      AppGroup(
                        title: 'Depois dessa',
                        dividerIndent: AppGroup.textIndent,
                        // O atalho só existe quando há de fato mais lista
                        // abaixo. Com duas escalas na agenda, "Ver todas"
                        // apontaria para o nada.
                        trailing: months.isEmpty
                            ? null
                            : TextButton.icon(
                                onPressed: _showAll,
                                iconAlignment: IconAlignment.end,
                                icon: const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                ),
                                label: const Text('Ver todas'),
                              ),
                        children: [
                          CompactScheduleTile(
                            event: afterNext,
                            canManage: widget.canManage,
                            membershipId: widget.membershipId,
                            wide: wide,
                          ),
                        ],
                      ),
                      if (months.isNotEmpty || widget.openDates.isNotEmpty)
                        const SizedBox(height: AppSpacing.xl),
                    ],
                    for (var i = 0; i < months.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.xl),
                      KeyedSubtree(
                        // O primeiro mês é o destino de "Ver todas"; os
                        // demais só precisam de identidade estável para o
                        // Flutter não reaproveitar o estado do mês anterior
                        // quando a lista muda.
                        key: i == 0
                            ? _monthsAnchor
                            : ValueKey('mes-${months[i].key}'),
                        child: AppGroup(
                          title: months[i].label,
                          dividerIndent: AppGroup.textIndent,
                          // A contagem no lugar em que a referência põe um
                          // ícone de calendário: mesmo peso visual, e diz
                          // alguma coisa.
                          trailing: _MonthCount(count: months[i].events.length),
                          children: [
                            for (final event in months[i].events)
                              CompactScheduleTile(
                                event: event,
                                canManage: widget.canManage,
                                membershipId: widget.membershipId,
                                wide: wide,
                              ),
                          ],
                        ),
                      ),
                    ],
                    // Por último, e não intercalado com as escalas: o que já
                    // está marcado vem primeiro porque é o que a equipe vai
                    // cumprir. O que falta marcar é trabalho da liderança, e
                    // trabalho pendente lido como lista fecha a tela melhor do
                    // que espalhado no meio do que já está pronto.
                    if (widget.openDates.isNotEmpty) ...[
                      if (months.isNotEmpty) const SizedBox(height: AppSpacing.xl),
                      _OpenDatesGroup(
                        teamId: widget.teamId,
                        dates: widget.openDates,
                        wide: wide,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Quantas escalas o mês tem, ao lado do nome dele.
class _MonthCount extends StatelessWidget {
  const _MonthCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        count == 1 ? '1 escala' : '$count escalas',
        style: theme.textTheme.labelSmall?.copyWith(
          fontFeatures: AppTypography.tabular,
        ),
      ),
    );
  }
}

/// Agenda sem nenhuma escala.
///
/// Com datas em aberto ela **não** está vazia: a grade já sabe quais são os
/// próximos domingos, e dizer "nenhuma escala marcada" ali seria esconder
/// justamente a lista que resolve a tela.
class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda({
    required this.teamId,
    required this.openDates,
    required this.showFeaturedEvent,
    required this.canManage,
    required this.banner,
    required this.onRefresh,
  });

  final String teamId;
  final List<OpenDate> openDates;
  final bool showFeaturedEvent;
  final bool canManage;
  final Widget? banner;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (openDates.isNotEmpty) {
      return Column(
        children: [
          if (banner != null) banner!,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xxxl * 2,
                  ),
                  children: [
                    _OpenDatesGroup(
                      teamId: teamId,
                      dates: openDates,
                      // O mesmo ponto de virada da lista de escalas: as duas
                      // arrumações precisam concordar, senão a agenda muda de
                      // formato no meio ao ganhar a primeira escala.
                      wide: constraints.maxWidth >= 880,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (banner != null) banner!,
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
}

/// As datas que a grade prevê e que ainda não têm escala.
///
/// A grade da igreja já diz quais são os próximos domingos e quintas, mas até
/// aqui isso só existia dentro do formulário de nova escala: a agenda mostrava
/// o que já tinha sido criado e ficava calada sobre o que faltava. O líder
/// precisava contar os domingos de cabeça para perceber que o mês estava vazio.
///
/// **Nada disto existe no banco.** São datas calculadas na hora (ver
/// [openDates]), e é justamente por isso que elas podem aparecer: mostrar o mês
/// inteiro não custa criar dezenas de escalas vazias que depois alguém teria de
/// apagar uma a uma. Tocar numa cria só aquela; a linha do fim cria todas.
///
/// Só para quem gerencia. Para a equipe, uma data sem escala não é informação —
/// é ruído no meio do que ela abriu o app para ver.
class _OpenDatesGroup extends ConsumerStatefulWidget {
  const _OpenDatesGroup({
    required this.teamId,
    required this.dates,
    required this.wide,
  });

  final String teamId;
  final List<OpenDate> dates;
  final bool wide;

  @override
  ConsumerState<_OpenDatesGroup> createState() => _OpenDatesGroupState();
}

class _OpenDatesGroupState extends ConsumerState<_OpenDatesGroup> {
  bool _saving = false;

  Future<void> _createAll() async {
    final count = widget.dates.length;
    final confirmed = await showConfirmDialog(
      context,
      title: count == 1 ? 'Criar 1 rascunho?' : 'Criar $count rascunhos?',
      message: 'Cada data vira uma escala em rascunho, com os cultos da grade '
          'já marcados. A equipe só vê depois que você publicar.',
      confirmLabel: 'Criar',
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      final result = await ref
          .read(eventRepositoryProvider)
          .generate(widget.teamId, weeks: openDatesWeeks);
      if (!mounted) return;

      // A lista de datas em aberto sai da lista de escalas: invalidar uma
      // recalcula a outra, e as linhas somem sozinhas.
      ref.invalidate(eventsProvider((widget.teamId, 'upcoming')));
      showAppSnackBar(
        context,
        result.createdCount == 0
            ? 'Estas datas já tinham escala.'
            : '${result.createdCount} '
                '${result.createdCount == 1 ? 'rascunho criado' : 'rascunhos criados'}.',
        tone: AppTone.success,
      );
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, tone: AppTone.danger);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppGroup(
      title: 'Datas sem escala',
      subtitle: 'Da grade de cultos da igreja, nas próximas '
          '$openDatesWeeks semanas.',
      dividerIndent: AppGroup.textIndent,
      children: [
        for (final date in widget.dates)
          OpenDateTile(date: date, wide: widget.wide),
        _CreateDraftsRow(
          count: widget.dates.length,
          saving: _saving,
          onTap: _createAll,
        ),
      ],
    );
  }
}

/// A última linha do grupo: cria de uma vez as datas listadas acima.
///
/// Fica **depois** da lista, e não no cabeçalho, porque ela é o resumo do que
/// está ali — o líder lê as datas, decide que é isso mesmo e confirma no fim. É
/// também a posição em que o polegar chega sem cobrir a lista que ele acabou de
/// conferir.
class _CreateDraftsRow extends StatelessWidget {
  const _CreateDraftsRow({
    required this.count,
    required this.saving,
    required this.onTap,
  });

  final int count;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppPressable(
      onTap: saving ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: saving
                  ? CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    )
                  : Icon(
                      Icons.event_repeat_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                count == 1
                    ? 'Criar o rascunho desta data'
                    : 'Criar os rascunhos destas $count datas',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
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

/// O painel ao lado da manchete, só onde há largura sobrando.
///
/// **Não traz informação nova.** Tudo aqui sai da mesma lista de escalas que a
/// tela já carregou: em quantas delas você entra, e quantas ainda são rascunho.
/// No celular esses números não cabem sem empurrar a manchete para fora da
/// tela; num monitor eles ocupam espaço que estava vazio, e respondem de
/// relance a única pergunta que o líder faz ao abrir a agenda — "o que falta?".
class _AgendaSummary extends StatelessWidget {
  const _AgendaSummary({
    required this.events,
    required this.membershipId,
    required this.canManage,
  });

  final List<Event> events;
  final String membershipId;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warning = AppStatusColors.of(context).warning;

    final yours = events
        .where((e) => e.positionsForMembership(membershipId).isNotEmpty)
        .toList();
    final drafts = events.where((e) => e.isDraft).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryTile(
          icon: Icons.person_pin_circle_outlined,
          value: '${yours.length}',
          label: yours.length == 1 ? 'escala com você' : 'escalas com você',
          detail: yours.isEmpty
              ? 'Você não está escalado nas próximas.'
              : yours
                  .take(2)
                  .map(
                    (e) => '${formatEventShortDate(
                      e.startsAt,
                      _eventTimezone(e),
                    )} · '
                        '${e.positionsForMembership(membershipId).join(', ')}',
                  )
                  .join('\n'),
          color: scheme.primary,
        ),
        if (canManage) ...[
          const SizedBox(height: AppSpacing.md),
          _SummaryTile(
            icon: Icons.edit_note_rounded,
            value: '${drafts.length}',
            label: drafts.length == 1 ? 'rascunho' : 'rascunhos',
            detail: drafts.isEmpty
                ? 'Nenhuma escala esperando publicação.'
                : 'A equipe só vê a escala depois de publicada.',
            color: drafts.isEmpty ? scheme.onSurfaceVariant : warning.foreground,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _SummaryTile(
          icon: Icons.event_note_outlined,
          value: '${events.length}',
          label: events.length == 1 ? 'escala à frente' : 'escalas à frente',
          detail: 'Contando a próxima.',
          color: scheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
