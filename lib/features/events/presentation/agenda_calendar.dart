import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/date/civil_date.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../domain/event_datetime.dart';

/// Calendário de consulta, independente dos modelos de escala e de Riverpod.
/// Segue a semana e as cores do seletor de indisponibilidade; aqui o passado
/// também é selecionável e os pontos representam as escalas que existem.
///
/// **O que o ponto significa é de quem chama** ([legend]): a agenda inteira
/// pinta os dias com algo marcado -- escala ou evento --, e o recorte pessoal
/// pinta os dias que são seus.
/// É o mesmo desenho dizendo duas coisas, e o rótulo embaixo é o que separa as
/// duas — inclusive para quem ouve a tela.
class AgendaCalendar extends StatelessWidget {
  const AgendaCalendar({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.today,
    required this.markedDays,
    required this.onSelected,
    required this.onMonthChanged,
    required this.onToday,
    this.legend = 'Com compromisso',
  });

  final DateTime month;
  final DateTime selectedDay;
  final DateTime today;
  final Set<String> markedDays;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime> onMonthChanged;
  final VoidCallback onToday;

  /// O que um dia marcado quer dizer. Vai na legenda e na leitura de tela.
  final String legend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final leading = DateTime(month.year, month.month).weekday % 7;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((leading + count) / 7).ceil();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mês anterior',
                onPressed: () => onMonthChanged(
                  DateTime(month.year, month.month - 1),
                ),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  monthYearLabel(month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Próximo mês',
                onPressed: () => onMonthChanged(
                  DateTime(month.year, month.month + 1),
                ),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              // Em celulares muito estreitos, conserva o alvo de toque sem
              // diminuir a fonte escolhida pelo usuário.
              final width = math.max(constraints.maxWidth, 7 * 44.0);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Table(
                    children: [
                      TableRow(
                        children: [
                          for (final label in [
                            'D',
                            'S',
                            'T',
                            'Q',
                            'Q',
                            'S',
                            'S',
                          ])
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                              ),
                              child: ExcludeSemantics(
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      for (var row = 0; row < rows; row++)
                        TableRow(
                          children: [
                            for (var col = 0; col < 7; col++)
                              if (row * 7 + col < leading ||
                                  row * 7 + col >= leading + count)
                                const SizedBox.shrink()
                              else
                                _day(
                                  context,
                                  DateTime(
                                    month.year,
                                    month.month,
                                    row * 7 + col - leading + 1,
                                  ),
                                ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Icon(Icons.circle, size: 5, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    legend,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                TextButton(onPressed: onToday, child: const Text('Hoje')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _day(BuildContext context, DateTime day) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = dateKey(day) == dateKey(selectedDay);
    final isToday = dateKey(day) == dateKey(today);
    final marked = markedDays.contains(dateKey(day));
    final color = selected ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      key: ValueKey('agenda-day-${dateKey(day)}'),
      button: true,
      selected: selected,
      label:
          '${capitalizeWeekday(DateFormat("EEEE, d 'de' MMMM 'de' y", 'pt_BR').format(day))}'
          '${isToday ? ', hoje' : ''}'
          '${marked ? ', ${legend.toLowerCase()}' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Material(
          color: selected ? scheme.primary : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            side: isToday
                ? BorderSide(
                    color: selected ? scheme.onPrimary : scheme.primary,
                    width: 2,
                  )
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onSelected(day),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${day.day}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: selected || isToday
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Icon(
                      Icons.circle,
                      size: 5,
                      color: marked
                          ? (selected ? scheme.onPrimary : scheme.primary)
                          : Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
