import 'package:flutter/material.dart';

import '../../../core/date/civil_date.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_month_grid.dart';

/// O que o seletor devolve: o conjunto final de dias marcados (não só os
/// novos, para a tela calcular o que entrou e o que saiu) e o motivo dos dias
/// que entraram.
typedef MultiDatePick = ({Set<DateTime> dates, String? reason});

/// Motivos que se repetem. Tocar preenche o campo; escrever outro continua
/// valendo.
const unavailabilityReasons = ['Viagem', 'Trabalho', 'Saúde', 'Família'];

/// Calendário de seleção múltipla.
///
/// O Flutter só traz `showDatePicker` (um dia) e `showDateRangePicker` (um
/// intervalo contínuo). Nenhum dos dois serve aqui: quem viaja costuma perder
/// três domingos seguidos e estar presente nos dias entre eles. Este seletor
/// alterna dia a dia.
///
/// **O motivo vem na mesma folha.** Era um segundo diálogo depois de
/// confirmar os dias ("Quer dizer o motivo?", com "Pular") — um passo a mais
/// para uma pergunta opcional. Agora ele aparece embaixo do calendário assim
/// que algum dia novo é marcado.
///
/// [isServiceDay] marca os dias em que a igreja tem culto pela grade: são os
/// únicos que importam, e sem a marca a pessoa procurava o domingo certo entre
/// trinta números iguais.
Future<MultiDatePick?> showMultiDatePicker({
  required BuildContext context,
  required Set<DateTime> initialSelection,
  bool Function(DateTime day)? isServiceDay,
  int monthsAhead = 12,
}) {
  return showModalBottomSheet<MultiDatePick>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MultiDatePickerSheet(
      initialSelection: initialSelection,
      isServiceDay: isServiceDay,
      monthsAhead: monthsAhead,
    ),
  );
}

DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

class _MultiDatePickerSheet extends StatefulWidget {
  const _MultiDatePickerSheet({
    required this.initialSelection,
    required this.isServiceDay,
    required this.monthsAhead,
  });

  final Set<DateTime> initialSelection;
  final bool Function(DateTime day)? isServiceDay;
  final int monthsAhead;

  @override
  State<_MultiDatePickerSheet> createState() => _MultiDatePickerSheetState();
}

class _MultiDatePickerSheetState extends State<_MultiDatePickerSheet> {
  late final Set<DateTime> _selected = {...widget.initialSelection};
  late final DateTime _today = _dayOnly(DateTime.now());
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _hasNewDays =>
      _selected.any((day) => !widget.initialSelection.contains(day));

  void _toggle(DateTime day) {
    setState(() {
      if (!_selected.remove(day)) {
        _selected.add(day);
      }
    });
  }

  void _confirm() {
    final reason = _reason.text.trim();
    final MultiDatePick pick = (
      dates: _selected,
      reason: _hasNewDays && reason.isNotEmpty ? reason : null,
    );
    Navigator.of(context).pop(pick);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: (media.size.height - media.viewInsets.bottom) * 0.85,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Toque nos dias. Podem ser vários, sem precisar '
                            'ser seguidos.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (widget.isServiceDay != null) ...[
                          const SizedBox(width: AppSpacing.md),
                          const AppDayLegendChip(),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Dia de culto',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const _WeekdayHeader(),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  itemCount: widget.monthsAhead + 1,
                  itemBuilder: (context, index) {
                    final month = DateTime(_today.year, _today.month + index);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.sm,
                              AppSpacing.lg,
                              AppSpacing.sm,
                              AppSpacing.sm,
                            ),
                            child: Text(
                              monthYearLabel(month),
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          AppMonthGrid(
                            month: month,
                            today: _today,
                            showWeekdays: false,
                            keyPrefix: 'indisponivel-',
                            onTap: _toggle,
                            describe: (day) {
                              final service =
                                  widget.isServiceDay?.call(day) ?? false;
                              return AppMonthDay(
                                selected: _selected.contains(day),
                                marks: service ? 1 : 0,
                                // Dia passado não é marcável: o backend recusa
                                // e não haveria o que avisar sobre uma escala
                                // que já aconteceu.
                                enabled: !day.isBefore(_today),
                                detail: service ? 'dia de culto' : null,
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              if (_hasNewDays)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: UnavailabilityReasonField(controller: _reason),
                ),
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
                      onPressed: _confirm,
                      child: const Text('Confirmar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O motivo, opcional: chips para os que se repetem e o campo para o resto.
///
/// Exposto porque a correção do motivo de um dia já marcado usa a mesma peça.
class UnavailabilityReasonField extends StatelessWidget {
  const UnavailabilityReasonField({
    super.key,
    required this.controller,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final reason in unavailabilityReasons)
                ChoiceChip(
                  label: Text(reason),
                  selected: controller.text.trim() == reason,
                  // Tocar no escolhido limpa: é como se volta atrás sem um
                  // chip "nenhum".
                  onSelected: (on) => controller.text = on ? reason : '',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            autofocus: autofocus,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Motivo (opcional)',
              hintText: 'Viagem, trabalho...',
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

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
