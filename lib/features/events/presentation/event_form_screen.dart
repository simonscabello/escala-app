import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_choice_bar.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/app_submit_button.dart';
import '../../../shared/widgets/form_scaffold.dart';
import '../../../shared/widgets/quarter_hour_picker.dart';
import '../../../shared/widgets/section_header.dart';
import '../../team/data/team_repository.dart';
import '../../team/domain/service_template.dart';
import '../data/event_repository.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';
import '../domain/next_service_date.dart';
import 'schedule_changed_dialog.dart';

/// Um culto sendo montado no formulário.
///
/// `templateId` guarda de qual linha da grade ele veio — é o que permite, mais
/// tarde, saber quais escalas uma mudança da grade afetaria. Nulo em culto
/// avulso (Páscoa, especial).
class _ServiceDraft {
  _ServiceDraft({
    required this.label,
    required this.time,
    this.id,
    this.templateId,
  });

  /// O culto que já está gravado, quando este rascunho veio de uma escala
  /// existente. Nulo em culto novo.
  ///
  /// É o que o servidor usa para saber que mudar o horário da noite é editar
  /// aquele culto, e não trocá-lo por outro: sem o id ele recriaria a linha, e
  /// o repertório da noite iria junto.
  final String? id;

  String label;
  TimeOfDay time;
  final String? templateId;

