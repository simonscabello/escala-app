import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_submit_button.dart';
import '../../../shared/widgets/form_scaffold.dart';
import '../../auth/application/auth_controller.dart';

/// Meus dados: nome e e-mail. A senha tem tela propria porque exige a atual.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();

  bool _populated = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    final name = _name.text.trim();
    final email = _email.text.trim().toLowerCase();

    if (name == user.name && email == user.email) {
      context.pop();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
            name: name == user.name ? null : name,
            email: email == user.email ? null : email,
          );

      if (!mounted) return;
      context.pop();
      showAppSnackBar(context, 'Dados atualizados.', tone: AppTone.success);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;

    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    if (!_populated) {
      _populated = true;
      _name.text = user.name;
      _email.text = user.email;
    }

    return FormScaffold(
      appBar: AppBar(title: const Text('Meus dados')),
      title: 'Meus dados',
      subtitle:
          'O nome aparece para a equipe. O e-mail é o que você usa para entrar.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Informe seu nome.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _email,
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  helperText: 'Você passa a entrar no app com ele',
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  final valid = value.contains('@') &&
                      value.contains('.') &&
                      !value.endsWith('@');
                  return valid ? null : 'Informe um e-mail válido.';
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (_error != null) FormErrorBanner(message: _error!),
        AppSubmitButton(
          label: 'Salvar',
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
