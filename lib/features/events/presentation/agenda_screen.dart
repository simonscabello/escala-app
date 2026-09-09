import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/date/civil_date.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/responsive/app_breakpoints.dart';
import '../../../core/storage/read_cache.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/cache_stamp_banner.dart';
import '../../auth/application/auth_controller.dart';
import '../../team/data/team_repository.dart';
import '../../team/presentation/team_onboarding.dart';
import '../../update/presentation/app_update_banner.dart';
import '../data/agenda_provider.dart';
import '../data/event_repository.dart';
import '../domain/agenda_entry.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';
import '../domain/open_date.dart';
import 'agenda_calendar.dart';
import 'agenda_entry_card.dart';
import 'agenda_open_dates.dart';

final agendaNowProvider = Provider<DateTime>((ref) => DateTime.now());

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

  void _select(DateTime day) => setState(() {
        _selected = day;
        _month = DateTime(day.year, day.month);
        _upcomingCount = 6;
      });

  Future<void> _refresh(String teamId) async {
    ref.invalidate(agendaNowProvider);
    for (final scope in ['upcoming', 'past']) {
      ref.invalidate(eventsProvider((teamId, scope)));
      ref.invalidate(agendaEventsProvider((teamId, scope)));
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
    final entries = agendaEntries(events);
    final groups = groupAgendaEntries(entries);
    final selectedEntries = groups[dateKey(selected)] ?? const <AgendaEntry>[];
    final nextEntries = entries
        .where((entry) => !entry.day.isBefore(today) && entry.day != selected)
        .toList();
    final nextGroups =
        groupAgendaEntries(nextEntries.take(_upcomingCount).toList());
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
    final templates = team.canManage
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
    void create() => context.push('/agenda/novo?data=${dateKey(selected)}');

    final calendar = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AgendaCalendar(
          month: month,
          selectedDay: selected,
          today: today,
          markedDays: groups.keys.toSet(),
          onSelected: _select,
          onMonthChanged: _select,
          onToday: () => _select(today),
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
              'Nenhum compromisso neste mês.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
    final daySection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_dayLabel(selected, today), style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        if (daySource.isLoading && !daySource.hasValue)
          const _AgendaLoading()
        else if (daySource.hasError && !daySource.hasValue)
          _AgendaError(error: daySource.error!, onRetry: () => _refresh(teamId))
        else ...[
          if (dayIncomplete)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                'A consulta disponível não cobre este dia por completo.',
              ),
            ),
          if (selectedEntries.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayIncomplete
                        ? 'Sem compromissos nos dados disponíveis.'
                        : 'Nada marcado para este dia.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (team.canManage)
                    TextButton.icon(
                      onPressed: create,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Criar escala'),
                    ),
                ],
              ),
            )
          else
            for (final entry in selectedEntries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AgendaEntryCard(
                  key: ValueKey('selected-${entry.id}'),
                  entry: entry,
                  membershipId: team.membershipId,
                  canManage: team.canManage,
                ),
              ),
        ],
      ],
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AppContentWidth.wide(
          child: RefreshIndicator(
            onRefresh: () => _refresh(teamId),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Agenda', style: theme.textTheme.headlineSmall),
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
                        onSelected: (id) =>
                            ref.read(activeTeamIdProvider.notifier).select(id),
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
                    if (team.canManage)
                      IconButton.filled(
                        tooltip: 'Nova escala',
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
                if (!allLoaded)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'Os indicadores do calendário aparecem conforme as escalas carregam.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (AppBreakpoints.fromWidth(constraints.maxWidth)
                        .isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: calendar),
                          const SizedBox(width: AppSpacing.xl),
                          Expanded(child: daySection),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        calendar,
                        const SizedBox(height: AppSpacing.lg),
                        daySection,
                      ],
                    );
                  },
                ),
                if (past.hasError &&
                    !past.hasValue &&
                    !selected.isBefore(today))
                  _AgendaError(
                    error: past.error!,
                    message: 'Não foi possível carregar as escalas passadas.',
                    onRetry: () => _refresh(teamId),
                  ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Próximos compromissos',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                if (upcoming.isLoading && !upcoming.hasValue)
                  const _AgendaLoading()
                else if (upcoming.hasError && !upcoming.hasValue)
                  _AgendaError(
                    error: upcoming.error!,
                    onRetry: () => _refresh(teamId),
                  )
                else if (nextGroups.isEmpty)
                  Text(
                    'Nenhum outro compromisso próximo.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  )
                else
                  for (final group in nextGroups.entries) ...[
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Text(
                        _dayLabel(group.value.first.day, today),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    for (final entry in group.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AgendaEntryCard(
                          key: ValueKey('upcoming-${entry.id}'),
                          entry: entry,
                          membershipId: team.membershipId,
                          canManage: team.canManage,
                        ),
                      ),
                  ],
                if (nextEntries.length > _upcomingCount)
                  TextButton(
                    onPressed: () => setState(() => _upcomingCount += 6),
                    child: const Text('Ver mais compromissos'),
                  ),
                if (planningDates.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  AgendaOpenDates(
                    teamId: teamId,
                    dates: planningDates,
                    wide: false,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
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
