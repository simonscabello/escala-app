import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../events/domain/event_datetime.dart';

/// Calendário de seleção múltipla.
///
/// O Flutter só traz `showDatePicker` (um dia) e `showDateRangePicker` (um
/// intervalo contínuo). Nenhum dos dois serve aqui: quem viaja costuma perder
/// três domingos seguidos e estar presente nos dias entre eles. Este seletor
/// alterna dia a dia.
///
/// Devolve o conjunto final de dias marcados (não só os novos), para a tela
/// poder calcular o que entrou e o que saiu.
Future<Set<DateTime>?> showMultiDatePicker({
  required BuildContext context,
  required Set<DateTime> initialSelection,
  int monthsAhead = 12,
}) {
  return showModalBottomSheet<Set<DateTime>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MultiDatePickerSheet(
      initialSelection: initialSelection,
      monthsAhead: monthsAhead,
    ),
  );
}

DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

class _MultiDatePickerSheet extends StatefulWidget {
  const _MultiDatePickerSheet({
    required this.initialSelection,
    required this.monthsAhead,
  });

  final Set<DateTime> initialSelection;
  final int monthsAhead;

  @override
  State<_MultiDatePickerSheet> createState() => _MultiDatePickerSheetState();
}

class _MultiDatePickerSheetState extends State<_MultiDatePickerSheet> {
  late final Set<DateTime> _selected = {...widget.initialSelection};
  late final DateTime _today = _dayOnly(DateTime.now());

  void _toggle(DateTime day) {
    setState(() {
      if (!_selected.remove(day)) {
        _selected.add(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dias em que não posso',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Toque nos dias. Podem ser vários, sem precisar ser '
                    'seguidos.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _WeekdayHeader(),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                itemCount: widget.monthsAhead + 1,
                itemBuilder: (context, index) {
                  final month = DateTime(
                    _today.year,
                    _today.month + index,
                  );
                  return _MonthGrid(
                    month: month,
                    today: _today,
                    selected: _selected,
                    onToggle: _toggle,
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selected.isEmpty
                          ? 'Nenhum dia marcado'
                          : '${_selected.length} '
                              '${_selected.length == 1 ? 'dia marcado' : 'dias marcados'}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('Confirmar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Semana começando no domingo, como no calendário brasileiro.
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

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.selected,
    required this.onToggle,
  });

  final DateTime month;
  final DateTime today;
  final Set<DateTime> selected;
  final ValueChanged<DateTime> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // weekday: seg=1 ... dom=7. Com a semana começando no domingo, o domingo
    // vai para a coluna 0.
    final leading = DateTime(month.year, month.month, 1).weekday % 7;
    final title = capitalizeWeekday(
      DateFormat("MMMM 'de' y", 'pt_BR').format(month),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.sm,
          ),
          child: Text(title, style: theme.textTheme.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: leading + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leading) return const SizedBox.shrink();

              final day = DateTime(
                month.year,
                month.month,
                index - leading + 1,
              );

              return _DayCell(
                day: day,
                isToday: day == today,
                isPast: day.isBefore(today),
                isSelected: selected.contains(day),
                onTap: () => onToggle(day),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isPast,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isPast;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final color = isSelected
        ? scheme.onPrimary
        : (isPast ? scheme.onSurfaceVariant.withValues(alpha: 0.4) : null);

    return Center(
      child: InkWell(
        // Dia passado não é marcável: o backend recusa e não haveria o que
        // avisar sobre uma escala que já aconteceu.
        onTap: isPast ? null : onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? scheme.primary : null,
            border: isToday && !isSelected
                ? Border.all(color: scheme.primary)
                : null,
          ),
          child: Text(
            '${day.day}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight:
                  isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
