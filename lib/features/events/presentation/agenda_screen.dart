import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/date/civil_date.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/responsive/adaptive_dialog.dart';
import '../../../core/responsive/app_breakpoints.dart';
import '../../../core/storage/read_cache.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_choice_bar.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_group.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/cache_stamp_banner.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../team/data/team_repository.dart';
import '../../team/presentation/team_onboarding.dart';
import '../../team_events/data/team_event_repository.dart';
import '../../team_events/domain/team_event.dart';
import '../../team_events/presentation/team_event_tile.dart';
import '../../update/presentation/app_update_banner.dart';
import '../data/agenda_provider.dart';
import '../data/event_repository.dart';
import '../domain/agenda_entry.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';
import '../domain/open_date.dart';
import 'agenda_calendar.dart';
import 'agenda_event_tile.dart';
import 'agenda_open_dates.dart';

final agendaNowProvider = Provider<DateTime>((ref) => DateTime.now());

/// O mês da equipe, com a lista do dia embaixo.
///
/// **A linha é a mesma da Home** ([CompactScheduleTile]): mesmo bloco de data,
/// mesmos horários, mesma pílula "VOCÊ", mesmas linhas de estado. A agenda
/// chegou a ter um cartão próprio por horário, e o efeito foi o de sempre —
/// duas telas do mesmo app parecendo de apps diferentes, e duas listas de
/// escala divergindo no primeiro ajuste. O que a agenda tem de seu é o
/// **calendário**; a escala, quando aparece escrita, se escreve de um jeito só.
///
/// **Dois recortes, a mesma tela** ([AgendaFilter]): a agenda da equipe e a
/// agenda de quem está olhando. O segundo governa também os pontos do
/// calendário — "em que domingos eu toco?" é uma pergunta que se responde no
/// mês, não numa lista.
///
/// **Escalas e eventos convivem na mesma lista.** O evento da equipe (reunião,
/// churrasco) não é escala e tem entidade própria, mas para quem consulta o
/// mês é a mesma pergunta: "o que tem neste dia?". Por isso a lista se chama
/// "Próximos compromissos" e não "Próximas escalas" — prometer só escala
/// faria a reunião de quinta parecer uma delas.
class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  DateTime? _selected;
  DateTime? _month;
  String? _teamKey;
  int _upcomingCount = 6;
  AgendaFilter _filter = AgendaFilter.all;

  void _select(DateTime day) => setState(() {
        _selected = day;
        _month = DateTime(day.year, day.month);
        _upcomingCount = 6;
      });

  /// Trocar o recorte devolve a lista ao tamanho inicial: ter tocado em "ver
  /// mais" na agenda inteira não é um pedido para ver trinta e seis escalas
  /// suas.
  void _changeFilter(AgendaFilter filter) => setState(() {
        _filter = filter;
        _upcomingCount = 6;
      });

  Future<void> _refresh(String teamId) async {
    ref.invalidate(agendaNowProvider);
    for (final scope in ['upcoming', 'past']) {
      ref.invalidate(eventsProvider((teamId, scope)));
      ref.invalidate(agendaEventsProvider((teamId, scope)));
      ref.invalidate(teamEventsProvider((teamId, scope)));
    }
    // Os erros são exibidos pela tela, inclusive durante atualização manual.
    await Future.wait([
      for (final scope in ['upcoming', 'past'])
        ref.read(agendaEventsProvider((teamId, scope)).future).then<void>(
              (_) {},
              onError: (Object _, StackTrace stack) {},
            ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final teamId = ref.watch(activeTeamIdProvider);
    if (auth.teams.isEmpty || teamId == null) return const TeamOnboarding();
    final team = auth.teams.where((t) => t.teamId == teamId).firstOrNull ??
        auth.teams.first;
    final upcoming = ref.watch(agendaEventsProvider((teamId, 'upcoming')));
    final past = ref.watch(agendaEventsProvider((teamId, 'past')));
    final events = [
      ...upcoming.valueOrNull?.data ?? <Event>[],
      ...past.valueOrNull?.data ?? <Event>[],
    ];
    // Os eventos da equipe entram na mesma agenda, e não numa aba própria:
    // quem abre esta tela quer o mês inteiro, e "reunião de quinta" some se
    // estiver atrás de outro toque. Falham em silêncio de propósito — um
    // churrasco que não carregou não pode esconder o domingo.
    final teamEvents = [
      ...ref
              .watch(teamEventsProvider((teamId, 'upcoming')))
              .valueOrNull
              ?.data ??
          <TeamEvent>[],
      ...ref.watch(teamEventsProvider((teamId, 'past'))).valueOrNull?.data ??
          <TeamEvent>[],
    ];
    final teamTimezone = ref.watch(teamProvider(teamId)).valueOrNull?.timezone;
    final timezone = teamTimezone ??
        events.where((e) => e.timezone.isNotEmpty).firstOrNull?.timezone ??
        'America/Sao_Paulo';
    final localNow = eventLocalTime(ref.watch(agendaNowProvider), timezone);
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    if (_teamKey != '$teamId/$timezone') {
      _teamKey = '$teamId/$timezone';
      _selected = today;
      _month = DateTime(today.year, today.month);
      _upcomingCount = 6;
    }
    final selected = _selected!;
    final month = _month!;

    // A agenda inteira **e** o recorte escolhido. As duas listas existem por
    // causa do dia vazio: ele precisa saber a diferença entre "a equipe não
    // toca" e "a equipe toca, e você não" — dizer a primeira no lugar da
    // segunda esconderia uma escala que existe, que é o pior defeito que um
    // filtro pode ter.
    final allEntries = agendaEntries(events, teamEvents: teamEvents);
    final entries = filterAgendaEntries(
      allEntries,
      filter: _filter,
      membershipId: team.membershipId,
    );
    final groups = groupAgendaRows(entries);
    // **Linhas, e não horários**: o calendário conta compromissos como a lista
    // os conta. Um domingo com culto de manhã e de noite é *uma* escala, e
    // marcar dois traços ali faria a equipe achar que toca em dobro -- a mesma
    // razão pela qual `groupAgendaRows` existe.
    final markedDays = {
      for (final entry in groups.entries) entry.key: entry.value.length,
    };
    final selectedRows = groups[dateKey(selected)] ?? const <AgendaEntry>[];
    final dayHasAny =
        (groupAgendaRows(allEntries)[dateKey(selected)] ?? const <AgendaEntry>[])
            .isNotEmpty;
    final selectedIds = {for (final row in selectedRows) row.rowId};

    // As próximas, sem repetir o que já está na lista do dia. A ordem é a das
    // entradas, que vêm ordenadas pelo horário — escalas e eventos misturados,
    // porque é assim que o mês acontece.
    final nextRows = <AgendaEntry>[];
    for (final entry in entries) {
      if (entry.day.isBefore(today) || selectedIds.contains(entry.rowId)) {
        continue;
      }
      if (!nextRows.any((row) => row.rowId == entry.rowId)) {
        nextRows.add(entry);
      }
    }

    final daySource = selected.isBefore(today) ? past : upcoming;
    final dayIncomplete = _outsideCoverage(
      daySource.valueOrNull,
      selected,
      past: selected.isBefore(today),
    );
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final monthIncomplete =
        _outsideCoverage(past.valueOrNull, month, past: true) ||
            _outsideCoverage(upcoming.valueOrNull, monthEnd, past: false);
    final allLoaded = upcoming.hasValue && past.hasValue;
    final monthHasEntries = entries.any(
      (entry) => entry.day.year == month.year && entry.day.month == month.month,
    );

    // A grade de cultos só interessa a quem monta escala, e não no recorte
    // pessoal: nenhuma data em aberto é "sua" — não há ninguém escalado nela.
    final planning = team.canManage && !_filter.isMine;
    final templates = planning
        ? ref.watch(serviceTemplatesProvider(teamId)).valueOrNull
        : null;
    final planningDates = templates != null && upcoming.hasValue
        ? openDates(
            templates: templates,
            events: upcoming.valueOrNull!.data,
            timezone: timezone,
            now: localNow,
          )
        : const <OpenDate>[];
    final cacheDates = [
      for (final source in [upcoming, past])
        if (source.valueOrNull case final value?)
          if (value.fromCache && value.cachedAt != null) value.cachedAt!,
    ]..sort();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    void createSchedule() =>
        context.push('/agenda/novo?data=${dateKey(selected)}');
    void create() => _openCreateMenu(context, selected, today);

    // Largura da **janela**, e não a da lista: onde o botão de criar mora é
    // decisão sobre o formato da tela (polegar × mouse), e é a mesma decisão
    // que a Home toma — ver o botão mudar de forma ao trocar de aba é o que
    // faz duas telas parecerem de dois apps.
    final janelaLarga = AppBreakpoints.of(context).isWide;
    final fab = team.canManage && !janelaLarga;

    final calendar = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AgendaCalendar(
          month: month,
          selectedDay: selected,
          today: today,
          markedDays: markedDays,
          onSelected: _select,
          onMonthChanged: _select,
          onToday: () => _select(today),
          legend: _filter.isMine ? 'Seus compromissos' : 'Com compromisso',
        ),
        if (monthIncomplete)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child:
                Text('Este mês pode ter escalas fora do período disponível.'),
          )
        else if (allLoaded && !monthHasEntries)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              _filter.isMine
                  ? 'Você não tem escala neste mês.'
                  : 'Nenhuma escala neste mês.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );

    Widget daySection({required bool wide}) {
      if (daySource.isLoading && !daySource.hasValue) {
        return const _AgendaLoading();
      }
      if (daySource.hasError && !daySource.hasValue) {
        return _AgendaError(
          error: daySource.error!,
          onRetry: () => _refresh(teamId),
        );
      }
      return AppGroup(
        title: _dayLabel(selected, today),
        subtitle: dayIncomplete
            ? 'A consulta disponível não cobre este dia por completo.'
            : null,
        // Sem ação própria: criar evento saiu daqui e entrou no menu do botão
        // **Nova**, junto de criar escala. Eram dois pontos de partida para a
        // mesma intenção ("quero marcar alguma coisa"), em dois cantos da
        // tela e com dois pesos visuais -- e quem não conhece o vocabulário do
        // app precisava saber de antemão que "escala" e "evento" são coisas
        // diferentes para escolher por qual dos dois começar.
        dividerIndent: AppGroup.textIndent,
        children: selectedRows.isEmpty
            ? [
                _emptyDayRow(
                  dayIncomplete: dayIncomplete,
                  dayHasAny: dayHasAny,
                  canManage: team.canManage,
                  // Direto na escala, e não no menu: a linha já **diz** o que
                  // vai acontecer ("Criar escala"). Perguntar de novo logo
                  // depois seria um passo a mais para chegar no mesmo lugar.
                  onCreate: createSchedule,
                ),
              ]
            : [
                for (final row in selectedRows)
                  _agendaRow(
                    row,
                    prefixo: 'selected',
                    canManage: team.canManage,
                    membershipId: team.membershipId,
                    wide: wide,
                  ),
              ],
      );
    }

    return Scaffold(
      // No celular, o canto inferior direito é onde o polegar chega. Com
      // mouse ele sobe para o cabeçalho, junto do título da tela. A diferença
      // para a Home é o que o botão leva junto: aqui, o dia selecionado.
      floatingActionButton: fab
          ? FloatingActionButton.extended(
              onPressed: create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova'),
              tooltip: 'Criar escala ou evento',
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: AppContentWidth.wide(
          child: RefreshIndicator(
            onRefresh: () => _refresh(teamId),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // A largura de que a **lista** dispõe, e não a da janela: é o
                // mesmo número com que a Home vira a linha em colunas.
                final wide = constraints.maxWidth >= 880;
                final desktop =
                    AppBreakpoints.fromWidth(constraints.maxWidth).isDesktop;

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    // Espaço para o botão flutuante não cobrir a última linha.
                    // Sem ele (monitor), o rodapé volta ao normal.
                    fab ? AppSpacing.xxxl * 2 : AppSpacing.xxl,
                  ),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Agenda',
                                style: theme.textTheme.headlineSmall,
                              ),
                              Text(
                                team.name,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (auth.teams.length > 1)
                          PopupMenuButton<String>(
                            tooltip: 'Trocar equipe',
                            initialValue: teamId,
                            onSelected: (id) => ref
                                .read(activeTeamIdProvider.notifier)
                                .select(id),
                            icon: const Icon(Icons.unfold_more_rounded),
                            itemBuilder: (_) => [
                              for (final item in auth.teams)
                                CheckedPopupMenuItem(
                                  value: item.teamId,
                                  checked: item.teamId == teamId,
                                  child: Text(item.name),
                                ),
                            ],
                          ),
                        IconButton(
                          tooltip: 'Atualizar agenda',
                          onPressed: () => _refresh(teamId),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        if (team.canManage && janelaLarga)
                          IconButton.filled(
                            tooltip: 'Criar escala ou evento',
                            onPressed: create,
                            icon: const Icon(Icons.add_rounded),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const AppUpdateBanner(),
                    if (cacheDates.isNotEmpty) ...[
                      CacheStampBanner(cachedAt: cacheDates.first),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    // O recorte fica **acima** do calendário porque manda nele
                    // também: em "Minhas escalas" os pontos do mês passam a ser
                    // os dias em que você toca, que é a pergunta que traz a
                    // pessoa a esta tela.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: wide ? 420 : double.infinity,
                      ),
                      child: AppChoiceBar<AgendaFilter>(
                        value: _filter,
                        onChanged: _changeFilter,
                        options: const [
                          AppChoice(value: AgendaFilter.all, label: 'Todas'),
                          AppChoice(
                            value: AgendaFilter.mine,
                            label: 'Minhas escalas',
                            icon: Icons.star_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (!allLoaded)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          'Os indicadores do calendário aparecem conforme as '
                          'escalas carregam.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    if (desktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: calendar),
                          const SizedBox(width: AppSpacing.xl),
                          // Meia largura: a linha em colunas precisa dos 880px
                          // inteiros, e aqui ela tem metade.
                          Expanded(child: daySection(wide: false)),
                        ],
                      )
                    else ...[
                      calendar,
                      const SizedBox(height: AppSpacing.lg),
                      daySection(wide: wide),
                    ],
                    if (past.hasError &&
                        !past.hasValue &&
                        !selected.isBefore(today))
                      _AgendaError(
                        error: past.error!,
                        message:
                            'Não foi possível carregar as escalas passadas.',
                        onRetry: () => _refresh(teamId),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    if (upcoming.isLoading && !upcoming.hasValue)
                      const _AgendaLoading()
                    else if (upcoming.hasError && !upcoming.hasValue)
                      _AgendaError(
                        error: upcoming.error!,
                        onRetry: () => _refresh(teamId),
                      )
                    else
                      // O mesmo bloco da Home, com a mesma linha de escala. O
                      // título diz "compromissos" e não "escalas" porque aqui
                      // a lista tem as duas coisas -- e prometer só escala
                      // faria a reunião de quinta parecer uma delas.
                      AppGroup(
                        title: 'Próximos compromissos',
                        dividerIndent: AppGroup.textIndent,
                        children: [
                          if (nextRows.isEmpty)
                            AppGroupRow(
                              title: _filter.isMine
                                  ? 'Nada seu por perto.'
                                  : 'Nada mais marcado por perto.',
                              showChevron: false,
                            )
                          else ...[
                            for (final row in nextRows.take(_upcomingCount))
                              _agendaRow(
                                row,
                                prefixo: 'upcoming',
                                canManage: team.canManage,
                                membershipId: team.membershipId,
                                wide: wide,
                              ),
                            if (nextRows.length > _upcomingCount)
                              AppGroupRow(
                                icon: Icons.expand_more_rounded,
                                title: 'Ver mais',
                                showChevron: false,
                                onTap: () =>
                                    setState(() => _upcomingCount += 6),
                              ),
                          ],
                        ],
                      ),
                    if (planningDates.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      AgendaOpenDates(
                        teamId: teamId,
                        dates: planningDates,
                        wide: wide,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// O que se cria pelo botão **Nova**.
enum _NewKind { schedule, event }

/// O único ponto de partida da agenda: "quero marcar alguma coisa neste dia".
///
/// Eram dois. O botão flutuante criava escala e um "+ Evento" discreto, dentro
/// do cabeçalho da lista do dia, criava evento -- dois pesos visuais, dois
/// cantos da tela e a exigência de já saber a diferença entre as duas palavras
/// para escolher por onde começar. Agora a diferença é **explicada no momento
/// da escolha**, com uma linha embaixo de cada opção dizendo para que ela
/// serve.
///
/// Folha no celular e diálogo no monitor, pelo [showAdaptiveSheet] que o resto
/// do app já usa: a mesma escolha, no lugar onde a mão (ou o cursor) a espera.
/// Os dois caminhos continuam sendo os de sempre -- este menu só decide para
/// qual deles ir, e leva junto o **dia selecionado**, que é o que o botão da
/// agenda sempre teve de seu.
Future<void> _openCreateMenu(
  BuildContext context,
  DateTime selected,
  DateTime today,
) async {
  final choice = await showAdaptiveSheet<_NewKind>(
    context: context,
    maxWidth: 420,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final scheme = theme.colorScheme;

      return SafeArea(
        // Rolável: com a fonte do sistema aumentada as duas explicações
        // passam de duas linhas cada, e uma folha que não rola engole a
        // segunda opção — que é justamente a que veio ganhar visibilidade.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xs,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                // A data vem escrita: o botão leva o dia selecionado junto, e
                // quem toca nele depois de navegar pelo mês precisa ver em
                // qual dia a coisa vai nascer -- antes do formulário.
                child: SectionHeader(
                  title: 'Criar',
                  subtitle: _dayLabel(selected, today),
                  padding: EdgeInsets.zero,
                ),
              ),
              _CreateOption(
                icon: Icons.groups_rounded,
                title: 'Nova escala',
                subtitle: 'Culto com equipe escalada e repertório',
                onTap: () => Navigator.pop(sheetContext, _NewKind.schedule),
              ),
              Divider(
                color: scheme.outlineVariant,
                height: 1,
                indent: AppSpacing.xl,
                endIndent: AppSpacing.xl,
              ),
              _CreateOption(
                icon: Icons.event_rounded,
                title: 'Novo evento',
                subtitle: 'Reunião, ensaio extra, confraternização',
                onTap: () => Navigator.pop(sheetContext, _NewKind.event),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      );
    },
  );

  if (choice == null || !context.mounted) return;
  final dia = dateKey(selected);
  switch (choice) {
    case _NewKind.schedule:
      context.push('/agenda/novo?data=$dia');
    case _NewKind.event:
      context.push('/eventos/novo?data=$dia');
  }
}

/// Uma opção do menu de criação.
///
/// Linha inteira tocável e com a explicação embaixo do nome: é o mesmo formato
/// de [AppGroupRow], que é como o app escreve "escolha um destes" em toda
/// tela de configuração.
class _CreateOption extends StatelessWidget {
  const _CreateOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xs,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Uma linha da agenda, seja ela escala ou evento.
///
/// O `switch` é exaustivo por construção ([AgendaEntry] é `sealed`): quando
/// aparecer uma terceira natureza de compromisso, é o compilador que cobra o
/// desenho dela, e não uma tela mostrando uma linha em branco.
Widget _agendaRow(
  AgendaEntry row, {
  required String prefixo,
  required bool canManage,
  required String membershipId,
  required bool wide,
}) {
  final key = ValueKey('$prefixo-${row.rowId}');
  return switch (row) {
    ScheduleEntry(:final event) => CompactScheduleTile(
        key: key,
        event: event,
        canManage: canManage,
        membershipId: membershipId,
        wide: wide,
      ),
    TeamEventEntry(:final event) => TeamEventTile(
        key: key,
        event: event,
        wide: wide,
      ),
  };
}

/// O dia sem escala, dito pelo que de fato aconteceu.
///
/// Em "Minhas escalas", um domingo cheio de escala da equipe **não** é um dia
/// vazio: a frase separa "a equipe não toca" de "a equipe toca, e você não".
/// Trocar uma pela outra esconderia uma escala que existe — e é exatamente o
/// que um filtro mal escrito faz.
Widget _emptyDayRow({
  required bool dayIncomplete,
  required bool dayHasAny,
  required bool canManage,
  required VoidCallback onCreate,
}) {
  if (dayIncomplete) {
    return const AppGroupRow(
      title: 'Sem escalas nos dados disponíveis.',
      showChevron: false,
    );
  }
  if (dayHasAny) {
    return const AppGroupRow(
      title: 'Você não está escalado neste dia.',
      subtitle: 'A equipe tem escala aqui — veja em "Todas".',
      showChevron: false,
    );
  }
  if (!canManage) {
    return const AppGroupRow(
      title: 'Nada marcado para este dia.',
      showChevron: false,
    );
  }
  return AppGroupRow(
    icon: Icons.add_rounded,
    title: 'Criar escala',
    subtitle: 'Nada marcado para este dia.',
    onTap: onCreate,
  );
}

/// A API limita a consulta, sem paginação nem filtro por mês. Nunca apresentar
/// um dia além da borda como vazio conhecido; a própria borda pode estar partida.
bool _outsideCoverage(
  CachedValue<List<Event>>? value,
  DateTime day, {
  required bool past,
}) {
  if (value == null ||
      value.data.length < (value.fromCache ? 20 : agendaQueryLimit)) {
    return false;
  }
  final dates = value.data.map((event) {
    final local = eventLocalTime(
      event.startsAt,
      event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone,
    );
    return DateTime(local.year, local.month, local.day);
  }).toList()
    ..sort();
  return past ? !day.isAfter(dates.first) : !day.isBefore(dates.last);
}

String _dayLabel(DateTime day, DateTime today) => capitalizeWeekday(
      DateFormat(
        day.year == today.year
            ? "EEEE, d 'de' MMMM"
            : "EEEE, d 'de' MMMM 'de' y",
        'pt_BR',
      ).format(day),
    );

class _AgendaLoading extends StatelessWidget {
  const _AgendaLoading();
  @override
  Widget build(BuildContext context) => const AppCard(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeleton(width: 80, height: 18),
            SizedBox(height: AppSpacing.md),
            AppSkeleton(width: 180, height: 16),
            SizedBox(height: AppSpacing.sm),
            AppSkeleton(width: 120, height: 12),
          ],
        ),
      );
}

class _AgendaError extends StatelessWidget {
  const _AgendaError({
    required this.error,
    required this.onRetry,
    this.message,
  });
  final Object error;
  final VoidCallback onRetry;
  final String? message;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message ??
                  (error is ApiException
                      ? (error as ApiException).message
                      : 'Não foi possível carregar a agenda.'),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
}
