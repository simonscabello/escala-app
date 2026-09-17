import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/responsive/adaptive_dialog.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_date_badge.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_group.dart';
import '../../../shared/widgets/app_pressable.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/app_submit_button.dart';
import '../../events/domain/event_datetime.dart';
import '../../team/data/team_repository.dart';
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

    // A grade da igreja, se ela já chegou: marca no calendário os dias em que
    // há culto. Sem ela o calendário funciona igual, só sem a marca.
    final templates =
        ref.read(serviceTemplatesProvider(widget.teamId)).valueOrNull;

    final result = await showMultiDatePicker(
      context: context,
      initialSelection: existing.keys.toSet(),
      isServiceDay: templates == null || templates.isEmpty
          ? null
          : (day) => templates.any((t) => t.matchesDate(day)),
    );

    if (result == null || !mounted) return;

    final added = result.dates.difference(existing.keys.toSet()).toList()
      ..sort();
    final removedIds = [
      for (final entry in existing.entries)
        if (!result.dates.contains(entry.key)) entry.value,
    ];

    if (added.isEmpty && removedIds.isEmpty) return;

    setState(() => _saving = true);
    try {
      final repository = ref.read(unavailabilityRepositoryProvider);

      for (final id in removedIds) {
        await repository.remove(widget.teamId, id);
      }
      if (added.isNotEmpty) {
        await repository.add(
          widget.teamId,
          dates: added,
          reason: result.reason,
        );
      }

      ref.invalidate(myUnavailabilityProvider(widget.teamId));

      if (mounted) {
        showAppSnackBar(
          context,
          added.isEmpty
              ? 'Dias atualizados. A equipe já vê.'
              : added.length == 1
                  ? 'Aviso enviado para 1 dia.'
                  : 'Aviso enviado para ${added.length} dias.',
          tone: AppTone.success,
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, tone: AppTone.danger);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Corrige o motivo de **um** dia. Folha, e não diálogo: é um formulário
  /// curto, e os formulários curtos do app sobem do rodapé.
  Future<void> _editReason(Unavailability item) async {
    final reason = await showAdaptiveSheet<String>(
      context: context,
      maxWidth: 440,
      builder: (_) => _ReasonSheet(initial: item.reason ?? ''),
    );
    if (reason == null || !mounted) return;
    if (reason == (item.reason ?? '')) return;

    try {
      await ref.read(unavailabilityRepositoryProvider).updateReason(
            widget.teamId,
            item.id,
            reason: reason,
          );
      ref.invalidate(myUnavailabilityProvider(widget.teamId));
      if (mounted) {
        showAppSnackBar(
          context,
          reason.isEmpty
              ? 'Motivo apagado. O dia continua marcado.'
              : 'Motivo atualizado. A equipe já vê.',
          tone: AppTone.success,
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, tone: AppTone.danger);
      }
    }
  }

  /// Tirar um dia, com volta. O toque é pequeno e fica ao lado da linha que
  /// abre o motivo: errar o alvo apagava o aviso sem jeito de desfazer.
  Future<void> _remove(Unavailability item) async {
    final repository = ref.read(unavailabilityRepositoryProvider);
    try {
      await repository.remove(widget.teamId, item.id);
      ref.invalidate(myUnavailabilityProvider(widget.teamId));
      if (mounted) {
        showAppSnackBar(
          context,
          'Você voltou a ficar disponível nesse dia.',
          tone: AppTone.success,
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () async {
              try {
                await repository.add(
                  widget.teamId,
                  dates: [item.date],
                  reason: item.reason,
                );
                ref.invalidate(myUnavailabilityProvider(widget.teamId));
              } on ApiException catch (error) {
                if (mounted) {
                  showAppSnackBar(
                    context,
                    error.message,
                    tone: AppTone.danger,
                  );
                }
              }
            },
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, tone: AppTone.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = ref.watch(myUnavailabilityProvider(widget.teamId));
    // Observada aqui para já ter chegado quando a pessoa abrir o calendário.
    ref.watch(serviceTemplatesProvider(widget.teamId));

    final upcoming = items.valueOrNull
            ?.where((i) => !i.date.isBefore(_today))
            .toList(growable: false) ??
        const <Unavailability>[];

    void openPicker() => _editDays(
          ref.read(myUnavailabilityProvider(widget.teamId)).value ?? const [],
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Minha disponibilidade')),
      // Sem dia marcado, a ação mora no próprio vazio: dois botões para a
      // mesma coisa na mesma tela seria um a mais.
      floatingActionButton: items.hasValue && upcoming.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : openPicker,
              icon: const Icon(Icons.edit_calendar_rounded),
              label: const Text('Escolher dias'),
            )
          : null,
      body: SafeArea(
        top: false,
        child: AppContentWidth.reading(
          child: items.when(
            loading: () =>
                const AppListSkeleton(itemCount: 3, leadingBlock: true),
            error: (error, _) => AppErrorState(
              message: error is ApiException
                  ? error.message
                  : 'Não foi possível carregar seus dias.',
              onRetry: () =>
                  ref.invalidate(myUnavailabilityProvider(widget.teamId)),
            ),
            data: (_) => RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(myUnavailabilityProvider(widget.teamId)),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.lg,
                  AppSpacing.screenPadding,
                  AppSpacing.fabClearance,
                ),
                children: [
                  Text(
                    'Marque os dias em que você não pode ser escalado. Quem '
                    'monta a escala vê esse aviso na hora de escalar.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (upcoming.isEmpty)
                    AppCard(
                      surface: CardSurface.sunken,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            size: 32,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Disponível em todos os dias',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Você não marcou nenhum dia.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton.icon(
                            onPressed: _saving ? null : openPicker,
                            icon: const Icon(
                              Icons.edit_calendar_rounded,
                              size: 18,
                            ),
                            label: const Text('Escolher dias'),
                          ),
                        ],
                      ),
                    )
                  else
                    // Uma superfície para os dias, com o bloco de data da
                    // agenda: era um cartão com borda por dia, uma pilha de
                    // caixinhas para uma lista só.
                    AppGroup(
                      dividerIndent: AppSpacing.lg + 54 + AppSpacing.md,
                      children: [
                        for (final item in upcoming)
                          _UnavailabilityRow(
                            item: item,
                            onEditReason: () => _editReason(item),
                            onRemove: () => _remove(item),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

class _UnavailabilityRow extends StatelessWidget {
  const _UnavailabilityRow({
    required this.item,
    required this.onEditReason,
    required this.onRemove,
  });

  final Unavailability item;
  final VoidCallback onEditReason;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final pattern =
        item.date.year == now.year ? "d 'de' MMMM" : "d 'de' MMMM 'de' y";
    final label = DateFormat(pattern, 'pt_BR').format(item.date);
    final weekday = DateFormat('EEE', 'pt_BR')
        .format(item.date)
        .replaceAll('.', '')
        .toUpperCase();
    final reason = item.reason?.isNotEmpty ?? false ? item.reason! : null;

    return AppPressable(
      onTap: onEditReason,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            AppDateBadge(
              weekday: weekday,
              day: '${item.date.day}',
              semanticsLabel: capitalizeWeekday(
                DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(item.date),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleSmall),
                  Text(
                    reason ?? 'Toque para dizer o motivo',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: reason == null ? FontStyle.italic : null,
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
      ),
    );
  }
}

/// O motivo de um dia já marcado, com os mesmos chips do calendário.
class _ReasonSheet extends StatefulWidget {
  const _ReasonSheet({required this.initial});

  final String initial;

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Motivo desse dia', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            UnavailabilityReasonField(controller: _controller, autofocus: true),
            const SizedBox(height: AppSpacing.lg),
            AppSubmitButton(
              label: 'Salvar',
              onPressed: () =>
                  Navigator.of(context).pop(_controller.text.trim()),
            ),
            const SizedBox(height: AppSpacing.xs),
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
