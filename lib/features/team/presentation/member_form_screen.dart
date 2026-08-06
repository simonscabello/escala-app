import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/form_scaffold.dart';
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
          data: (list) => Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final position in list)
                FilterChip(
                  label: Text(position.name),
                  selected: _selected.contains(position.id),
                  onSelected: _loading
                      ? null
                      : (on) => setState(() {
                            if (on) {
                              _selected.add(position.id);
                            } else {
                              _selected.remove(position.id);
                            }
                          }),
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
              : Text(widget.isEditing ? 'Salvar' : 'Adicionar'),
        ),
      ],
    );
  }
}
