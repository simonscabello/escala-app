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
import '../data/event_repository.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';

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

  late DateTime _startsAt;
  DateTime? _rehearsalAt;
  bool _populated = false;
  bool _loading = false;
  String? _error;

  bool get _isEditing => widget.eventId != null;

  @override
  void initState() {
    super.initState();
    _startsAt = DateTime.now();
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
    _title.text = event.title;
    _location.text = event.location ?? '';
    _notes.text = event.notes ?? '';
    _colorPalette.text = event.colorPalette ?? '';
    _startsAt = eventLocalTime(event.startsAt, _timezone(event.timezone));
    _rehearsalAt = event.rehearsalAt == null
        ? null
        : eventLocalTime(event.rehearsalAt!, _timezone(event.timezone));
  }

  String _timezone(String value) {
    if (value.isEmpty) return 'America/Sao_Paulo';
    return value;
  }

  Future<void> _pickDate({required bool rehearsal}) async {
    final current = rehearsal ? _rehearsalAt ?? _startsAt : _startsAt;
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;

    setState(() {
      final updated = DateTime(
        selected.year,
        selected.month,
        selected.day,
        current.hour,
        current.minute,
      );
      if (rehearsal) {
        _rehearsalAt = updated;
        return;
      }
      _startsAt = updated;
    });
  }

  Future<void> _pickTime({required bool rehearsal}) async {
    final current = rehearsal ? _rehearsalAt ?? _startsAt : _startsAt;
    final selected = await showQuarterHourPicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      title: rehearsal ? 'Horario do ensaio' : 'Horario do culto',
    );
    if (selected == null || !mounted) return;

    setState(() {
      final updated = DateTime(
        current.year,
        current.month,
        current.day,
        selected.hour,
        selected.minute,
      );
      if (rehearsal) {
        _rehearsalAt = updated;
        return;
      }
      _startsAt = updated;
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

  Future<String> _createTimezone(String teamId) async {
    final team = await ref.read(teamRepositoryProvider).find(teamId);
    return _timezone(team.timezone);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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
      final startsAt = _toUtc(_startsAt, timezone).toIso8601String();
      final rehearsalAt = _rehearsalAt == null
          ? null
          : _toUtc(_rehearsalAt!, timezone).toIso8601String();
      final repository = ref.read(eventRepositoryProvider);

      if (event != null) {
        await repository.update(
          event.id,
          title: _title.text.trim(),
          startsAt: startsAt,
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
          startsAt: startsAt,
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

    return FormScaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar escala' : 'Nova escala'),
      ),
      title: _isEditing ? 'Editar escala' : 'Nova escala',
      subtitle: 'Informe os horários e os detalhes da escala.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _title,
                enabled: !_loading,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Título da escala'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe o título da escala.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Culto', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              _DateTimeFields(
                dateTime: _startsAt,
                enabled: !_loading,
                onPickDate: () => _pickDate(rehearsal: false),
                onPickTime: () => _pickTime(rehearsal: false),
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
                  onPressed: _loading
                      ? null
                      : () => setState(() => _rehearsalAt = _startsAt),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar ensaio'),
                )
              else
                _DateTimeFields(
                  dateTime: _rehearsalAt!,
                  enabled: !_loading,
                  onPickDate: () => _pickDate(rehearsal: true),
                  onPickTime: () => _pickTime(rehearsal: true),
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

class _DateTimeFields extends StatelessWidget {
  const _DateTimeFields({
    required this.dateTime,
    required this.enabled,
    required this.onPickDate,
    required this.onPickTime,
  });

  final DateTime dateTime;
  final bool enabled;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // A data ganha mais espaco que a hora: "06/08/2026" tem o dobro dos
        // caracteres de "09:00". Com os dois botoes em metades iguais, num
        // Galaxy S23 com a fonte do sistema aumentada o ano quebrava para a
        // linha de baixo.
        Expanded(
          flex: 3,
          child: _PickerButton(
            enabled: enabled,
            onPressed: onPickDate,
            icon: Icons.calendar_today_outlined,
            label: DateFormat('dd/MM/yyyy', 'pt_BR').format(dateTime),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: _PickerButton(
            enabled: enabled,
            onPressed: onPickTime,
            icon: Icons.schedule_outlined,
            label: DateFormat('HH:mm', 'pt_BR').format(dateTime),
          ),
        ),
      ],
    );
  }
}

/// Botao de data/hora que encolhe o texto em vez de quebrar a linha.
class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.enabled,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.sm),
          // `scaleDown` so age quando falta espaco -- em tela larga o texto
          // fica no tamanho normal. `softWrap: false` garante que a saida seja
          // encolher, e nao quebrar.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label, maxLines: 1, softWrap: false),
            ),
          ),
        ],
      ),
    );
  }
}
