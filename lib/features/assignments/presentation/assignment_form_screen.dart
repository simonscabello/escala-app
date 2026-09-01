import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/responsive/adaptive_dialog.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/app_submit_button.dart';
import '../../../shared/widgets/position_icon.dart';
import '../../../shared/widgets/unavailable_badge.dart';
import '../../../shared/widgets/form_scaffold.dart';
import '../../events/data/event_repository.dart';
import '../../events/domain/event_models.dart';
import '../../events/presentation/schedule_changed_dialog.dart';
import '../../team/data/team_repository.dart';
import '../../team/domain/team_models.dart';
import '../../team/domain/workload_report.dart';

@visibleForTesting
List<Map<String, Object?>> buildAssignmentPayload(
  Map<String, Set<String>> selected,
  Map<(String, String), String> notes,
) {
  return <Map<String, Object?>>[
    for (final entry in selected.entries)
      for (final membershipId in entry.value)
        {
          'membershipId': membershipId,
          'positionId': entry.key,
          if (notes[(entry.key, membershipId)] case final note?) 'note': note,
        },
  ];
}

/// Como o rodízio da pessoa aparece na linha do seletor.
///
/// O líder não escala por planilha: ele lembra de quem vem à cabeça, e quem vem
/// à cabeça é quem tocou no domingo passado. Duas informações curtas ao lado do
/// nome — há quanto tempo e quantas vezes — bastam para ele reparar em quem
/// está sumindo da escala. **Não bloqueia nem sugere nada**: a decisão continua
/// sendo dele, que sabe de coisas que o app não sabe.
@visibleForTesting
String rotationSummary(
  RotationMember? rotation, {
  required int weeks,
  required DateTime now,
}) {
  final last = rotation?.lastScheduledAt;
  if (last == null) return 'Sem escala no último ano';

  final days = now.toUtc().difference(last).inDays;
  final when = switch (days) {
    <= 0 => 'Hoje',
    1 => 'Ontem',
    < 14 => 'Há $days dias',
    < 60 => 'Há ${(days / 7).round()} semanas',
    _ => 'Há ${(days / 30).round()} meses',
  };

  final count = rotation!.recentCount;
  return '$when · $count ${count == 1 ? 'escala' : 'escalas'} '
      'em $weeks semanas';
}

/// Montagem da escala.
///
/// A versão anterior listava todos os membros em checkbox dentro de cada
/// função: com 6 funções e 6 integrantes eram 36 linhas e uma rolagem enorme
/// para uma tarefa que o líder repete toda semana. Aqui cada função é um
/// cartão compacto que mostra quem já está escalado, e a escolha acontece numa
/// folha focada em uma função de cada vez.
class AssignmentFormScreen extends ConsumerStatefulWidget {
  const AssignmentFormScreen({
    super.key,
    required this.eventId,
    this.nextIsSetlist = false,
  });

  final String eventId;

  /// Esta tela é o segundo passo de uma escala recém-criada, e o repertório é
  /// o terceiro.
  ///
  /// Muda duas coisas: o botão diz para onde leva, e salvar emenda no
  /// repertório em vez de voltar. Montar a escala é escalar a equipe **e**
  /// escolher as músicas — parar no meio é o que fazia o líder ter de procurar
  /// a escala de novo na agenda para terminar.
  final bool nextIsSetlist;

  @override
  ConsumerState<AssignmentFormScreen> createState() =>
      _AssignmentFormScreenState();
}

class _AssignmentFormScreenState extends ConsumerState<AssignmentFormScreen> {
  /// positionId -> membershipIds selecionados
  final Map<String, Set<String>> _selected = {};

  /// Recado individual por (função, pessoa).
  ///
  /// A API já guardava este campo, mas o formulário remontava o payload só
  /// com os ids. Assim, abrir uma escala antiga e salvar qualquer ajuste
  /// apagava todos os recados sem aviso.
  final Map<(String, String), String> _notes = {};

  /// Quem conduz a ministração do louvor. Um por escala, não por função.
  String? _ministerId;

  bool _seeded = false;
  bool _saving = false;
  String? _error;

  /// Versão da escala no momento em que esta tela a abriu. Vai junto ao salvar
  /// para o servidor recusar a gravação se outra pessoa mexeu no meio.
  DateTime? _expectedUpdatedAt;

  void _seedFromEvent(Event event) {
    if (_seeded) return;
    _seeded = true;
    _expectedUpdatedAt = event.updatedAt;
    for (final group in event.assignments) {
      _selected[group.positionId] = {
        for (final member in group.members) member.membershipId,
      };
      for (final member in group.members) {
        final note = member.note?.trim();
        if (note != null && note.isNotEmpty) {
          _notes[(group.positionId, member.membershipId)] = note;
        }
      }
    }
    _ministerId = event.minister?.membershipId;
  }

