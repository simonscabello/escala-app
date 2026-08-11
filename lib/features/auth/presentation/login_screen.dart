import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_submit_button.dart';
import '../../../shared/widgets/form_scaffold.dart';
import '../application/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).login(
            email: _email.text.trim(),
            password: _password.text,
          );
      // A navegacao e feita pelo redirect do router ao mudar o estado de auth.
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
      title: 'Entrar',
      subtitle: 'Acesse as escalas da sua equipe de louvor.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'E-mail'),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                enabled: !_loading,
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Informe um e-mail válido.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _password,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  suffixIcon: IconButton(
                    // Sem `tooltip` o leitor de tela anunciava só "botão": não
                    // dizia o que ele faz nem em que estado a senha está.
                    tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                enabled: !_loading,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Informe sua senha.' : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_error != null) FormErrorBanner(message: _error!),
        AppSubmitButton(
          label: 'Entrar',
          loading: _loading,
          loadingLabel: 'Entrando',
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _loading ? null : () => context.go('/cadastro'),
          child: const Text('Não tenho conta. Criar agora'),
        ),
        const SizedBox(height: AppSpacing.xl),
        TextButton.icon(
          onPressed: () => context.push('/diagnostico'),
          icon: const Icon(Icons.wifi_tethering, size: 18),
          label: const Text('Problemas para conectar?'),
        ),
      ],
    );
  }
}