  String get timeLabel =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.eventId, this.initialDate});

  final String? eventId;

  /// Dia já escolhido em outra tela — hoje, o calendário de indisponibilidade
  /// e as datas em aberto da agenda. Quem chega dali já decidiu a data; repetir
  /// a escolha seria pedir duas vezes a mesma coisa, e é onde se erra o
  /// domingo.
  ///
  /// Nulo é "ninguém decidiu ainda": aí a grade da equipe decide, em
  /// [nextScheduledDate].
  final DateTime? initialDate;

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

  /// Ver [RepertoireMode]. Planejado é o padrão porque é o domingo comum -- e
  /// porque é o que toda escala já gravada é.
  RepertoireMode _repertoireMode = RepertoireMode.planned;

  /// Título, local e observações começam recolhidos.
  ///
  /// **Os três juntos aparecem em menos de uma escala em dez.** O título era o
  /// primeiro campo da tela, e a primeira coisa que se lia ao criar a escala de
  /// domingo era um pedido para nomear um domingo -- que não tem nome. Em
  /// edição a seção abre sozinha quando algum deles está preenchido: escondê-lo
  /// esconderia o que já foi escrito.
  bool _extrasExpanded = false;

  /// A grade só semeia os cultos uma vez, e só numa escala nova: em edição, os
  /// horários que valem são os que já foram salvos.
  bool _seededFromTemplates = false;
  bool _populated = false;
  bool _loading = false;
  String? _error;

  /// Versão da escala no momento em que esta tela a abriu. Vai junto ao salvar
  /// para o servidor recusar a gravação se outra pessoa mexeu no meio.
  DateTime? _expectedUpdatedAt;

  bool get _isEditing => widget.eventId != null;

  @override
  void initState() {
    super.initState();
    final start = widget.initialDate ?? DateTime.now();
    _date = DateTime(start.year, start.month, start.day);
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
    _expectedUpdatedAt = event.updatedAt;
    _title.text = event.title ?? '';
    _location.text = event.location ?? '';
    _notes.text = event.notes ?? '';
    _colorPalette.text = event.colorPalette ?? '';
    _repertoireMode = event.repertoireMode;
    _extrasExpanded = _title.text.isNotEmpty ||
        _location.text.isNotEmpty ||
        _notes.text.isNotEmpty;

    final timezone = _timezone(event.timezone);
    final start = eventLocalTime(event.startsAt, timezone);
    _date = DateTime(start.year, start.month, start.day);
    // `services`, e não `displayServices`: o fallback para cache antigo inventa
    // um culto usando o id DA ESCALA, e devolver esse id ao servidor faria a
    // edição ser recusada com INVALID_SERVICE. Sem culto gravado, os rascunhos
    // nascem sem id e viram cultos novos.
    final gravados = event.services;
    _services = [
      for (final service in gravados.isEmpty ? event.displayServices : gravados)
        _ServiceDraft(
          id: gravados.isEmpty ? null : service.id,
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

  /// Escolhe o dia e preenche os cultos a partir da grade da igreja.
  ///
  /// **A data vem da grade quando ninguém a escolheu antes.** Abrir sempre em
  /// hoje era abrir quase sempre num dia sem culto: quem cria a escala do
  /// domingo numa quarta-feira via "Não há grade para este dia da semana" e
  /// tinha de ir ao calendário consertar o palpite do app. Chegando de uma
  /// tela que já decidiu a data ([EventFormScreen.initialDate]), a grade não
  /// opina — ali a escolha já foi feita.
  void _seedFromTemplates(List<ServiceTemplate> templates, String timezone) {
    if (_seededFromTemplates) return;
    _seededFromTemplates = true;

    if (widget.initialDate == null) {
      final sugerida = nextScheduledDate(
        templates: templates,
        timezone: timezone,
        now: DateTime.now(),
      );
      // Nulo é grade vazia ou nada na janela: fica o dia de hoje, que é o que
      // esta tela sempre propôs. Nenhuma data é inventada.
      if (sugerida != null) _date = sugerida;
    }

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
      title: 'Horário de ${_services[index].label}',
    );
    if (selected == null || !mounted) return;
    setState(() => _services[index].time = selected);
  }

  /// Tirar um culto da escala apaga o repertório dele junto (a FK é cascade),
  /// e isso não estava dito em lugar nenhum: era um "x" sem aviso.
  Future<void> _removeService(int index) async {
    final service = _services[index];
    final confirmed = await showConfirmDialog(
      context,
      title: 'Tirar ${service.label} desta escala?',
      message: 'O horário sai da escala. Se já houver repertório escolhido '
          'para ele, as músicas saem junto.',
      confirmLabel: 'Tirar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _services = [..._services]..removeAt(index));
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
      title: 'Horário do ensaio',
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
          // Só nos cultos que já existiam: é o que diz ao servidor "edite este"
          // em vez de "troque por um novo".
          if (service.id != null) 'id': service.id,
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

  /// [force] repete a gravação sem a trava de versão: é o "salvar assim mesmo"
  /// de quem viu o aviso de que a escala mudou e decidiu sobrescrever.
  Future<void> _submit({bool force = false}) async {
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
          repertoireMode: _repertoireMode,
          expectedUpdatedAt: force ? null : _expectedUpdatedAt,
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
          repertoireMode: _repertoireMode,
        );
        ref.invalidate(eventsProvider((createdEvent.teamId, 'upcoming')));
        ref.invalidate(eventsProvider((createdEvent.teamId, 'past')));
        ref.invalidate(eventProvider(createdEvent.id));

        if (!mounted) return;
        // Criar a escala não é o fim da tarefa: ela nasce sem ninguém escalado
        // e sem repertório. Em vez de devolver o líder à agenda -- de onde ele
        // teria de achar a escala nova e abrir dois menus --, a criação emenda
        // direto na escalação e, dali, no repertório.
        //
        // **`?novo=1` diz só "esta escala acabou de nascer".** Se o passo
        // seguinte é o repertório ou o detalhe da escala, quem decide é a
        // escalação, olhando o modo que foi gravado agora: com repertório
        // definido na hora não há lista para montar.
        //
        // **Uma chamada de navegação por passo.** A tentativa anterior fazia
        // `go` (para montar agenda → detalhe) e `push` da escalação por cima,
        // no mesmo frame: em go_router as duas disparam análises assíncronas, e
        // o `push` toma como base a configuração de ANTES do `go`. A pilha
        // saía indeterminada e o passo seguinte não avançava. `pushReplacement`
        // troca este formulário -- que já cumpriu seu papel -- pela escalação,
        // e cada etapa faz o mesmo com a próxima.
        context.pushReplacement(
          '/agenda/${createdEvent.id}/escalar?novo=1',
        );
        return;
      }

      if (mounted) context.pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == scheduleChangedCode) {
        await _resolveConflict(error.message);
        return;
      }
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Sobrescrever é escolha da pessoa; conferir é o caminho oferecido primeiro.
  /// Ao voltar, o detalhe recarrega e mostra a escala como ela está agora.
  Future<void> _resolveConflict(String message) async {
    final overwrite = await showScheduleChangedDialog(context, message);
    if (!mounted) return;

    if (overwrite) {
      await _submit(force: true);
      return;
    }
    ref.invalidate(eventProvider(widget.eventId!));
    if (mounted) context.pop();
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

    // O fuso da equipe decide que dia é "hoje" ao propor a data. Observado
    // aqui, e não buscado na hora de semear, porque semear acontece durante o
    // `build` -- e porque a agenda já mantém esta resposta em cache.
    final teamAsync = teamId == null ? null : ref.watch(teamProvider(teamId));

    // A grade só entra em escala nova; em edição valem os horários salvos.
    //
    // A espera é pelas **duas** respostas: semear com o fuso padrão enquanto a
    // equipe carrega proporia o dia errado para uma igreja em outro fuso, e
    // depois nada corrigiria -- a semeadura acontece uma vez só. Equipe que
    // falhou não trava a tela: aí vale o fuso padrão, que é o de quase todas.
    final teamSettled =
        teamAsync == null || teamAsync.hasValue || teamAsync.hasError;
    if (!_isEditing && templatesAsync.hasValue && teamSettled) {
      _seedFromTemplates(
        templates,
        _timezone(teamAsync?.valueOrNull?.timezone ?? ''),
      );
    }

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
              const SectionHeader(
                title: 'Dia',
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
              ),
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
                onRemove: _removeService,
                onAdd: _addService,
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(
                title: 'Ensaio (opcional)',
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                trailing: _rehearsalAt == null
                    ? null
                    : IconButton(
                        tooltip: 'Limpar ensaio',
                        onPressed: _loading
                            ? null
                            : () => setState(() => _rehearsalAt = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
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
              const SizedBox(height: AppSpacing.xl),
              _RepertoireModeSection(
                mode: _repertoireMode,
                enabled: !_loading,
                onChanged: (mode) => setState(() => _repertoireMode = mode),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Fica na tela principal, e não com o título: é combinado da
              // equipe para aquele dia ("todos de preto"), e quem monta a
              // escala precisa vê-lo sem procurar.
              TextFormField(
                controller: _colorPalette,
                enabled: !_loading,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Paleta de roupas (opcional)',
                  hintText: 'Preto e dourado',
                  helperText: 'A combinação de cores que a equipe vai vestir.',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _AdditionalInfoSection(
                expanded: _extrasExpanded,
                onToggle: () =>
                    setState(() => _extrasExpanded = !_extrasExpanded),
                filled: [
                  if (_title.text.trim().isNotEmpty) 'Título',
                  if (_location.text.trim().isNotEmpty) 'Local',
                  if (_notes.text.trim().isNotEmpty) 'Observações',
                ],
                children: [
                  // Opcional e sem validação: o domingo comum não precisa de
                  // nome, e exigir um produzia "Domingo" ao lado de um selo que
                  // já dizia DOM 9 AGO. Só culto especial tem o que nomear.
                  TextFormField(
                    controller: _title,
                    enabled: !_loading,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    // O resumo recolhido conta quais campos têm algo dentro;
                    // sem isto ele só mudaria no próximo `setState` de outra
                    // coisa.
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Título (opcional)',
                      hintText: 'Páscoa, Ceia, Batismo...',
                      helperText: 'Deixe vazio no culto comum.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _location,
                    enabled: !_loading,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
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
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Observações (opcional)',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (_error != null) FormErrorBanner(message: _error!),
        AppSubmitButton(
          label: _isEditing ? 'Salvar' : 'Criar escala',
          loading: _loading,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Como o repertório desta escala vai ser decidido.
///
/// **Da escala, e não de cada culto**: no domingo de manhã e noite quem
/// ministra é a mesma pessoa e o jeito de trabalhar é um só.
///
/// A linha de apoio muda com a escolha porque é ela que diz a consequência --
/// escolher "na hora" desliga toda a cobrança de repertório desta escala, e
/// isso precisa estar dito onde se escolhe, não descoberto depois.
class _RepertoireModeSection extends StatelessWidget {
  const _RepertoireModeSection({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final RepertoireMode mode;
  final bool enabled;
  final ValueChanged<RepertoireMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Repertório',
          subtitle: switch (mode) {
            RepertoireMode.planned =>
              'As músicas são escolhidas antes e vão junto na escala.',
            RepertoireMode.onTheFly =>
              'Quem ministra escolhe no culto. A escala não vai cobrar '
                  'repertório nem avisar que faltam músicas.',
          },
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        ),
        AppChoiceBar<RepertoireMode>(
          value: mode,
          options: const [
            AppChoice(
              value: RepertoireMode.planned,
              label: 'Planejado',
              icon: Icons.queue_music_rounded,
            ),
            AppChoice(
              value: RepertoireMode.onTheFly,
              label: 'Na hora',
              icon: Icons.bolt_rounded,
            ),
          ],
          onChanged: (value) {
            if (!enabled) return;
            onChanged(value);
          },
        ),
      ],
    );
  }
}

/// Título, local e observações — recolhidos até alguém precisar deles.
///
/// Os três são opcionais e raros, e ocupavam um terço da tela de criação: o
/// título abria o formulário pedindo nome para um domingo que não tem nome.
/// Recolhidos, a escala comum cabe numa tela — dia, cultos, repertório — e
/// quem tem uma Páscoa para nomear continua a um toque de distância.
///
/// **O resumo diz o que está guardado dentro.** Uma seção fechada que não
/// mostra sinal do que contém é uma seção que ninguém abre — e aí o local que
/// alguém escreveu semana passada some da vista de quem edita.
class _AdditionalInfoSection extends StatelessWidget {
  const _AdditionalInfoSection({
    required this.expanded,
    required this.onToggle,
    required this.filled,
    required this.children,
  });

  final bool expanded;
  final VoidCallback onToggle;

  /// Os nomes dos campos que já têm conteúdo: "Título", "Local", "Observações".
  final List<String> filled;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final resumo =
        filled.isEmpty ? 'Título, local e observações' : filled.join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informações adicionais',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            resumo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: AppMotion.fast,
                      curve: AppMotion.standard,
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
        ],
      ),
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
        SectionHeader(
          title: 'Cultos',
          subtitle: hasGradeForDay
              ? 'Vieram da grade da igreja. Remova o que não vai ter.'
              : 'Não há grade para este dia da semana. Adicione o horário.',
          trailing: services.isEmpty
              ? null
              : AppBadge(
                  label: services.length == 1
                      ? '1 culto'
                      : '${services.length} cultos',
                ),
        ),
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
