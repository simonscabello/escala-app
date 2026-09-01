import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/app_submit_button.dart';
import '../../../shared/widgets/form_scaffold.dart';
import '../../../shared/widgets/quarter_hour_picker.dart';
import '../../events/data/event_repository.dart';
import '../data/team_repository.dart';
import '../domain/service_template.dart';

/// A grade de cultos da igreja.
///
/// Existe para o líder não digitar rótulo e horário a cada escala. Ele cadastra
/// aqui uma vez ("Domingo 08:30 Manhã", "Domingo 19:00 Noite", "Quinta 19:30")
/// e, na tela de nova escala, escolhe só a data -- os cultos daquele dia da
/// semana já vêm marcados.
class ServiceTemplatesScreen extends ConsumerWidget {
  const ServiceTemplatesScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(serviceTemplatesProvider(teamId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cultos da igreja'),
        actions: [
          IconButton(
            tooltip: 'Planejar próximas escalas',
            onPressed: templates.valueOrNull?.isNotEmpty == true
                ? () => _openGenerator(context, ref)
                : null,
            icon: const Icon(Icons.event_repeat_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Adicionar'),
      ),
      body: SafeArea(
        top: false,
        child: AppContentWidth(
          child: templates.when(
            loading: () => const AppListSkeleton(itemCount: 4),
            error: (error, _) => AppErrorState(
              message: error is ApiException
                  ? error.message
                  : 'Não foi possível carregar os cultos.',
              onRetry: () => ref.invalidate(serviceTemplatesProvider(teamId)),
            ),
            data: (list) => list.isEmpty
                ? RefreshableMessage(
                    onRefresh: () async =>
                        ref.refresh(serviceTemplatesProvider(teamId).future),
                    child: AppEmptyState(
                      icon: Icons.church_outlined,
                      title: 'Nenhum culto cadastrado',
                      message: 'Cadastre os horários que se repetem toda '
                          'semana. Eles aparecem prontos ao criar uma escala.',
                      actionLabel: 'Adicionar culto',
                      onAction: () => _openEditor(context, ref),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async =>
                        ref.refresh(serviceTemplatesProvider(teamId).future),
                    child: _TemplateList(
                      teamId: teamId,
                      templates: list,
                      onEdit: (t) => _openEditor(context, ref, template: t),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    ServiceTemplate? template,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TemplateEditorSheet(teamId: teamId, template: template),
    );
    if (saved == true) ref.invalidate(serviceTemplatesProvider(teamId));
  }

  Future<void> _openGenerator(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<GeneratedSchedules>(
      context: context,
      builder: (_) => _GenerateSchedulesDialog(teamId: teamId),
    );
    if (result == null || !context.mounted) return;

    ref.invalidate(eventsProvider((teamId, 'upcoming')));
    final message = result.createdCount == 0
        ? 'As próximas datas já tinham escala.'
        : '${result.createdCount} '
            '${result.createdCount == 1 ? 'rascunho criado' : 'rascunhos criados'}.';
    showAppSnackBar(context, message, tone: AppTone.success);
  }
}

class _GenerateSchedulesDialog extends ConsumerStatefulWidget {
  const _GenerateSchedulesDialog({required this.teamId});

  final String teamId;

  @override
  ConsumerState<_GenerateSchedulesDialog> createState() =>
      _GenerateSchedulesDialogState();
}

class _GenerateSchedulesDialogState
    extends ConsumerState<_GenerateSchedulesDialog> {
  int _weeks = 4;
  bool _saving = false;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(eventRepositoryProvider)
          .generate(widget.teamId, weeks: _weeks);
      if (mounted) Navigator.of(context).pop(result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Planejar próximas escalas'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cria rascunhos usando os dias e horários desta grade. Datas que '
            'já têm escala são mantidas como estão.',
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<int>(
            initialValue: _weeks,
            decoration: const InputDecoration(labelText: 'Período'),
            items: const [
              DropdownMenuItem(value: 4, child: Text('Próximas 4 semanas')),
              DropdownMenuItem(value: 8, child: Text('Próximas 8 semanas')),
              DropdownMenuItem(value: 12, child: Text('Próximas 12 semanas')),
            ],
            onChanged:
                _saving ? null : (value) => setState(() => _weeks = value ?? 4),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            FormErrorBanner(message: _error!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _generate,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Criar rascunhos'),
        ),
      ],
    );
  }
}

class _TemplateList extends ConsumerWidget {
  const _TemplateList({
    required this.teamId,
    required this.templates,
    required this.onEdit,
  });

  final String teamId;
  final List<ServiceTemplate> templates;
  final ValueChanged<ServiceTemplate> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Agrupado por dia da semana: é assim que se pensa a semana da igreja, e
    // uma lista corrida de sete horários não deixa ver que domingo tem dois.
    final byWeekday = <int, List<ServiceTemplate>>{};
    for (final template in templates) {
      byWeekday.putIfAbsent(template.weekday, () => []).add(template);
    }
    final weekdays = byWeekday.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        96,
      ),
      children: [
        Text(
          'Os horários que se repetem toda semana. Ao criar uma escala, você '
          'escolhe a data e os cultos do dia já vêm marcados.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final weekday in weekdays) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              weekdayName(weekday),
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                for (var i = 0; i < byWeekday[weekday]!.length; i++) ...[
                  if (i > 0) Divider(color: scheme.outlineVariant, height: 1),
                  _TemplateRow(
                    teamId: teamId,
                    template: byWeekday[weekday]![i],
                    onEdit: () => onEdit(byWeekday[weekday]![i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _TemplateRow extends ConsumerWidget {
  const _TemplateRow({
    required this.teamId,
    required this.template,
    required this.onEdit,
  });

  final String teamId;
  final ServiceTemplate template;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onEdit,
      // A hora como texto, e não dentro de um bloco azul. Era o mesmo ladrilho
      // tingido que saiu das outras telas — e aqui ele era pior: pintava de
      // azul-marca uma informação puramente factual, repetida em toda linha da
      // grade. Em algarismos tabulares as horas caem na mesma vertical, que é o
      // que se quer numa grade semanal.
      leading: SizedBox(
        width: 58,
        child: Text(
          template.timeLabel,
          style: AppTypography.time(context),
        ),
      ),
      title: Text(template.label, style: theme.textTheme.titleSmall),
      trailing: IconButton(
        tooltip: 'Remover ${template.label}',
        icon: Icon(
          Icons.delete_outline_rounded,
          color: scheme.onSurfaceVariant,
        ),
        onPressed: () => _confirmRemove(context, ref),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remover ${template.label}?',
      message: 'Sai da grade de '
          '${weekdayName(template.weekday).toLowerCase()}. As escalas já '
          'montadas continuam com o horário que têm hoje.',
      confirmLabel: 'Remover',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref
          .read(teamRepositoryProvider)
          .removeServiceTemplate(teamId, template.id);
      ref.invalidate(serviceTemplatesProvider(teamId));
      if (context.mounted) {
        showAppSnackBar(
          context,
          '${template.label} saiu da grade.',
          tone: AppTone.success,
        );
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, error.message, tone: AppTone.danger);
      }
    }
  }
}

/// Folha de cadastro/edição de um culto da grade.
class _TemplateEditorSheet extends ConsumerStatefulWidget {
  const _TemplateEditorSheet({required this.teamId, this.template});

  final String teamId;
  final ServiceTemplate? template;

  @override
  ConsumerState<_TemplateEditorSheet> createState() =>
      _TemplateEditorSheetState();
}

class _TemplateEditorSheetState extends ConsumerState<_TemplateEditorSheet> {
  late final TextEditingController _label =
      TextEditingController(text: widget.template?.label ?? '');
  late int _weekday = widget.template?.weekday ?? 0;
  late TimeOfDay _time =
      widget.template?.timeOfDay ?? const TimeOfDay(hour: 19, minute: 0);

  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.template != null;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  int get _startMinutes => _time.hour * 60 + _time.minute;

  Future<void> _save() async {
    final label = _label.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Informe o nome do culto.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repository = ref.read(teamRepositoryProvider);

      if (!_isEditing) {
        await repository.addServiceTemplate(
          widget.teamId,
          label: label,
          weekday: _weekday,
          startMinutes: _startMinutes,
        );
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      final template = widget.template!;
      final changedTime = template.startMinutes != _startMinutes;
      final changedLabel = template.label != label;

      // Só pergunta sobre escalas futuras quando alguma delas realmente
      // mudaria. Trocar o dia da semana não mexe em escala já montada -- isso
      // vale para as próximas.
      var applyToFuture = false;
      if (changedTime || changedLabel) {
        final affected = await repository.serviceTemplateFutureEvents(
          widget.teamId,
          template.id,
        );
        if (affected.isNotEmpty) {
          if (!mounted) return;
          final answer = await _askApplyToFuture(affected.length);
          if (answer == null) {
            setState(() => _saving = false);
            return;
          }
          applyToFuture = answer;
        }
      }

      await repository.updateServiceTemplate(
        widget.teamId,
        template.id,
        label: label,
        weekday: _weekday,
        startMinutes: _startMinutes,
        applyToFutureEvents: applyToFuture,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// `null` = desistiu de salvar.
  Future<bool?> _askApplyToFuture(int count) {
    final plural = count == 1 ? 'escala futura usa' : 'escalas futuras usam';
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Atualizar escalas futuras?'),
        content: Text(
          '$count $plural este culto. Quer que elas passem a usar o horário e '
          'o nome novos?\n\n'
          'A data de cada escala não muda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Só as próximas'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
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
            Text(
              _isEditing ? 'Editar culto' : 'Novo culto',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _label,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome',
                hintText: 'Manhã, Noite, Quinta...',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Dia da semana', style: theme.textTheme.titleSmall),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (var day = 0; day < 7; day++)
                  ChoiceChip(
                    label: Text(weekdayName(day).substring(0, 3)),
                    selected: _weekday == day,
                    onSelected:
                        _saving ? null : (_) => setState(() => _weekday = day),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      final picked = await showQuarterHourPicker(
                        context: context,
                        initialTime: _time,
                        title: 'Horário do culto',
                      );
                      if (picked != null) setState(() => _time = picked);
                    },
              icon: const Icon(Icons.schedule_outlined, size: 18),
              label: Text(
                '${_time.hour.toString().padLeft(2, '0')}:'
                '${_time.minute.toString().padLeft(2, '0')}',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppSubmitButton(
              label: 'Salvar',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
