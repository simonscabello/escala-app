import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_brand_mark.dart';
import '../application/auth_controller.dart';
import 'login_screen.dart';

/// O fundo do pedido de biometria, com a sessão guardada e bloqueada.
///
/// **Existe porque a tela de login parecia defeito.** O pedido de digital
/// abria por cima do formulário de e-mail e senha, e quem tinha acabado de
/// abrir o app lia aquilo como "fui deslogado". Aqui o fundo é a própria
/// splash — mesma cor, mesma marca —, então abrir o app, confirmar a digital
/// e ver a Home parece uma sequência só.
///
/// O pedido sai sozinho ao abrir. Cancelado, a tela oferece as duas saídas:
/// tentar de novo ou entrar com a senha (que continua oferecendo a biometria,
/// enquanto a sessão estiver guardada).
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  /// Começa verdadeiro: até o pedido abrir, a tela é a splash — sem botão que
  /// apareça por um instante e suma debaixo do diálogo.
  bool _unlocking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = ref.read(authControllerProvider.notifier);
      if (!await auth.biometricsAvailable) {
        // Digitais removidas depois de ligar a biometria: não há o que pedir.
        if (mounted) context.go('/login');
        return;
      }
      if (mounted) await _unlock();
    });
  }

  Future<void> _unlock() async {
    setState(() {
      _unlocking = true;
      _error = null;
    });
    // Lido antes do `await`: quando a sessão expira, o roteador desmonta esta
    // tela antes de o resultado voltar, e `ref` de widget desmontado lança.
    final notice = ref.read(loginNoticeProvider.notifier);
    final result =
        await ref.read(authControllerProvider.notifier).unlockWithBiometrics();
    if (result == BiometricUnlock.expired) {
      // A sessão já foi descartada e o roteador está levando para o login;
      // o motivo vai junto para não parecer que o app deslogou sozinho.
      notice.state = 'Sua sessão expirou. Entre com seu e-mail e senha.';
      return;
    }
    if (!mounted) return;
    setState(() {
      _unlocking = false;
      _error = result == BiometricUnlock.offline
          ? 'Não foi possível conectar ao servidor. Tente de novo ou entre com e-mail e senha.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandDeepViolet,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: AppBrandGlyph(size: 96, onDark: true),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'PAUTA',
                    textAlign: TextAlign.center,
                    style: AppTypography.wordmark(
                      context,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _unlocking
                        ? 'Sua equipe no mesmo ritmo.'
                        : 'Confirme que é você para continuar.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.brandLavender,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (_unlocking)
                    const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                          backgroundColor: Color(0x4DFFFFFF),
                        ),
                      ),
                    )
                  else ...[
                    if (_error != null) ...[
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.brandDeepViolet,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _unlock,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Entrar com biometria'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => context.go('/login'),
                      child: const Text('Usar e-mail e senha'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
