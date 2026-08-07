import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/form_scaffold.dart';
import '../../../shared/widgets/quarter_hour_picker.dart';
import '../../team/data/team_repository.dart';
import '../../team/domain/service_template.dart';
import '../data/event_repository.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';

/// Um culto sendo montado no formulário.
///
/// `templateId` guarda de qual linha da grade ele veio — é o que permite, mais
/// tarde, saber quais escalas uma mudança da grade afetaria. Nulo em culto
/// avulso (Páscoa, especial).
class _ServiceDraft {
  _ServiceDraft({
    required this.label,
    required this.time,
    this.templateId,
  });

  String label;
  TimeOfDay time;
  final String? templateId;

  String get timeLabel =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.eventId});

  final String? eventId;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  final _colorPalette = TextEditingController();

  /// O dia da escala. Manhã e noite são o mesmo domingo, então a data é uma só
  /// e cada culto contribui apenas com o horário.
  late DateTime _date;

  List<_ServiceDraft> _services = [];
  DateTime? _rehearsalAt;

  /// A grade só semeia os cultos uma vez, e só numa escala nova: em edição, os
  /// horários que valem são os que já foram salvos.
  bool _seededFromTemplates = false;
  bool _populated = false;
  bool _loading = false;
  String? _error;

  bool get _isEditing => widget.eventId != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    _colorPalette.dispose();
    super.dispose();
  }

  void _populate(Event event) {
    if (_populated) return;

    _populated = true;
    _seededFromTemplates = true;
    _title.text = event.title ?? '';
    _location.text = event.location ?? '';
    _notes.text = event.notes ?? '';
    _colorPalette.text = event.colorPalette ?? '';

    final timezone = _timezone(event.timezone);
    final start = eventLocalTime(event.startsAt, timezone);
    _date = DateTime(start.year, start.month, start.day);
    _services = [
      for (final service in event.displayServices)
        _ServiceDraft(
          label: service.label,
          time: TimeOfDay.fromDateTime(
            eventLocalTime(service.startsAt, timezone),
          ),
        ),
    ];
    _rehearsalAt = event.rehearsalAt == null
        ? null
        : eventLocalTime(event.rehearsalAt!, timezone);
  }

  /// Preenche os cultos a partir da grade da igreja, para a data escolhida.
  void _seedFromTemplates(List<ServiceTemplate> templates) {
    if (_seededFromTemplates) return;
    _seededFromTemplates = true;
    _services = _templatesForDate(templates, _date);
  }

  List<_ServiceDraft> _templatesForDate(
    List<ServiceTemplate> templates,
    DateTime date,
  ) {
    final matching = templates.where((t) => t.matchesDate(date)).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return [
      for (final template in matching)
        _ServiceDraft(
          label: template.label,
          time: template.timeOfDay,
          templateId: template.id,
        ),
    ];
  }

  String _timezone(String value) => value.isEmpty ? 'America/Sao_Paulo' : value;

  Future<void> _pickDate(List<ServiceTemplate> templates) async {
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;

    final newDate = DateTime(selected.year, selected.month, selected.day);
    final suggestion = _templatesForDate(templates, newDate);

    // Trocar a data troca o dia da semana, e a grade do novo dia é outra. Só
    // sugerimos quando há grade para o dia -- e só quando a lista atual ainda
    // é a sugestão anterior, para não descartar horário digitado à mão.
    final replaceable = suggestion.isNotEmpty &&
        (_services.isEmpty || _services.every((s) => s.templateId != null));

    setState(() {
      _date = newDate;
      if (replaceable) _services = suggestion;
      if (_rehearsalAt != null) {
        _rehearsalAt = DateTime(
          newDate.year,
          newDate.month,
          newDate.day,
          _rehearsalAt!.hour,
          _rehearsalAt!.minute,
        );
      }
    });
  }

  Future<void> _pickServiceTime(int index) async {
    final selected = await showQuarterHourPicker(
      context: context,
      initialTime: _services[index].time,
      title: 'Horario de ${_services[index].label}',
    );
    if (selected == null || !mounted) return;
    setState(() => _services[index].time = selected);
  }

  Future<void> _addService() async {
    final draft = await showModalBottomSheet<_ServiceDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ExtraServiceSheet(),
    );
    if (draft == null || !mounted) return;
    setState(() {
      _services = [..._services, draft]
        ..sort((a, b) => _minutes(a.time).compareTo(_minutes(b.time)));
    });
  }

  static int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

  Future<void> _pickRehearsal() async {
    final current = _rehearsalAt ?? _date;
    final date = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showQuarterHourPicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      title: 'Horario do ensaio',
    );
    if (time == null || !mounted) return;

    setState(() {
      _rehearsalAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  DateTime _toUtc(DateTime dateTime, String timezone) {
    final location = tz.getLocation(timezone);
    return tz.TZDateTime(
      location,
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
    ).toUtc();
  }

  List<Map<String, String?>> _servicePayload(String timezone) {
    return [
      for (final service in _services)
        {
          'label': service.label,
          'startsAt': _toUtc(
            DateTime(
              _date.year,
              _date.month,
              _date.day,
              service.time.hour,
              service.time.minute,
            ),
            timezone,
          ).toIso8601String(),
          if (service.templateId != null) 'templateId': service.templateId,
        },
    ];
  }

  Future<String> _createTimezone(String teamId) async {
    final team = await ref.read(teamRepositoryProvider).find(teamId);
    return _timezone(team.timezone);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_services.isEmpty) {
      setState(() => _error = 'Escolha pelo menos um culto para esta escala.');
      return;
    }

    final activeTeamId = ref.read(activeTeamIdProvider);
    if (!_isEditing && activeTeamId == null) {
      setState(() => _error = 'Nenhuma equipe ativa foi encontrada.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cached = _isEditing
          ? await ref.read(eventRepositoryProvider).find(widget.eventId!)
          : null;
      final event = cached?.data;
      final timezone = event == null
          ? await _createTimezone(activeTeamId!)
          : _timezone(event.timezone);

      final services = _servicePayload(timezone);
      final rehearsalAt = _rehearsalAt == null
          ? null
          : _toUtc(_rehearsalAt!, timezone).toIso8601String();
      final repository = ref.read(eventRepositoryProvider);

      if (event != null) {
        await repository.update(
          event.id,
          title: _title.text.trim(),
          services: services,
          rehearsalAt: rehearsalAt,
          removeRehearsalAt: _rehearsalAt == null,
          location: _location.text.trim(),
          notes: _notes.text.trim(),
          colorPalette: _colorPalette.text.trim(),
        );
        ref.invalidate(eventsProvider((event.teamId, 'upcoming')));
        ref.invalidate(eventsProvider((event.teamId, 'past')));
        ref.invalidate(eventProvider(event.id));
      } else {
        final createdEvent = await repository.create(
          activeTeamId!,
          title: _title.text.trim(),
          services: services,
          rehearsalAt: rehearsalAt,
          location: _location.text.trim(),
          notes: _notes.text.trim(),
          colorPalette: _colorPalette.text.trim(),
        );
        ref.invalidate(eventsProvider((createdEvent.teamId, 'upcoming')));
        ref.invalidate(eventsProvider((createdEvent.teamId, 'past')));
        ref.invalidate(eventProvider(createdEvent.id));
      }

      if (mounted) context.pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync =
        _isEditing ? ref.watch(eventProvider(widget.eventId!)) : null;

    if (eventAsync != null && eventAsync.isLoading) {
      return const Scaffold(body: AppLoading());
    }

    if (eventAsync != null && eventAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Culto')),
        body: AppErrorState(
          message: 'Não foi possível carregar a escala.',
          onRetry: () => ref.invalidate(eventProvider(widget.eventId!)),
        ),
      );
    }

    final event = eventAsync?.valueOrNull?.data;
    if (event != null) _populate(event);

    final teamId = ref.watch(activeTeamIdProvider);
    final templatesAsync = teamId == null
        ? const AsyncValue<List<ServiceTemplate>>.data([])
        : ref.watch(serviceTemplatesProvider(teamId));
    final templates = templatesAsync.valueOrNull ?? const <ServiceTemplate>[];

    // A grade só entra em escala nova; em edição valem os horários salvos.
    if (!_isEditing && templatesAsync.hasValue) _seedFromTemplates(templates);

    return FormScaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar escala' : 'Nova escala'),
      ),
      title: _isEditing ? 'Editar escala' : 'Nova escala',
      subtitle: 'Escolha o dia e os cultos desta escala.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Opcional e sem validação: o domingo comum não precisa de nome,
              // e exigir um produzia "Domingo" ao lado de um selo que já dizia
              // DOM 9 AGO. Só culto especial tem o que nomear.
              TextFormField(
                controller: _title,
                enabled: !_loading,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Título (opcional)',
                  hintText: 'Páscoa, Ceia, Batismo...',
                  helperText: 'Deixe vazio no culto comum.',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Dia', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              _DateButton(
                date: _date,
                enabled: !_loading,
                onPressed: () => _pickDate(templates),
              ),
              const SizedBox(height: AppSpacing.xl),
              _ServicesSection(
                services: _services,
                templates: templates,
                date: _date,
                loadingTemplates: templatesAsync.isLoading,
                enabled: !_loading,
                onPickTime: _pickServiceTime,
                onRemove: (index) =>
                    setState(() => _services = [..._services]..removeAt(index)),
                onAdd: _addService,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ensaio (opcional)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (_rehearsalAt != null)
                    IconButton(
                      tooltip: 'Limpar ensaio',
                      onPressed: _loading
                          ? null
                          : () => setState(() => _rehearsalAt = null),
                      icon: const Icon(Icons.clear),
                    ),
                ],
              ),
              if (_rehearsalAt == null)
                OutlinedButton.icon(
                  onPressed: _loading ? null : _pickRehearsal,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar ensaio'),
                )
              else
                OutlinedButton.icon(
                  onPressed: _loading ? null : _pickRehearsal,
                  icon: const Icon(Icons.schedule_outlined, size: 18),
                  label: Text(
                    DateFormat("d 'de' MMMM 'às' HH:mm", 'pt_BR')
                        .format(_rehearsalAt!),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _location,
                enabled: !_loading,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration:
                    const InputDecoration(labelText: 'Local (opcional)'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _notes,
                enabled: !_loading,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 5,
                decoration:
                    const InputDecoration(labelText: 'Observações (opcional)'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _colorPalette,
                enabled: !_loading,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Paleta de cores (opcional)',
                  hintText: 'Preto e dourado',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (_error != null) FormErrorBanner(message: _error!),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Salvar' : 'Criar escala'),
        ),
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.date,
    required this.enabled,
    required this.onPressed,
  });

  final DateTime date;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 18),
          const SizedBox(width: AppSpacing.sm),
          // `scaleDown` em vez de quebrar: num Galaxy S23 com a fonte do
          // sistema aumentada, o ano ia para a linha de baixo.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                capitalizeWeekday(
                  DateFormat("EEEE, d 'de' MMMM 'de' y", 'pt_BR').format(date),
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Os cultos desta escala.
///
/// Vêm marcados a partir da grade da igreja: escolhida a data, os cultos
/// daquele dia da semana já estão aqui. Dá para desmarcar (domingo sem culto
/// de manhã acontece) e acrescentar um avulso (Páscoa, especial).
class _ServicesSection extends StatelessWidget {
  const _ServicesSection({
    required this.services,
    required this.templates,
    required this.date,
    required this.loadingTemplates,
    required this.enabled,
    required this.onPickTime,
    required this.onRemove,
    required this.onAdd,
  });

  final List<_ServiceDraft> services;
  final List<ServiceTemplate> templates;
  final DateTime date;
  final bool loadingTemplates;
  final bool enabled;
  final ValueChanged<int> onPickTime;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasGradeForDay =
        templates.any((t) => t.matchesDate(date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Cultos', style: theme.textTheme.titleMedium),
            ),
            if (services.isNotEmpty)
              Text(
                services.length == 1 ? '1 culto' : '${services.length} cultos',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          hasGradeForDay
              ? 'Vieram da grade da igreja. Desmarque o que não vai ter.'
              : 'Não há grade para este dia da semana. Adicione o horário.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (loadingTemplates)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          )
        else if (services.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(
              'Nenhum culto nesta escala.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (var i = 0; i < services.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ServiceRow(
                service: services[i],
                enabled: enabled,
                onPickTime: () => onPickTime(i),
                onRemove: () => onRemove(i),
              ),
            ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: enabled ? onAdd : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Adicionar culto'),
          ),
        ),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.enabled,
    required this.onPickTime,
    required this.onRemove,
  });

  final _ServiceDraft service;
  final bool enabled;
  final VoidCallback onPickTime;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.church_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              service.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          TextButton(
            onPressed: enabled ? onPickTime : null,
            child: Text(service.timeLabel),
          ),
          IconButton(
            tooltip: 'Remover culto',
            visualDensity: VisualDensity.compact,
            onPressed: enabled ? onRemove : null,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Culto fora da grade: Páscoa, vigília, culto especial.
class _ExtraServiceSheet extends StatefulWidget {
  const _ExtraServiceSheet();

  @override
  State<_ExtraServiceSheet> createState() => _ExtraServiceSheetState();
}

class _ExtraServiceSheetState extends State<_ExtraServiceSheet> {
  final _label = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 19, minute: 0);
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
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
            Text('Adicionar culto', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Para um culto que não está na grade da igreja.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _label,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome',
                hintText: 'Vigília, Especial...',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showQuarterHourPicker(
                  context: context,
                  initialTime: _time,
                  title: 'Horario do culto',
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
            FilledButton(
              onPressed: () {
                final label = _label.text.trim();
                if (label.isEmpty) {
                  setState(() => _error = 'Informe o nome do culto.');
                  return;
                }
                Navigator.of(context).pop(
                  _ServiceDraft(label: label, time: _time),
                );
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }
}
