import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/push/push_service.dart';
import '../../../core/responsive/app_breakpoints.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_group.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/cache_stamp_banner.dart';
import '../../../shared/widgets/greeting_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../events/data/event_repository.dart';
import '../../events/domain/event_datetime.dart';
import '../../events/domain/event_models.dart';
import '../../events/presentation/agenda_event_tile.dart';
import '../../events/presentation/event_schedule_facts.dart';
import '../../suggestions/data/suggestion_repository.dart';
import '../../team/data/team_repository.dart';
import '../../team/presentation/team_onboarding.dart';
import '../../update/presentation/app_update_banner.dart';
import '../domain/home_summary.dart';
import 'home_next_card.dart';
import 'home_quick_access.dart';

/// A porta de entrada do app.
///
/// **Quatro perguntas, nesta ordem:** quando eu toco, o que preciso fazer
/// agora, o que vem depois, e por onde chego ao que uso toda semana. A agenda
/// responde a terceira muito bem e sempre respondeu a primeira pela metade — o
/// destaque dela é a próxima escala **da equipe**, e quem abre o app quer saber
/// da própria. É essa diferença que dá razão à Home; o resto ela pega
/// emprestado.
///
/// **Nenhum dado novo, nenhum endpoint novo.** A tela observa exatamente o
/// mesmo `eventsProvider((teamId, 'upcoming'))` da agenda — mesma chave, mesma
/// resposta em cache, zero requisição a mais — e a contagem de sugestões vem do
/// provider que já alimenta o selo da aba Equipe. Toda a leitura dessa lista
/// mora em [HomeSummary], fora do widget.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _askedForNotifications = false;

  /// Pede a permissão de notificação **depois de a tela ter conteúdo**.
  ///
  /// Era da agenda, e mudou de lugar junto com a porta de entrada: quem abre o
  /// app agora cai aqui, e um integrante que nunca toca na aba Agenda jamais
  /// veria a pergunta. O próprio sistema lembra a resposta, então a guarda
  /// abaixo só evita repetir a chamada a cada reconstrução.
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
      return const TeamOnboarding();
    }

    // A equipe **ativa**, não `teams.first`: quem lidera numa equipe e apenas
    // participa de outra não pode ver "Nova escala" enquanto a equipe ativa é
    // a segunda. Mesma regra da agenda.
    final team = auth.teams.where((t) => t.teamId == teamId).firstOrNull ??
        auth.teams.first;
    final events = ref.watch(eventsProvider((teamId, 'upcoming')));
    if (events.hasValue) _maybeAskForNotifications();

    // Largura da **janela**: o botão de criar escala muda de lugar (canto
    // inferior no celular, cabeçalho no monitor), e essa decisão é sobre o
    // formato da tela, não sobre o espaço que a lista recebeu.
    final wide = AppBreakpoints.of(context).isWide;

    return Scaffold(
      // O mesmo botão da agenda, no mesmo lugar: é a mesma ação, e vê-la mudar
      // de forma ao trocar de aba é o que faz duas telas parecerem de dois
      // apps. No monitor ele sobe para o cabeçalho, onde a ação principal
      // pertence quando existe mouse.
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
              GreetingHeader(
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
              Expanded(
                child: events.when(
                  // Esqueleto no formato do que vem — a manchete, os dois
                  // atalhos, as linhas —, e não a rodinha centralizada: a tela
                  // já mostra que é a Home enquanto carrega, e o conteúdo entra
                  // sem sacudir o layout.
                  loading: () => const _HomeSkeleton(),
                  error: (error, _) => AppErrorState(
                    message: error is ApiException
                        ? error.message
                        : 'Não foi possível carregar a sua próxima escala.',
                    onRetry: () => ref.invalidate(
                      eventsProvider((teamId, 'upcoming')),
                    ),
                  ),
                  data: (cached) => _HomeBody(
                    teamId: teamId,
                    canManage: team.canManage,
                    summary: HomeSummary.of(
                      cached.data,
                      membershipId: team.membershipId,
                      canManage: team.canManage,
                      now: DateTime.now(),
                    ),
                    membershipId: team.membershipId,
                    fromCache: cached.fromCache,
                    cachedAt: cached.cachedAt,
                    onRefresh: () {
                      // O selo das sugestões cai junto: puxar a Home para
                      // baixo é o gesto de "traga o que mudou", e trazer só
                      // metade seria pior do que não trazer nada.
                      if (team.canManage) {
                        ref.invalidate(openSuggestionCountProvider(teamId));
                      }
                      return ref.refresh(
                        eventsProvider((teamId, 'upcoming')).future,
                      );
                    },
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

/// O corpo da Home, na hierarquia que a tela promete.
///
/// Manchete, atalhos, próximas escalas, avisos — nesta ordem, e sempre nesta.
/// Um bloco pode não existir (não há avisos, a equipe não tem outras escalas),
/// mas nenhum troca de lugar com outro: a Home é consultada de relance, e uma
/// tela cujo conteúdo muda de posição obriga a lê-la inteira toda vez.
class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.teamId,
    required this.canManage,
    required this.summary,
    required this.membershipId,
    required this.fromCache,
    required this.cachedAt,
    required this.onRefresh,
  });

  final String teamId;
  final bool canManage;
  final HomeSummary summary;
  final String membershipId;
  final bool fromCache;
  final DateTime? cachedAt;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final myNext = summary.myNext;

    final hero = myNext == null
        ? NoScheduleCard(
            hasSchedules: summary.hasSchedules,
            canManage: canManage,
          )
        : MyNextScheduleCard(event: myNext, positions: summary.myPositions);

    return Column(
      children: [
        if (fromCache && cachedAt != null) CacheStampBanner(cachedAt: cachedAt!),
        Expanded(
          // A largura de que o **corpo** dispõe, e não a da janela: dentro da
          // casca com barra lateral aberta sobram ~900px de 1200, e é esse o
          // número que decide se a manchete e os atalhos cabem lado a lado.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 880;
              final quickAccess = HomeQuickAccess(
                teamId: teamId,
                canManage: canManage,
              );

              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    // Espaço para o botão flutuante não cobrir o último item.
                    // Sem ele (monitor), o rodapé volta ao normal.
                    twoColumns ? AppSpacing.xxl : AppSpacing.xxxl * 2,
                  ),
                  children: [
                    if (twoColumns)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: hero),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(flex: 2, child: quickAccess),
                        ],
                      )
                    else ...[
                      hero,
                      const SizedBox(height: AppSpacing.xl),
                      quickAccess,
                    ],
                    if (summary.upcoming.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _UpcomingSchedules(
                        events: summary.upcoming,
                        membershipId: membershipId,
                      ),
                    ],
                    if (summary.notices.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _HomeNotices(notices: summary.notices),
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

/// As próximas da equipe, em linha.
///
/// **É a linha da agenda, sem uma vírgula de diferença** ([CompactScheduleTile]):
/// mesmo bloco de data, mesmo título, mesmo destaque de "você" — porque é a
/// mesma coisa, e desenhá-la de novo aqui garantiria que as duas listas
/// divergissem no primeiro ajuste. O que muda é o recorte: três escalas, e sem
/// o menu de "duplicar" — administrar a escala é trabalho da agenda.
///
/// A escala da manchete não entra aqui (ver [HomeSummary.upcoming]): a mesma
/// data em dois blocos da mesma tela faz a pessoa achar que tem escala em
/// dobro.
class _UpcomingSchedules extends StatelessWidget {
  const _UpcomingSchedules({required this.events, required this.membershipId});

  final List<Event> events;
  final String membershipId;

  @override
  Widget build(BuildContext context) {
    return AppGroup(
      title: 'Próximas escalas',
      dividerIndent: AppGroup.textIndent,
      children: [
        for (final event in events)
          CompactScheduleTile(
            event: event,
            canManage: false,
            membershipId: membershipId,
          ),
        AppGroupRow(
          title: 'Ver agenda',
          // `go`, e não `push`: a agenda é uma aba. Empilhá-la sobre a Home
          // deixaria a barra inferior acesa na Home com a agenda na tela.
          onTap: () => context.go('/agenda'),
        ),
      ],
    );
  }
}

/// O pé da Home: até dois avisos, e só quando há o que avisar.
///
/// **Nada aqui é dado novo** — tudo sai da lista de escalas que a tela já
/// mostrou acima (ver [HomeSummary]). Sem aviso nenhum o bloco simplesmente não
/// existe: uma seção vazia com um "tudo em dia" seria um cartão gasto para não
/// dizer nada.
class _HomeNotices extends StatelessWidget {
  const _HomeNotices({required this.notices});

  final List<HomeNotice> notices;

  @override
  Widget build(BuildContext context) {
    return AppGroup(
      title: 'Fique de olho',
      children: [
        for (final notice in notices)
          _noticeRow(context, notice),
      ],
    );
  }

  Widget _noticeRow(BuildContext context, HomeNotice notice) {
    final copy = _copyFor(notice);

    return AppGroupRow(
      icon: copy.icon,
      title: copy.title,
      subtitle: copy.message,
      onTap: () => notice.opensTab
          ? context.go(notice.route)
          : context.push(notice.route),
    );
  }

  /// A frase de cada aviso.
  ///
  /// Mora aqui, e não no domínio: os horários saem de [ScheduleFacts], que é
  /// quem já sabe escrever "Manhã 08:30 · Noite 19:00" — e escrever isso de
  /// novo em outro lugar é como as três versões daquela frase apareceram da
  /// primeira vez.
  ({IconData icon, String title, String message}) _copyFor(HomeNotice notice) {
    final event = notice.event;
    final timezone = event == null || event.timezone.isEmpty
        ? 'America/Sao_Paulo'
        : event.timezone;

    return switch (notice.kind) {
      HomeNoticeKind.scheduleToday => (
          icon: Icons.today_rounded,
          title: 'Sua escala é hoje',
          message: ScheduleFacts.of(event!, timezone).times,
        ),
      HomeNoticeKind.scheduleTomorrow => (
          icon: Icons.event_rounded,
          title: 'Sua escala é amanhã',
          message: ScheduleFacts.of(event!, timezone).times,
        ),
      HomeNoticeKind.pendingDrafts => (
          icon: Icons.edit_note_rounded,
          title: notice.count == 1
              ? '1 escala em rascunho'
              : '${notice.count} escalas em rascunho',
          message: 'A equipe só vê a escala depois de publicada.',
        ),
      HomeNoticeKind.unstaffedSchedule => (
          icon: Icons.person_add_alt_1_rounded,
          title: 'Ninguém escalado ainda',
          message: '${formatEventShortDate(event!.startsAt, timezone)} '
              'está sem equipe.',
        ),
    };
  }
}

/// A Home carregando, na forma que ela vai ter.
///
/// A manchete é um bloco alto; abaixo, os dois atalhos lado a lado e as linhas
/// das próximas escalas. Um esqueleto genérico prometeria outra tela — e a
/// promessa quebrada é o que faz o conteúdo "pular" quando chega.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

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
          Container(
            height: 230,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              for (var i = 0; i < 2; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: AppSkeleton(height: 108, radius: AppSpacing.radiusLg),
                ),
              ],
            ],
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