  /// Todos os escalados, sem repetir quem acumula duas funções.
  Set<String> get _assignedIds => _selected.values.expand((ids) => ids).toSet();

  /// O ministrante precisa continuar escalado; se saiu, o campo se limpa.
  void _dropMinisterIfUnassigned() {
    if (_ministerId != null && !_assignedIds.contains(_ministerId)) {
      _ministerId = null;
    }
  }

  /// Pessoas distintas: quem acumula duas funções conta uma vez.
  int get _distinctPeople =>
      _selected.values.expand((ids) => ids).toSet().length;

  /// Por que esta pessoa não pode entrar nesta função, dado o resto da escala.
  ///
  /// Duas regras do culto (as mesmas validadas no backend):
  ///  - ninguém toca dois instrumentos; vocal acumula com um instrumento
  ///  - quem está na multimídia ou no som fica fora da banda
  ///
  /// Bloquear na tela evita o líder montar a escala inteira e só descobrir o
  /// problema ao salvar.
  String? _blockedReason(
    Member member,
    Position target,
    List<Position> positions,
  ) {
    final byId = {for (final p in positions) p.id: p};
    final current = <Position>[
      for (final entry in _selected.entries)
        if (entry.key != target.id && entry.value.contains(member.id))
          if (byId[entry.key] != null) byId[entry.key]!,
    ];

    if (target.isInstrument) {
      final other = current.where((p) => p.isInstrument).firstOrNull;
      if (other != null) return 'Já está em ${other.name}';
      final tech = current.where((p) => p.isTech).firstOrNull;
      if (tech != null) return 'Está em ${tech.name}';
    }

    if (target.isVocal) {
      final tech = current.where((p) => p.isTech).firstOrNull;
      if (tech != null) return 'Está em ${tech.name}';
    }

    if (target.isTech) {
      final band =
          current.where((p) => p.isVocal || p.isInstrument).firstOrNull;
      if (band != null) return 'Está em ${band.name}';
    }

    return null;
  }

  int get _filledPositions =>
      _selected.values.where((ids) => ids.isNotEmpty).length;

  /// [force] repete a gravação sem a trava de versão: é o "salvar assim mesmo"
  /// de quem viu o aviso de que a escala mudou e decidiu sobrescrever.
  Future<void> _save({bool force = false}) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = buildAssignmentPayload(_selected, _notes);

    try {
      final updated =
          await ref.read(eventRepositoryProvider).replaceAssignments(
                widget.eventId,
                payload,
                ministerMembershipId: _ministerId,
                expectedUpdatedAt: force ? null : _expectedUpdatedAt,
              );
      ref.invalidate(eventProvider(widget.eventId));
      // A agenda também mostra a escalação (o chip "VOCÊ" e a contagem de
      // escalados). Sem invalidar a lista, o cartão continuava com o número
      // de antes de salvar, contradizendo a tela de detalhe.
      ref.invalidate(eventsProvider((updated.teamId, 'upcoming')));
      ref.invalidate(eventsProvider((updated.teamId, 'past')));
      if (!mounted) return;

      // Avisos depois de salvar, não bloqueios antes: a escala é do líder.
      final warnings = <String>[];

      final unavailable = updated.warnings.unavailableAssigned;
      if (unavailable.isNotEmpty) {
        final names = unavailable.map((u) => u.displayName).toSet().join(', ');
        warnings.add('$names marcou que não pode neste dia.');
      }

      final conflicts = updated.warnings.sameDayConflicts;
      if (conflicts.isNotEmpty) {
        final names = conflicts.map((c) => c.displayName).toSet().join(', ');
        warnings.add('$names também está em outra escala no mesmo dia.');
      }

      // Salvar sem avisos também precisa responder. Antes, a tela simplesmente
      // fechava: dava para não ter certeza se o toque tinha pegado, e o líder
      // reabria a escala para conferir.
      showAppSnackBar(
        context,
        warnings.isEmpty
            ? 'Escala salva.'
            : 'Escala salva. ${warnings.join(' ')}',
        tone: warnings.isEmpty ? AppTone.success : AppTone.warning,
      );

      // `pushReplacement` e não `push`: a escalação já foi salva, e voltar para
      // ela do repertório só ofereceria salvá-la de novo. O que fica embaixo é
      // o detalhe da escala, que é onde o repertório desemboca ao terminar.
      if (widget.nextIsSetlist) {
        context.pushReplacement(
          '/agenda/${widget.eventId}/repertorio?novo=1',
        );
        return;
      }
      context.pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == scheduleChangedCode) {
        await _resolveConflict(error.message);
        return;
      }
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Sobrescrever é escolha da pessoa; conferir é o caminho oferecido primeiro.
  /// Ao voltar, o detalhe recarrega e mostra a escala como ela está agora.
  Future<void> _resolveConflict(String message) async {
    final overwrite = await showScheduleChangedDialog(context, message);
    if (!mounted) return;

    if (overwrite) {
      await _save(force: true);
      return;
    }
    ref.invalidate(eventProvider(widget.eventId));
    if (mounted) context.pop();
  }

