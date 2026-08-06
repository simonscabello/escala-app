import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/form_scaffold.dart';
import '../application/auth_controller.dart';

/// Obrigatoria depois que o líder redefine a senha do membro (regra 27).
/// Enquanto a troca não acontece, o backend bloqueia as demais rotas.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      showBrand: true,
      title: 'Defina uma nova senha',
      subtitle:
          'Sua senha foi redefinida pelo líder da equipe. Escolha uma nova '
          'para continuar.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _current,
                decoration: const InputDecoration(
                  labelText: 'Senha atual (a que você recebeu)',
                ),
                obscureText: true,
                textInputAction: TextInputAction.next,
                enabled: !_loading,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Informe a senha atual.' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _next,
                decoration: const InputDecoration(
                  labelText: 'Nova senha',
                  helperText: 'Ao menos 8 caracteres',
                ),
                obscureText: true,
                textInputAction: TextInputAction.next,
                enabled: !_loading,
                validator: (v) => (v == null || v.length < 8)
                    ? 'A senha precisa ter ao menos 8 caracteres.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _confirm,
                decoration: const InputDecoration(
                  labelText: 'Confirme a nova senha',
                ),
                obscureText: true,
                textInputAction: TextInputAction.done,
                enabled: !_loading,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) =>
                    v != _next.text ? 'As senhas não conferem.' : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_error != null) FormErrorBanner(message: _error!),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar e continuar'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _loading
              ? null
              : () => ref.read(authControllerProvider.notifier).logout(),
          child: const Text('Sair'),
        ),
      ],
    );
  }
}
