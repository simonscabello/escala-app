import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_states.dart';
import '../../events/domain/event_datetime.dart';
import '../data/unavailability_repository.dart';
import '../domain/unavailability_models.dart';
import 'multi_date_picker.dart';

/// "Não posso nesses dias".
///
/// O modelo é avisar antes, não confirmar depois: em vez de a escala sair e
/// cada pessoa aceitar ou recusar, quem sabe que vai faltar marca o dia com
/// antecedência e quem monta a escala já enxerga isso na hora de escalar.
class MyUnavailabilityScreen extends ConsumerStatefulWidget {
  const MyUnavailabilityScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<MyUnavailabilityScreen> createState() =>
      _MyUnavailabilityScreenState();
}

class _MyUnavailabilityScreenState
    extends ConsumerState<MyUnavailabilityScreen> {
  bool _saving = false;

  /// O calendário edita o conjunto inteiro: o que a pessoa desmarcar é
  /// removido, o que marcar é criado. Assim o calendário mostra a verdade e
  /// não vira só um formulário de inclusão.
  Future<void> _editDays(List<Unavailability> current) async {
    final existing = {
      for (final item in current)
        if (!item.date.isBefore(_today)) item.date: item.id,
    };

    final result = await showMultiDatePicker(
      context: context,
      initialSelection: existing.keys.toSet(),
    );

    if (result == null || !mounted) return;

    final added = result.difference(existing.keys.toSet()).toList()..sort();
    final removedIds = [
      for (final entry in existing.entries)
        if (!result.contains(entry.key)) entry.value,
    ];

    if (added.isEmpty && removedIds.isEmpty) return;

    // Motivo só faz sentido quando há dias novos.
    final reason = added.isEmpty ? null : await _askReason();
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      final repository = ref.read(unavailabilityRepositoryProvider);

      for (final id in removedIds) {
        await repository.remove(widget.teamId, id);
      }
      if (added.isNotEmpty) {
        await repository.add(widget.teamId, dates: added, reason: reason);
      }

      ref.invalidate(myUnavailabilityProvider(widget.teamId));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _askReason() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quer dizer o motivo?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Viagem, trabalho... (opcional)',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Pular'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(Unavailability item) async {
    try {
      await ref
          .read(unavailabilityRepositoryProvider)
          .remove(widget.teamId, item.id);
      ref.invalidate(myUnavailabilityProvider(widget.teamId));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = ref.watch(myUnavailabilityProvider(widget.teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('Minha disponibilidade')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving
            ? null
            : () => _editDays(
                  ref.read(myUnavailabilityProvider(widget.teamId)).value ??
                      const [],
                ),
        icon: const Icon(Icons.edit_calendar_rounded),
        label: const Text('Escolher dias'),
      ),
      body: SafeArea(
        top: false,
        child: items.when(
        loading: () => const AppLoading(),
        error: (error, _) => AppErrorState(
          message: error is ApiException
              ? error.message
              : 'Não foi possível carregar seus dias.',
          onRetry: () =>
              ref.invalidate(myUnavailabilityProvider(widget.teamId)),
        ),
        data: (list) {
          final upcoming = list
              .where((i) => !i.date.isBefore(_today))
              .toList(growable: false);

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(myUnavailabilityProvider(widget.teamId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xxxl * 2,
              ),
              children: [
                Text(
                  'Marque os dias em que você não pode ser escalado. Quem monta '
                  'a escala vê esse aviso na hora de escalar.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (upcoming.isEmpty)
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.4,
                    child: const AppEmptyState(
                      icon: Icons.event_available_outlined,
                      title: 'Disponível em todos os dias',
                      message:
                          'Você não marcou nenhum dia. Toque em "Escolher dias" '
                          'se precisar avisar sobre alguma ausência.',
                    ),
                  )
                else
                  for (final item in upcoming)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _UnavailabilityTile(
                        item: item,
                        onRemove: () => _remove(item),
                      ),
                    ),
              ],
            ),
          );
        },
        ),
      ),
    );
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

class _UnavailabilityTile extends StatelessWidget {
  const _UnavailabilityTile({required this.item, required this.onRemove});

  final Unavailability item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = capitalizeWeekday(
      DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(item.date),
    );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(
              Icons.event_busy_rounded,
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                if (item.reason?.isNotEmpty ?? false)
                  Text(
                    item.reason!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remover',
            icon: const Icon(Icons.close_rounded),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