  Future<void> _openPicker({
    required Position position,
    required List<Member> members,
    required List<Position> positions,
    required Set<String> unavailableIds,
    required String teamId,
    required Map<String, RotationMember>? rotation,
  }) async {
    // No celular sobe do rodapé; no monitor abre no centro. O conteúdo é o
    // mesmo widget nos dois casos.
    await showAdaptiveSheet<void>(
      context: context,
      maxWidth: 560,
      builder: (sheetContext) => _MemberPickerSheet(
        position: position,
        members: members,
        rotation: rotation,
        unavailableIds: unavailableIds,
        blockedReason: (member) => _blockedReason(member, position, positions),
        onAddGuest: (name) => _addGuest(teamId, name),
        initialSelection: _selected[position.id] ?? const <String>{},
        onChanged: (next) => setState(() {
          _selected[position.id] = next;
          _dropMinisterIfUnassigned();
        }),
      ),
    );
  }

  Future<void> _editNote({
    required Position position,
    required Member member,
  }) async {
    final key = (position.id, member.id);
    final controller = TextEditingController(text: _notes[key] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Recado para ${member.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              position.name,
              style: Theme.of(dialogContext).textTheme.labelLarge?.copyWith(
                    color: Theme.of(dialogContext).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Recado individual',
                hintText: 'Ex.: trazer o violão reserva',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Salvar recado'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;

    setState(() {
      if (result.isEmpty) {
        _notes.remove(key);
      } else {
        _notes[key] = result;
      }
    });
  }

  Future<Member?> _addGuest(String teamId, String name) async {
    try {
      final guest = await ref.read(addGuestProvider)(teamId, name);
      ref.invalidate(schedulableMembersProvider(teamId));
      return guest;
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, tone: AppTone.danger);
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventProvider(widget.eventId));

    return eventAsync.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('Escalar')),
        body: AppErrorState(
          message: 'Não foi possível carregar a escala.',
          onRetry: () => ref.invalidate(eventProvider(widget.eventId)),
        ),
      ),
      data: (cached) {
        final event = cached.data;
        _seedFromEvent(event);
        final membersAsync =
            ref.watch(schedulableMembersProvider(event.teamId));
        final positionsAsync = ref.watch(positionsProvider(event.teamId));

        return membersAsync.when(
          loading: () => const Scaffold(body: AppLoading()),
          error: (_, __) => Scaffold(
            appBar: AppBar(title: const Text('Escalar')),
            body: const AppErrorState(
              message: 'Não foi possível carregar a equipe.',
            ),
          ),
          data: (members) => positionsAsync.when(
            loading: () => const Scaffold(body: AppLoading()),
            error: (_, __) => Scaffold(
              appBar: AppBar(title: const Text('Escalar')),
              body: const AppErrorState(
                message: 'Não foi possível carregar as funções.',
              ),
            ),
            data: (positions) => _buildForm(context, event, members, positions),
          ),
        );
      },
    );
  }

  Widget _buildForm(
    BuildContext context,
    Event event,
    List<Member> members,
    List<Position> positions,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) => _form(
        context,
        event,
        members,
        positions,
        constraints.maxWidth,
      ),
    );
  }

  Widget _form(
    BuildContext context,
    Event event,
    List<Member> members,
    List<Position> positions,
    double available,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activePositions = positions.where((p) => p.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    // Quem avisou que não pode no dia desta escala. Não bloqueia escalar —
    // sinaliza, porque o líder às vezes já combinou uma troca por fora.
    final unavailableIds = {
      for (final person in event.unavailable) person.membershipId,
    };
    // Observado aqui, e não dentro da folha: quando o líder toca na função a
    // resposta já chegou, e a linha não nasce depois que ele começou a ler.
    final rotation =
        ref.watch(rotationProvider(event.teamId)).valueOrNull?.members;

    void openPicker(Position position) => _openPicker(
          position: position,
          members: members,
          positions: activePositions,
          unavailableIds: unavailableIds,
          teamId: event.teamId,
          rotation: rotation,
        );

    void removeFrom(Position position, String membershipId) => setState(() {
          final next = {...?_selected[position.id]}..remove(membershipId);
          _selected[position.id] = next;
          _dropMinisterIfUnassigned();
        });

    final minister = _MinisterPicker(
      members: members,
      assignedIds: _assignedIds,
      ministerId: _ministerId,
      enabled: !_saving,
      onChanged: (id) => setState(() => _ministerId = id),
    );

    final summary = _SummaryBar(
      people: _distinctPeople,
      filled: _filledPositions,
      total: activePositions.length,
    );

    final saveButton = AppSubmitButton(
      label: widget.nextIsSetlist ? 'Salvar e escolher músicas' : 'Salvar escala',
      loading: _saving,
      onPressed: _save,
    );

    final replaceWarning = Text(
      'Salvar substitui toda a equipe escalada.',
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    );

    // No monitor, montar a escala deixa de ser uma rolagem.
    //
    // No celular a tarefa é: rolar até a função, tocar, escolher, voltar, rolar
    // de novo — e o "quanto falta" fica no topo, fora da vista justamente
    // enquanto se decide. Com 1024px de largura as duas metades da tarefa cabem
    // lado a lado: as funções à esquerda, como uma tabela de uma superfície só,
    // e à direita o que responde "acabou?" — o resumo, o ministrante e o botão,
    // parados enquanto a lista rola.
    //
    // A escolha de quem entra continua sendo a **mesma** folha do celular; ela
    // só aparece como diálogo (ver `showAdaptiveSheet`).
    // 940 é a largura **disponível para esta tela** (janela menos a barra
    // lateral), não a da janela: num monitor de 1024px com a barra aberta
    // sobram 756px, e ali as duas colunas espremeriam a tabela de funções. Um
    // 1280px deixa ~1010px e cabe com folga.
    if (available >= 940) {
      return Scaffold(
        appBar: AppBar(title: const Text('Escalar equipe')),
        body: SafeArea(
          top: false,
          child: AppContentWidth.wide(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.describe(), style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xl,
                            ),
                            children: [
                              _PositionsTable(
                                positions: activePositions,
                                members: members,
                                selected: _selected,
                                notes: _notes,
                                unavailableIds: unavailableIds,
                                onOpen: openPicker,
                                onRemove: removeFrom,
                                onEditNote: (position, member) => _editNote(
                                  position: position,
                                  member: member,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xl),
                        SizedBox(
                          width: 320,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xl,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                summary,
                                if (_error != null) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  FormErrorBanner(message: _error!),
                                ],
                                const SizedBox(height: AppSpacing.lg),
                                // Depois das funções de propósito: só dá para
                                // escolher o ministrante entre quem já foi
                                // escalado.
                                minister,
                                const SizedBox(height: AppSpacing.lg),
                                saveButton,
                                const SizedBox(height: AppSpacing.md),
                                replaceWarning,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Escalar equipe')),
      body: AppContentWidth.wide(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          children: [
            Text(event.describe(), style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            summary,
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FormErrorBanner(message: _error!),
            ],
            const SizedBox(height: AppSpacing.lg),
            for (final position in activePositions) ...[
              _PositionCard(
                position: position,
                members: members,
                selected: _selected[position.id] ?? const <String>{},
                notes: {
                  for (final membershipId
                      in _selected[position.id] ?? const <String>{})
                    if (_notes[(position.id, membershipId)] case final note?)
                      membershipId: note,
                },
                unavailableIds: unavailableIds,
                onTap: () => openPicker(position),
                onRemove: (membershipId) => removeFrom(position, membershipId),
                onEditNote: (member) => _editNote(
                  position: position,
                  member: member,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.lg),
            // Depois das funções de propósito: só dá para escolher o
            // ministrante entre quem já foi escalado.
            minister,
            const SizedBox(height: AppSpacing.lg),
            replaceWarning,
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          child: AppContentWidth.wide(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: SizedBox(width: double.infinity, child: saveButton),
            ),
          ),
        ),
      ),
    );
  }
}

/// As funções como uma tabela de uma superfície só — a versão de monitor da
/// pilha de cartões.
///
/// **Uma superfície, não uma por função.** Oito cartões com borda própria numa
/// coluna de 700px é o mural de fichas soltas que o `AppGroup` já resolveu no
/// resto do app; aqui a mesma ideia dá também o alinhamento das colunas, que é
/// o que faz a lista ser lida por coluna ("quais funções estão vazias?") em vez
/// de item por item.
class _PositionsTable extends StatelessWidget {
  const _PositionsTable({
    required this.positions,
    required this.members,
    required this.selected,
    required this.notes,
    required this.unavailableIds,
    required this.onOpen,
    required this.onRemove,
    required this.onEditNote,
  });

  final List<Position> positions;
  final List<Member> members;
  final Map<String, Set<String>> selected;
  final Map<(String, String), String> notes;
  final Set<String> unavailableIds;
  final ValueChanged<Position> onOpen;
  final void Function(Position position, String membershipId) onRemove;
  final void Function(Position position, Member member) onEditNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: scheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 200,
                  child: Text('Função', style: AppTypography.eyebrow(context)),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    'Quem está escalado',
                    style: AppTypography.eyebrow(context),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < positions.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
            _PositionRow(
              position: positions[i],
              members: members,
              selected: selected[positions[i].id] ?? const <String>{},
              notes: {
                for (final membershipId
                    in selected[positions[i].id] ?? const <String>{})
                  if (notes[(positions[i].id, membershipId)] case final note?)
                    membershipId: note,
              },
              unavailableIds: unavailableIds,
              onOpen: () => onOpen(positions[i]),
              onRemove: (membershipId) => onRemove(positions[i], membershipId),
              onEditNote: (member) => onEditNote(positions[i], member),
            ),
          ],
        ],
      ),
    );
  }
}

