import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/form_scaffold.dart';
import '../../auth/application/auth_controller.dart';
import '../data/team_repository.dart';

/// Dados da equipe.
///
/// Só o nome. O fuso horário é sempre o de Brasília e nem aparece: era uma
/// escolha que ninguém precisava fazer e que, errada, deslocaria o horário de
/// todas as escalas sem deixar pista do motivo.
class TeamSettingsScreen extends ConsumerStatefulWidget {
  const TeamSettingsScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<TeamSettingsScreen> createState() => _TeamSettingsScreenState();
}

class _TeamSettingsScreenState extends ConsumerState<TeamSettingsScreen> {
  final _name = TextEditingController();
  bool _populated = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Informe o nome da equipe.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(teamRepositoryProvider).update(widget.teamId, name: name);
      ref.invalidate(teamProvider(widget.teamId));
      // O nome da equipe aparece na saudação da agenda, que vem do estado de
      // autenticação -- sem recarregar, a agenda continuaria com o nome antigo.
      await ref.read(authControllerProvider.notifier).reloadTeams();
      if (mounted) context.pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(teamProvider(widget.teamId));

    if (team.isLoading) {
      return const Scaffold(body: AppLoading());
    }
    if (team.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dados da equipe')),
        body: AppErrorState(
          message: 'Não foi possível carregar a equipe.',
          onRetry: () => ref.invalidate(teamProvider(widget.teamId)),
        ),
      );
    }

    final value = team.valueOrNull;
    if (value != null && !_populated) {
      _populated = true;
      _name.text = value.name;
    }

    return FormScaffold(
      appBar: AppBar(title: const Text('Dados da equipe')),
      title: 'Dados da equipe',
      subtitle: 'O nome aparece na agenda e nos convites.',
      children: [
        TextField(
          controller: _name,
          enabled: !_saving,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome da equipe'),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (_error != null) FormErrorBanner(message: _error!),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
