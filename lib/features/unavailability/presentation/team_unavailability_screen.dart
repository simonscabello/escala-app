import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_states.dart';
import '../../events/domain/event_datetime.dart';
import '../../team/data/team_repository.dart';
import '../data/unavailability_repository.dart';
import '../domain/unavailability_models.dart';

/// O mês da equipe: quem avisou que não pode, e em que dia.
///
/// A indisponibilidade já existia dos dois lados — o integrante marcava os dias
/// e a escala mostrava o aviso —, mas só **dentro** de uma escala já criada. O
/// líder que planeja o mês descobria a ausência tarde: depois de escalar. Aqui
/// ele vê o mês antes de montar qualquer coisa, e cria a escala do dia a partir
/// do próprio calendário.
class TeamUnavailabilityScreen extends ConsumerStatefulWidget {
  const TeamUnavailabilityScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<TeamUnavailabilityScreen> createState() =>
      _TeamUnavailabilityScreenState();
}

class _TeamUnavailabilityScreenState
    extends ConsumerState<TeamUnavailabilityScreen> {
  late DateTime _month = _monthOf(DateTime.now());

  /// Nulo = a equipe inteira. Com alguém escolhido, o calendário responde
  /// "quando o João não pode?", que é a pergunta de quem já sabe de quem
  /// precisa e procura o domingo em que ele está livre.
  String? _memberFilter;

  static DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

  void _shiftMonth(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
  }

  @override
  Widget build(BuildContext context) {
    final key = (
      teamId: widget.teamId,
      year: _month.year,
      month: _month.month,
    );
    final unavailability = ref.watch(teamUnavailabilityProvider(key));
    final members = ref.watch(membersProvider(widget.teamId)).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quem não pode'),
        actions: [
          if (members != null && members.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Filtrar por pessoa',
              icon: Icon(
                _memberFilter == null
                    ? Icons.filter_alt_outlined
                    : Icons.filter_alt_rounded,
              ),
              onSelected: (value) => setState(
                () => _memberFilter = value.isEmpty ? null : value,
              ),
              itemBuilder: (_) => [
                const PopupMenuItem(value: '', child: Text('Todo mundo')),
                for (final member in members)
                  PopupMenuItem(
                    value: member.id,
                    child: Text(member.displayName),
                  ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AppContentWidth(
          child: Column(
            children: [
              _MonthHeader(
                month: _month,
                onPrevious: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
              ),
              Expanded(
                child: unavailability.when(
                  loading: () => const AppLoading(),
                  error: (error, _) => AppErrorState(
                    message: error is ApiException
                        ? error.message
                        : 'Não foi possível carregar o calendário.',
                    onRetry: () =>
                        ref.invalidate(teamUnavailabilityProvider(key)),
                  ),
                  data: (all) {
                    final visible = _memberFilter == null
                        ? all
                        : all
                            .where((item) => item.membershipId == _memberFilter)
                            .toList();
                    return _MonthBody(
                      teamId: widget.teamId,
                      month: _month,
                      items: visible,
                      filteredName: _memberFilter == null
                          ? null
                          : members
                              ?.where((m) => m.id == _memberFilter)
                              .firstOrNull
                              ?.displayName,
                      onRefresh: () async => ref
                          .refresh(teamUnavailabilityProvider(key).future),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = capitalizeWeekday(
      DateFormat("MMMM 'de' y", 'pt_BR').format(month),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Mês anterior',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Próximo mês',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _MonthBody extends StatelessWidget {
  const _MonthBody({
    required this.teamId,
    required this.month,
    required this.items,
    required this.filteredName,
    required this.onRefresh,
  });

  final String teamId;
  final DateTime month;
  final List<Unavailability> items;

  /// Nome de quem está filtrado, para o vazio dizer de quem ele fala.
  final String? filteredName;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final byDay = <int, List<Unavailability>>{};
    for (final item in items) {
      if (item.date.year != month.year || item.date.month != month.month) {
        continue;
      }
      byDay.putIfAbsent(item.date.day, () => []).add(item);
    }

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // weekday: seg=1 … dom=7. Com a semana começando no domingo, o domingo vai
    // para a coluna 0.
    final leading = DateTime(month.year, month.month, 1).weekday % 7;
    final today = DateTime.now();
    final todayDay = today.year == month.year && today.month == month.month
        ? today.day
        : null;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          const _WeekdayHeader(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.85,
              ),
              itemCount: leading + daysInMonth,
              itemBuilder: (context, index) {
                if (index < leading) return const SizedBox.shrink();

                final dayNumber = index - leading + 1;
                final day = DateTime(month.year, month.month, dayNumber);
                final people = byDay[dayNumber] ?? const <Unavailability>[];

                return _DayCell(
                  day: day,
                  isToday: dayNumber == todayDay,
                  people: people,
                  onTap: people.isEmpty
                      ? null
                      : () => _openDay(context, day, people),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (byDay.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
              ),
              child: Text(
                filteredName == null
                    ? 'Ninguém avisou indisponibilidade neste mês.'
                    : '$filteredName não marcou nenhum dia neste mês.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            // A lista abaixo do calendário não é repetição: a grade responde
            // "quais domingos estão comprometidos?" de relance, e a lista
            // responde "quem, e por quê?" sem exigir um toque por dia.
            for (final day in byDay.keys.toList()..sort())
              _DaySummary(
                day: DateTime(month.year, month.month, day),
                people: byDay[day]!,
                onTap: () => _openDay(
                  context,
                  DateTime(month.year, month.month, day),
                  byDay[day]!,
                ),
              ),
        ],
      ),
    );
  }

  void _openDay(
    BuildContext context,
    DateTime day,
    List<Unavailability> people,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _DaySheet(teamId: teamId, day: day, people: people),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const labels = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (final label in labels)
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Um dia da grade. O número de pessoas vem em âmbar, o papel de atenção da
/// paleta — não é erro, é algo a considerar antes de escalar.
///
/// **A cor não é o único sinal** (WCAG 1.4.1): o número de ausentes aparece
/// escrito abaixo do dia, e o leitor de tela recebe a frase inteira.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.people,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final List<Unavailability> people;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warning = AppStatusColors.of(context).warning;
    final count = people.length;

    return Semantics(
      button: onTap != null,
      excludeSemantics: true,
      label: [
        capitalizeWeekday(DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(day)),
        if (count == 0)
          'ninguém avisou que não pode'
        else if (count == 1)
          '1 pessoa não pode'
        else
          '$count pessoas não podem',
      ].join(': '),
      child: InkWell(
        onTap: onTap,
        customBorder: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusMd)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: count > 0 ? warning.container : null,
                border:
                    isToday ? Border.all(color: scheme.primary, width: 2) : null,
              ),
              child: Text(
                '${day.day}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: count > 0 ? warning.onContainer : null,
                  fontWeight: count > 0 || isToday
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ),
            SizedBox(
              height: 14,
              child: count == 0
                  ? null
                  : Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: warning.foreground,
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

class _DaySummary extends StatelessWidget {
  const _DaySummary({
    required this.day,
    required this.people,
    required this.onTap,
  });

  final DateTime day;
  final List<Unavailability> people;
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
      title: Text(
        capitalizeWeekday(DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(day)),
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        people.map((person) => person.displayName ?? 'Alguém').join(', '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _DaySheet extends StatelessWidget {
  const _DaySheet({
    required this.teamId,
    required this.day,
    required this.people,
  });

  final String teamId;
  final DateTime day;
  final List<Unavailability> people;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateKey = '${day.year}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              capitalizeWeekday(
                DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(day),
              ),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              people.length == 1
                  ? '1 pessoa avisou que não pode'
                  : '${people.length} pessoas avisaram que não podem',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final person in people)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AppAvatar(
                  name: person.displayName ?? '?',
                  radius: 18,
                ),
                title: Text(person.displayName ?? 'Alguém'),
                subtitle: person.reason == null ? null : Text(person.reason!),
              ),
            const SizedBox(height: AppSpacing.md),
            // O calendário existe para virar decisão: é daqui que sai a escala
            // do dia, já sabendo quem não está.
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/agenda/novo?data=$dateKey');
              },
              icon: const Icon(Icons.event_available_rounded, size: 18),
              label: const Text('Criar escala neste dia'),
            ),
          ],
        ),
      ),
    );
  }
}
