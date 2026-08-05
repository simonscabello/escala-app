import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/network/api_exception.dart';
import '../data/event_repository.dart';
import '../domain/event_models.dart';

/// Pede a data/hora do novo culto e chama a API de duplicação.
Future<void> showDuplicateEventDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Event source,
}) async {
  final timezone =
      source.timezone.isEmpty ? 'America/Sao_Paulo' : source.timezone;
  final location = tz.getLocation(timezone);
  final localStart = tz.TZDateTime.from(source.startsAt, location);
  // Sugere +7 dias, mesmo horário local.
  var pickedLocal = localStart.add(const Duration(days: 7));

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final label = DateFormat(
            "EEEE, d 'de' MMMM 'às' HH:mm",
            'pt_BR',
          ).format(pickedLocal);

          return AlertDialog(
            title: const Text('Duplicar culto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Copia a escalação e os detalhes de "${source.title}" '
                  'para a nova data. O ensaio mantém a mesma diferença.',
                ),
                const SizedBox(height: 16),
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime(
                            pickedLocal.year,
                            pickedLocal.month,
                            pickedLocal.day,
                          ),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (date == null) return;
                        setState(() {
                          pickedLocal = tz.TZDateTime(
                            location,
                            date.year,
                            date.month,
                            date.day,
                            pickedLocal.hour,
                            pickedLocal.minute,
                          );
                        });
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: const Text('Data'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: pickedLocal.hour,
                            minute: pickedLocal.minute,
                          ),
                        );
                        if (time == null) return;
                        setState(() {
                          pickedLocal = tz.TZDateTime(
                            location,
                            pickedLocal.year,
                            pickedLocal.month,
                            pickedLocal.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                      icon: const Icon(Icons.schedule_outlined),
                      label: const Text('Hora'),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => dialogContext.pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => dialogContext.pop(true),
                child: const Text('Duplicar'),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final created = await ref.read(eventRepositoryProvider).duplicate(
          source.id,
          startsAt: pickedLocal.toUtc().toIso8601String(),
        );
    ref.invalidate(eventsProvider((source.teamId, 'upcoming')));
    ref.invalidate(eventsProvider((source.teamId, 'past')));
    if (!context.mounted) return;
    context.push('/agenda/${created.id}');
  } on ApiException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.message)),
    );
  }
}
