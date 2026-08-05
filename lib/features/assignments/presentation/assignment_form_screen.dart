import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/form_scaffold.dart';
import '../../events/data/event_repository.dart';
import '../../events/domain/event_models.dart';
import '../../team/data/team_repository.dart';
import '../../team/domain/team_models.dart';

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
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = <Map<String, String?>>[
      for (final entry in _selected.entries)
        for (final membershipId in entry.value)
          {
            'membershipId': membershipId,
            'positionId': entry.key,
          },
    ];

    try {
      final updated = await ref
          .read(eventRepositoryProvider)
          .replaceAssignments(widget.eventId, payload);
      ref.invalidate(eventProvider(widget.eventId));
      if (!mounted) return;

      final conflicts = updated.warnings.sameDayConflicts;
      if (conflicts.isNotEmpty) {
        final names = conflicts.map((c) => c.displayName).toSet().join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Escala salva. Aviso: $names também está escalado(a) em outro culto no mesmo dia.',
            ),
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

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventProvider(widget.eventId));

    return eventAsync.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('Escalar')),
        body: AppErrorState(
          message: 'Não foi possível carregar o culto.',
          onRetry: () => ref.invalidate(eventProvider(widget.eventId)),
        ),
      ),
      data: (cached) {
        final event = cached.data;
        _seedFromEvent(event);
        final membersAsync = ref.watch(membersProvider(event.teamId));
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
            data: (positions) {
              final activePositions = positions
                  .where((p) => p.isActive)
                  .toList()
                ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

              return Scaffold(
                appBar: AppBar(title: const Text('Escalar equipe')),
                body: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.listPadding,
                    AppSpacing.lg,
                    AppSpacing.listPadding,
                    100,
                  ),
                  children: [
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Escolha quem toca em cada função. Salvar substitui a escala inteira.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      FormErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    for (final position in activePositions) ...[
                      _PositionSection(
                        position: position,
                        members: members,
                        selected:
                            _selected[position.id] ?? const <String>{},
                        onChanged: (next) {
                          setState(() {
                            _selected[position.id] = next;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
                bottomNavigationBar: Material(
                  elevation: 8,
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Salvar escala'),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PositionSection extends StatelessWidget {
  const _PositionSection({
    required this.position,
    required this.members,
    required this.selected,
    required this.onChanged,
  });

  final Position position;
  final List<Member> members;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final registered = members
        .where((m) => m.positions.any((p) => p.id == position.id))
        .toList();
    final others = members
        .where((m) => !m.positions.any((p) => p.id == position.id))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              position.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            if (registered.isEmpty && others.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Nenhum membro cadastrado.'),
              ),
            if (registered.isNotEmpty) ...[
              Text(
                'Com esta função',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              for (final member in registered)
                _MemberTile(
                  member: member,
                  checked: selected.contains(member.id),
                  outsideCadastro: false,
                  onChanged: (checked) {
                    final next = {...selected};
                    if (checked) {
                      next.add(member.id);
                    } else {
                      next.remove(member.id);
                    }
                    onChanged(next);
                  },
                ),
            ],
            if (others.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Outros membros',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              for (final member in others)
                _MemberTile(
                  member: member,
                  checked: selected.contains(member.id),
                  outsideCadastro: true,
                  onChanged: (checked) {
                    final next = {...selected};
                    if (checked) {
                      next.add(member.id);
                    } else {
                      next.remove(member.id);
                    }
                    onChanged(next);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.checked,
    required this.outsideCadastro,
    required this.onChanged,
  });

  final Member member;
  final bool checked;
  final bool outsideCadastro;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: checked,
      onChanged: (value) => onChanged(value ?? false),
      title: Text(member.displayName),
      subtitle: outsideCadastro && checked
          ? const Text('Fora do cadastro desta função')
          : null,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