/// Uma função como linha da tabela: nome à esquerda, escalados no meio, a ação
/// à direita — sempre no mesmo lugar, para o clique não ter de ser procurado.
class _PositionRow extends StatelessWidget {
  const _PositionRow({
    required this.position,
    required this.members,
    required this.selected,
    required this.notes,
    required this.unavailableIds,
    required this.onOpen,
    required this.onRemove,
    required this.onEditNote,
  });

  final Position position;
  final List<Member> members;
  final Set<String> selected;
  final Map<String, String> notes;
  final Set<String> unavailableIds;
  final VoidCallback onOpen;
  final ValueChanged<String> onRemove;
  final ValueChanged<Member> onEditNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chosen =
        members.where((m) => selected.contains(m.id)).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 200,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: chosen.isEmpty
                        ? scheme.surfaceContainerHigh
                        : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Center(
                    child: PositionIcon(
                      position.name,
                      category: position.category,
                      size: 16,
                      color: chosen.isEmpty
                          ? scheme.onSurfaceVariant
                          : scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    position.name,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: chosen.isEmpty
                ? Text(
                    'Ninguém escalado',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final member in chosen)
                        _SelectedChip(
                          member: member,
                          // Escalar fora do cadastro é permitido (regra 18); o
                          // chip sinaliza, não impede.
                          outsideRegistration:
                              !member.positions.any((p) => p.id == position.id),
                          unavailable: unavailableIds.contains(member.id),
                          note: notes[member.id],
                          onEditNote: () => onEditNote(member),
                          onRemove: () => onRemove(member.id),
                        ),
                    ],
                  ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Botão com palavra, e não só um ícone: é a ação da linha, e "+"
          // sozinho num monitor não diz se acrescenta pessoa ou função.
          TextButton.icon(
            onPressed: onOpen,
            icon: Icon(
              chosen.isEmpty ? Icons.add_rounded : Icons.edit_outlined,
              size: 18,
            ),
            label: Text(chosen.isEmpty ? 'Escolher' : 'Alterar'),
          ),
        ],
      ),
    );
  }
}
/// Responde "quanto falta?" sem o líder ter de rolar a lista inteira.
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.people,
    required this.filled,
    required this.total,
  });

  final int people;
  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final empty = people == 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: empty ? scheme.surfaceContainerHigh : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Icon(
            empty ? Icons.person_off_outlined : Icons.groups_rounded,
            color: empty ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              empty
                  ? 'Nenhuma função preenchida ainda'
                  : '$people ${people == 1 ? 'pessoa' : 'pessoas'} · '
                      '$filled de $total ${filled == 1 ? 'função' : 'funções'}',
              style: theme.textTheme.titleSmall?.copyWith(
                color:
                    empty ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quem conduz a ministração do louvor nesta escala.
///
/// Um por escala, e não por função: é a pessoa que lê os versículos, fala
/// antes das músicas e delega. Ela também está escalada em alguma função, mas
/// o papel não pertence à função — por isso o campo é próprio, e não uma marca
/// dentro de cada cartão.
class _MinisterPicker extends StatelessWidget {
  const _MinisterPicker({
    required this.members,
    required this.assignedIds,
    required this.ministerId,
    required this.enabled,
    required this.onChanged,
  });

  final List<Member> members;
  final Set<String> assignedIds;
  final String? ministerId;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final assigned = members
        .where((member) => assignedIds.contains(member.id))
        .toList(growable: false)
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    // Sem cartão: o bloco vira mais uma superfície flutuante no meio de uma
    // pilha que já tem um cartão por função. O rótulo e as pastilhas bastam.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.record_voice_over_rounded,
              size: 17,
              color: scheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Ministrante', style: theme.textTheme.titleSmall),
            const SizedBox(width: AppSpacing.sm),
            // A explicação de o que é ministrante saiu: quem monta a escala
            // sabe. Fica só o que muda com a tela -- se dá para escolher.
            if (assigned.isEmpty)
              Expanded(
                child: Text(
                  'escale a equipe primeiro',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        if (assigned.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final member in assigned)
                _MinisterChoice(
                  name: member.displayName,
                  selected: ministerId == member.id,
                  // Tocar no escolhido limpa: às vezes ainda não se sabe
                  // quem vai ministrar, e isso não pode travar a escala.
                  onTap: enabled
                      ? () => onChanged(
                            ministerId == member.id ? null : member.id,
                          )
                      : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MinisterChoice extends StatelessWidget {
  const _MinisterChoice({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground =
        selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: Padding(
          // Sem avatar e com folga menor: são as mesmas pessoas dos cartões
          // logo acima, então o nome já identifica.
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 14, color: foreground),
                const SizedBox(width: 4),
              ],
              Text(
                name,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({
    required this.position,
    required this.members,
    required this.selected,
    required this.notes,
    required this.unavailableIds,
    required this.onTap,
    required this.onRemove,
    required this.onEditNote,
  });

  final Position position;
  final List<Member> members;
  final Set<String> selected;
  final Map<String, String> notes;
  final Set<String> unavailableIds;
  final VoidCallback onTap;
  final ValueChanged<String> onRemove;
  final ValueChanged<Member> onEditNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chosen =
        members.where((m) => selected.contains(m.id)).toList(growable: false);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: chosen.isEmpty
                      ? scheme.surfaceContainerHigh
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Center(
                  child: PositionIcon(
                    position.name,
                    category: position.category,
                    size: 17,
                    color: chosen.isEmpty
                        ? scheme.onSurfaceVariant
                        : scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(position.name, style: theme.textTheme.titleMedium),
              ),
              Icon(
                chosen.isEmpty ? Icons.add_rounded : Icons.edit_outlined,
                size: 20,
                color: scheme.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (chosen.isEmpty)
            Text(
              'Toque para escolher quem toca',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final member in chosen)
                  _SelectedChip(
                    member: member,
                    // Escalar fora do cadastro é permitido (regra 18); o chip
                    // sinaliza, não impede.
                    outsideRegistration:
                        !member.positions.any((p) => p.id == position.id),
                    unavailable: unavailableIds.contains(member.id),
                    note: notes[member.id],
                    onEditNote: () => onEditNote(member),
                    onRemove: () => onRemove(member.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({
    required this.member,
    required this.outsideRegistration,
    required this.unavailable,
    required this.note,
    required this.onEditNote,
    required this.onRemove,
  });

  final Member member;
  final bool outsideRegistration;
  final bool unavailable;
  final String? note;
  final VoidCallback onEditNote;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = AppStatusColors.of(context);

    // O chip de "fora do cadastro" saía **no azul da marca** — a mesma cor que
    // o app usa para "é aqui que você toca" e para tudo que está certo. Ou
    // seja: a única pista de que aquela pessoa não tem a função cadastrada era
    // ela ficar mais bonita que as outras. Âmbar é o papel de atenção da
    // paleta, e é o que o resto do app já usa para isto.
    final tone = unavailable
        ? AppTone.danger
        : outsideRegistration
            ? AppTone.warning
            : AppTone.neutral;
    final palette = status.resolve(tone, scheme);

    final hint = unavailable
        ? '${member.displayName} avisou que não pode neste dia'
        : outsideRegistration
            ? '${member.displayName} não tem esta função no cadastro'
            : null;

    return Semantics(
      label: hint ?? member.displayName,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: palette.container,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAvatar(
              name: member.displayName,
              imageUrl: member.avatarUrl,
              radius: 12,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              member.displayName,
              style: theme.textTheme.labelLarge?.copyWith(
                color: palette.onContainer,
              ),
            ),
            if (unavailable) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.event_busy_rounded,
                size: 15,
                color: palette.onContainer,
              ),
            ] else if (outsideRegistration) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: palette.onContainer,
              ),
            ],
            Tooltip(
              message: note == null ? 'Adicionar recado' : 'Editar recado',
              child: Semantics(
                button: true,
                label: note == null
                    ? 'Adicionar recado para ${member.displayName}'
                    : 'Editar recado de ${member.displayName}: $note',
                child: InkWell(
                  onTap: onEditNote,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      note == null
                          ? Icons.edit_note_outlined
                          : Icons.sticky_note_2_rounded,
                      size: 16,
                      color: note == null
                          ? palette.onContainer.withValues(alpha: 0.72)
                          : palette.onContainer,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            // O "x" herdava `onSurfaceVariant` seja qual fosse o fundo do chip
            // -- cinza sobre o vermelho de indisponível.
            Semantics(
              button: true,
              label: 'Tirar ${member.displayName} da escala',
              child: InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: palette.onContainer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Folha de escolha, focada em uma função por vez.
class _MemberPickerSheet extends StatefulWidget {
  const _MemberPickerSheet({
    required this.position,
    required this.members,
    required this.rotation,
    required this.unavailableIds,
    required this.blockedReason,
    required this.onAddGuest,
    required this.initialSelection,
    required this.onChanged,
  });

  final Position position;
  final List<Member> members;

  /// Nulo enquanto o relatório de rodízio não chegou.
  final Map<String, RotationMember>? rotation;
  final Set<String> unavailableIds;

  /// Nulo = pode escalar. Texto = motivo do bloqueio, exibido na linha.
  final String? Function(Member) blockedReason;
  final Future<Member?> Function(String displayName) onAddGuest;
  final Set<String> initialSelection;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
  late Set<String> _working = {...widget.initialSelection};

  /// "Outros membros" começa recolhido: na maioria das semanas o líder escala
  /// quem já tem a função cadastrada, e repetir a equipe inteira em cada
  /// função era o que transformava a tela num paredão.
  bool _showOthers = false;
  bool _addingGuest = false;

  /// Cadastra o convidado e já o deixa marcado nesta função — quem abre esse
  /// fluxo está com a função vazia na mão.
  Future<void> _promptGuest() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Convidar alguém de fora'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Músico convidado não tem conta no app. Ele entra na escala e '
              'recebe os detalhes pelo texto compartilhado.',
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome'),
              onSubmitted: (value) =>
                  Navigator.of(dialogContext).pop(value.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (name == null || name.length < 2 || !mounted) return;

    setState(() => _addingGuest = true);
    final guest = await widget.onAddGuest(name);
    if (!mounted) return;

    setState(() {
      _addingGuest = false;
      if (guest != null) {
        _working = {..._working, guest.id};
        _extraGuests = [..._extraGuests, guest];
      }
    });
    if (guest != null) widget.onChanged(_working);
  }

  /// Convidados criados aqui dentro: a lista recebida por parâmetro só é
  /// recarregada quando a folha fecha.
  List<Member> _extraGuests = [];

  /// O convidado fica de fora: ele não faz parte da equipe, e "sem escala no
  /// último ano" ao lado do nome de quem foi chamado só para o dia diria algo
  /// que não é sobre ele.
  String? _rotationOf(Member member) {
    final report = widget.rotation;
    if (report == null || member.isGuest) return null;
    return rotationSummary(
      report[member.id],
      weeks: rotationWeeks,
      now: DateTime.now(),
    );
  }

  void _toggle(String membershipId) {
    setState(() {
      _working = {..._working};
      if (!_working.remove(membershipId)) {
        _working.add(membershipId);
      }
    });
    widget.onChanged(_working);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final all = [...widget.members, ..._extraGuests];
    final registered = all
        .where((m) => m.positions.any((p) => p.id == widget.position.id))
        .toList();
    final others = all
        .where((m) => !m.positions.any((p) => p.id == widget.position.id))
        .toList();

    // Quem foi escalado fora do cadastro continua visível mesmo com a seção
    // recolhida -- senão a pessoa sumiria da folha logo após ser marcada.
    final othersToShow = _showOthers
        ? others
        : others.where((m) => _working.contains(m.id)).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  PositionIcon(
                    widget.position.name,
                    category: widget.position.category,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      widget.position.name,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${_working.length} '
                    'escolhido${_working.length == 1 ? '' : 's'}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                // shrinkWrap para a folha ter a altura do conteúdo: com uma
                // função de poucos membros ela abria ocupando 3/4 da tela,
                // quase tudo vazio. O ConstrainedBox acima segue limitando.
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  if (registered.isEmpty && others.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Text('Nenhum membro cadastrado na equipe.'),
                    ),
                  if (registered.isNotEmpty) ...[
                    _SheetLabel('Com esta função', count: registered.length),
                    for (final member in registered)
                      _PickerTile(
                        member: member,
                        checked: _working.contains(member.id),
                        rotation: _rotationOf(member),
                        unavailable: widget.unavailableIds.contains(member.id),
                        blockedReason: widget.blockedReason(member),
                        onTap: () => _toggle(member.id),
                      ),
                  ],
                  if (others.isNotEmpty) ...[
                    _SheetLabel(
                      'Outros membros',
                      count: others.length,
                      trailing: TextButton(
                        onPressed: () =>
                            setState(() => _showOthers = !_showOthers),
                        child: Text(_showOthers ? 'Ocultar' : 'Mostrar'),
                      ),
                    ),
                    for (final member in othersToShow)
                      _PickerTile(
                        member: member,
                        checked: _working.contains(member.id),
                        rotation: _rotationOf(member),
                        outsideRegistration: true,
                        unavailable: widget.unavailableIds.contains(member.id),
                        blockedReason: widget.blockedReason(member),
                        onTap: () => _toggle(member.id),
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                children: [
                  // O momento em que se descobre que falta alguém é este:
                  // montando a escala e sem ninguém para a função.
                  TextButton.icon(
                    onPressed: _addingGuest ? null : _promptGuest,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Convidar alguém de fora'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Concluir'),
                    ),
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

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text, {required this.count, this.trailing});

  final String text;
  final int count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        trailing == null ? AppSpacing.xl : AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$text ($count)',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.member,
    required this.checked,
    required this.onTap,
    this.rotation,
    this.outsideRegistration = false,
    this.unavailable = false,
    this.blockedReason,
  });

  final Member member;
  final bool checked;
  final VoidCallback onTap;

  /// "Há 3 semanas · 2 escalas em 8 semanas". Nulo = nada a mostrar.
  final String? rotation;
  final bool outsideRegistration;

  /// A pessoa avisou que não pode no dia desta escala.
  final bool unavailable;

  /// Combinação proibida (dois instrumentos, ou técnica junto com banda).
  /// Diferente de "indisponível": aqui não há escolha, a regra impede.
  final String? blockedReason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final blocked = blockedReason != null && !checked;

    // A linha inteira é **um** controle: sem `MergeSemantics` o leitor de tela
    // lia o nome e a caixa de seleção como dois itens separados, e o estado
    // ficava longe de quem ele descreve.
    return MergeSemantics(
      child: InkWell(
        onTap: blocked ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              // O esmaecido cobre só a identificação da pessoa. Antes ele
              // envolvia a linha toda a 45%, **inclusive o motivo do bloqueio**
              // -- justamente a frase que explica por que aquele nome não pode
              // ser marcado, apagada até quase sumir.
              Opacity(
                opacity: blocked ? 0.5 : 1,
                child: AppAvatar(
                  name: member.displayName,
                  imageUrl: member.avatarUrl,
                  radius: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Opacity(
                            opacity: blocked ? 0.5 : 1,
                            child: Text(
                              member.displayName,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ),
                        // Continua na lista e continua selecionável: o líder às
                        // vezes já acertou uma troca por fora do app.
                        if (unavailable) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const UnavailableBadge(),
                        ],
                        if (member.isGuest) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const _GuestBadge(),
                        ],
                      ],
                    ),
                    if (blocked)
                      Text(
                        blockedReason!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else if (outsideRegistration && checked)
                      // Âmbar, não azul: é uma ressalva, e o azul é a cor do
                      // que está certo no app inteiro.
                      Text(
                        'Fora do cadastro desta função',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppStatusColors.of(context).warning.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    // Cinza, e não uma cor de estado: é contexto para a
                    // decisão do líder, não alarme. Escalar de novo quem tocou
                    // ontem continua sendo legítimo.
                    else if (rotation != null)
                      Text(
                        rotation!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Checkbox(
                value: checked,
                onChanged: blocked ? null : (_) => onTap(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marca quem é de fora — na escala compartilhada isso muda o que se espera
/// da pessoa (não tem o app, não vê avisos).
class _GuestBadge extends StatelessWidget {
  const _GuestBadge();

  @override
  Widget build(BuildContext context) {
    return const AppBadge(
      label: 'Convidado',
      tone: AppTone.info,
      semanticsLabel: 'Convidado de fora: não tem conta no app e recebe a '
          'escala pelo texto compartilhado',
    );
  }
}
