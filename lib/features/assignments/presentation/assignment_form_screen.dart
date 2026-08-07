import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/position_icon.dart';
import '../../../shared/widgets/unavailable_badge.dart';
import '../../../shared/widgets/form_scaffold.dart';
import '../../events/data/event_repository.dart';
import '../../events/domain/event_models.dart';
import '../../team/data/team_repository.dart';
import '../../team/domain/team_models.dart';

/// Montagem da escala.
///
/// A versão anterior listava todos os membros em checkbox dentro de cada
/// função: com 6 funções e 6 integrantes eram 36 linhas e uma rolagem enorme
/// para uma tarefa que o líder repete toda semana. Aqui cada função é um
/// cartão compacto que mostra quem já está escalado, e a escolha acontece numa
/// folha focada em uma função de cada vez.
class AssignmentFormScreen extends ConsumerStatefulWidget {
  const AssignmentFormScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<AssignmentFormScreen> createState() =>
      _AssignmentFormScreenState();
}

class _AssignmentFormScreenState extends ConsumerState<AssignmentFormScreen> {
  /// positionId -> membershipIds selecionados
  final Map<String, Set<String>> _selected = {};

  /// Quem conduz a ministração do louvor. Um por escala, não por função.
  String? _ministerId;

  bool _seeded = false;
  bool _saving = false;
  String? _error;

  void _seedFromEvent(Event event) {
    if (_seeded) return;
    _seeded = true;
    for (final group in event.assignments) {
      _selected[group.positionId] = {
        for (final member in group.members) member.membershipId,
      };
    }
    _ministerId = event.minister?.membershipId;
  }

  /// Todos os escalados, sem repetir quem acumula duas funções.
  Set<String> get _assignedIds =>
      _selected.values.expand((ids) => ids).toSet();

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

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = <Map<String, Object?>>[
      for (final entry in _selected.entries)
        for (final membershipId in entry.value)
          {'membershipId': membershipId, 'positionId': entry.key},
    ];

    try {
      final updated = await ref
          .read(eventRepositoryProvider)
          .replaceAssignments(
            widget.eventId,
            payload,
            ministerMembershipId: _ministerId,
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

      if (warnings.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text('Escala salva. ${warnings.join(' ')}'),
          ),
        );
      }

      context.pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPicker({
    required Position position,
    required List<Member> members,
    required List<Position> positions,
    required Set<String> unavailableIds,
    required String teamId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _MemberPickerSheet(
        position: position,
        members: members,
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

  Future<Member?> _addGuest(String teamId, String name) async {
    try {
      final guest = await ref.read(addGuestProvider)(teamId, name);
      ref.invalidate(schedulableMembersProvider(teamId));
      return guest;
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activePositions = positions.where((p) => p.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    // Quem avisou que não pode no dia desta escala. Não bloqueia escalar —
    // sinaliza, porque o líder às vezes já combinou uma troca por fora.
    final unavailableIds = {
      for (final person in event.unavailable) person.membershipId,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Escalar equipe')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xxxl,
        ),
        children: [
          Text(event.describe(), style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          _SummaryBar(
            people: _distinctPeople,
            filled: _filledPositions,
            total: activePositions.length,
          ),
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
              unavailableIds: unavailableIds,
              onTap: () => _openPicker(
                position: position,
                members: members,
                positions: activePositions,
                unavailableIds: unavailableIds,
                teamId: event.teamId,
              ),
              onRemove: (membershipId) => setState(() {
                final next = {...?_selected[position.id]}..remove(membershipId);
                _selected[position.id] = next;
                _dropMinisterIfUnassigned();
              }),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.lg),
          // Depois das funções de propósito: só dá para escolher o ministrante
          // entre quem já foi escalado.
          _MinisterPicker(
            members: members,
            assignedIds: _assignedIds,
            ministerId: _ministerId,
            enabled: !_saving,
            onChanged: (id) => setState(() => _ministerId = id),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Salvar substitui toda a equipe escalada.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar escala'),
            ),
          ),
        ),
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
    final foreground = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return Material(
      color: selected
          ? scheme.primaryContainer
          : scheme.surfaceContainerHigh,
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
    required this.unavailableIds,
    required this.onTap,
    required this.onRemove,
  });

  final Position position;
  final List<Member> members;
  final Set<String> selected;
  final Set<String> unavailableIds;
  final VoidCallback onTap;
  final ValueChanged<String> onRemove;

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
    required this.onRemove,
  });

  final Member member;
  final bool outsideRegistration;
  final bool unavailable;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Indisponível pesa mais que "fora do cadastro": a pessoa avisou que não
    // estará lá, então o chip vai em vermelho.
    final warn = outsideRegistration || unavailable;

    final background = unavailable
        ? scheme.errorContainer
        : (warn
            ? scheme.primaryContainer
            : scheme.surfaceContainerHigh);
    final foreground = unavailable
        ? scheme.onErrorContainer
        : (warn ? scheme.onPrimaryContainer : scheme.onSurface);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAvatar(name: member.displayName, radius: 12),
          const SizedBox(width: AppSpacing.sm),
          Text(
            member.displayName,
            style: theme.textTheme.labelLarge?.copyWith(color: foreground),
          ),
          if (unavailable) ...[
            const SizedBox(width: 4),
            Icon(Icons.event_busy_rounded, size: 15, color: foreground),
          ] else if (warn) ...[
            const SizedBox(width: 4),
            Icon(Icons.info_outline_rounded, size: 15, color: foreground),
          ],
          const SizedBox(width: 2),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Folha de escolha, focada em uma função por vez.
class _MemberPickerSheet extends StatefulWidget {
  const _MemberPickerSheet({
    required this.position,
    required this.members,
    required this.unavailableIds,
    required this.blockedReason,
    required this.onAddGuest,
    required this.initialSelection,
    required this.onChanged,
  });

  final Position position;
  final List<Member> members;
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
    this.outsideRegistration = false,
    this.unavailable = false,
    this.blockedReason,
  });

  final Member member;
  final bool checked;
  final VoidCallback onTap;
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

    return Opacity(
      opacity: blocked ? 0.45 : 1,
      child: InkWell(
        onTap: blocked ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              AppAvatar(name: member.displayName, radius: 18),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.displayName,
                            style: theme.textTheme.bodyLarge,
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
                        ),
                      )
                    else if (outsideRegistration && checked)
                      Text(
                        'Fora do cadastro desta função',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        'Convidado',
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
