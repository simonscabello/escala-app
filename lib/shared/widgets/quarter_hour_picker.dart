import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Seletor de hora em passos de 15 minutos.
///
/// O `showTimePicker` do Material nao aceita passo: ou o usuario digita
/// qualquer minuto, ou arrasta um mostrador de 60 posicoes. Culto e ensaio
/// nunca comecam 09:07, entao as outras 45 opcoes por hora so atrapalham.
///
/// Duas rodas em vez de arredondar o resultado do seletor padrao: arredondar
/// mudaria em silencio o que a pessoa escolheu.
Future<TimeOfDay?> showQuarterHourPicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String title = 'Escolha o horario',
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => _QuarterHourSheet(
      initialTime: initialTime,
      title: title,
    ),
  );
}

/// Minutos oferecidos. Trocar esta lista muda o passo do seletor inteiro.
const _minutes = [0, 15, 30, 45];

/// Encaixa um horario qualquer na grade de 15 minutos, para a roda abrir com
/// algo selecionado. So afeta a posicao inicial: nada e salvo sem confirmar.
int _nearestQuarterIndex(int minute) {
  var best = 0;
  for (var i = 1; i < _minutes.length; i++) {
    if ((minute - _minutes[i]).abs() < (minute - _minutes[best]).abs()) {
      best = i;
    }
  }
  return best;
}

class _QuarterHourSheet extends StatefulWidget {
  const _QuarterHourSheet({required this.initialTime, required this.title});

  final TimeOfDay initialTime;
  final String title;

  @override
  State<_QuarterHourSheet> createState() => _QuarterHourSheetState();
}

class _QuarterHourSheetState extends State<_QuarterHourSheet> {
  late int _hour = widget.initialTime.hour;
  late int _minuteIndex = _nearestQuarterIndex(widget.initialTime.minute);

  late final FixedExtentScrollController _hourController =
      FixedExtentScrollController(initialItem: _hour);
  late final FixedExtentScrollController _minuteController =
      FixedExtentScrollController(initialItem: _minuteIndex);

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'De 15 em 15 minutos.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 180,
              child: Stack(
                children: [
                  // Faixa da selecao desenhada atras das rodas: sem ela nao ha
                  // como saber qual item esta valendo.
                  Center(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _Wheel(
                          controller: _hourController,
                          count: 24,
                          selected: _hour,
                          labelAt: (i) => i.toString().padLeft(2, '0'),
                          onSelected: (i) => setState(() => _hour = i),
                        ),
                      ),
                      Text(':', style: theme.textTheme.headlineSmall),
                      Expanded(
                        child: _Wheel(
                          controller: _minuteController,
                          count: _minutes.length,
                          selected: _minuteIndex,
                          labelAt: (i) =>
                              _minutes[i].toString().padLeft(2, '0'),
                          onSelected: (i) =>
                              setState(() => _minuteIndex = i),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                TimeOfDay(hour: _hour, minute: _minutes[_minuteIndex]),
              ),
              child: const Text('Confirmar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.count,
    required this.selected,
    required this.labelAt,
    required this.onSelected,
  });

  final FixedExtentScrollController controller;
  final int count;
  final int selected;
  final String Function(int index) labelAt;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 44,
      perspective: 0.004,
      diameterRatio: 1.6,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onSelected,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, index) {
          final active = index == selected;
          return Center(
            child: Text(
              labelAt(index),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          );
        },
      ),
    );
  }
}
