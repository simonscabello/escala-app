import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/form_scaffold.dart';
import '../../../shared/widgets/position_icon.dart';
import '../data/team_repository.dart';
import '../domain/team_models.dart';

/// Cadastro de membro sem exigir conta: o líder monta a equipe inteira de uma
/// vez, e cada pessoa reivindica seu cadastro depois, pelo convite.
class MemberFormScreen extends ConsumerStatefulWidget {
  const MemberFormScreen({super.key, required this.teamId, this.member});

  final String teamId;
  final Member? member;

  bool get isEditing => member != null;

  @override
  ConsumerState<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends ConsumerState<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final Set<String> _selected;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.member?.displayName ?? '');
    _phone = TextEditingController(text: widget.member?.phone ?? '');
    _selected = {...?widget.member?.positions.map((p) => p.id)};
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repository = ref.read(teamRepositoryProvider);

      if (widget.isEditing) {
        await repository.updateMember(
          widget.teamId,
          widget.member!.id,
          displayName: _name.text.trim(),
          phone: _phone.text.trim(),
          positionIds: _selected.toList(),
        );
      } else {
        await repository.addMember(
          widget.teamId,
          displayName: _name.text.trim(),
          phone: _phone.text.trim(),
          positionIds: _selected.toList(),
        );
      }

      ref.invalidate(membersProvider(widget.teamId));
      if (mounted) context.pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final positions = ref.watch(positionsProvider(widget.teamId));

    return FormScaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar membro' : 'Adicionar membro'),
      ),
      title: widget.isEditing ? 'Editar membro' : 'Adicionar membro',
      subtitle: widget.isEditing
          ? 'Atualize os dados e as funções.'
          : 'A pessoa não precisa ter conta ainda. Cadastre agora e envie o '
              'convite depois.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  helperText: 'Como a pessoa é chamada na equipe',
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                enabled: !_loading,
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Informe o nome do membro.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Telefone (opcional)',
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                enabled: !_loading,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Funções',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Pode marcar mais de uma.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        positions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (list) => _PositionGrid(
            positions: list,
            selected: _selected,
            enabled: !_loading,
            onToggle: (id, on) => setState(() {
              if (on) {
                _selected.add(id);
              } else {
                _selected.remove(id);
              }
            }),
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
              : Text(widget.isEditing ? 'Salvar' : 'Adicionar'),
        ),
      ],
    );
  }
}

/// Funcoes em duas colunas.
///
/// Antes era um `Wrap`: os chips tinham larguras diferentes ("Som" ao lado de
/// "Multimidia") e as linhas ficavam desalinhadas, dando ao bloco a aparencia
/// de sobra de layout. Em duas colunas de largura igual a lista vira uma
/// grade que se le de cima para baixo.
class _PositionGrid extends StatelessWidget {
  const _PositionGrid({
    required this.positions,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final List<Position> positions;
  final Set<String> selected;
  final bool enabled;
  final void Function(String positionId, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    for (var i = 0; i < positions.length; i += 2) {
      final left = positions[i];
      final right = i + 1 < positions.length ? positions[i + 1] : null;

      rows.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: i + 2 < positions.length ? AppSpacing.sm : 0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildTile(left)),
              const SizedBox(width: AppSpacing.sm),
              // Numero impar de funcoes: a ultima ocupa so a coluna da
              // esquerda, em vez de esticar e ficar diferente das outras.
              Expanded(
                child: right == null
                    ? const SizedBox.shrink()
                    : _buildTile(right),
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildTile(Position position) {
    return _PositionTile(
      position: position,
      selected: selected.contains(position.id),
      enabled: enabled,
      onTap: () => onToggle(position.id, !selected.contains(position.id)),
    );
  }
}

class _PositionTile extends StatelessWidget {
  const _PositionTile({
    required this.position,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Position position;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground =
        selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                PositionIcon(
                  position.name,
                  category: position.category,
                  size: 17,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    position.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
