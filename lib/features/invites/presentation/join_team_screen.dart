import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_submit_button.dart';
import '../../../shared/widgets/form_scaffold.dart';
import '../../auth/application/auth_controller.dart';
import '../data/invite_repository.dart';
import '../domain/invite_models.dart';

String cleanInviteCode(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

/// Entrada por código ou por link público. O link abre esta mesma tela já com
/// o código preenchido; sem conta, a pessoa vê a equipe antes de entrar.
class JoinTeamScreen extends ConsumerStatefulWidget {
  const JoinTeamScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends ConsumerState<JoinTeamScreen> {
  final _code = TextEditingController();

  InvitePreview? _preview;
  bool _checking = false;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _code.text = widget.initialCode ?? '';
    _code.addListener(_onCodeChanged);
    if (cleanInviteCode(_code.text).length == 20) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  @override
  void dispose() {
    _code.removeListener(_onCodeChanged);
    _code.dispose();
    super.dispose();
  }

  /// O código tem 20 caracteres uteis; assim que completa, buscamos o preview
  /// sozinhos -- a pessoa não precisa apertar nada para saber se acertou.
  void _onCodeChanged() {
    final clean = cleanInviteCode(_code.text);
    if (clean.length == 20 && _preview == null && !_checking) {
      _check();
    } else if (clean.length < 20 && _preview != null) {
      setState(() {
        _preview = null;
        _error = null;
      });
    }
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final preview =
          await ref
              .read(inviteRepositoryProvider)
              .preview(cleanInviteCode(_code.text));
      if (mounted) setState(() => _preview = preview);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      final result =
          await ref
              .read(inviteRepositoryProvider)
              .accept(cleanInviteCode(_code.text));
      await ref.read(authControllerProvider.notifier).reloadTeams();

      if (!mounted) return;
      context.go('/home');
      showAppSnackBar(
        context,
        result.joined
            ? 'Pronto! Você entrou em ${result.teamName}.'
            : 'Você já fazia parte de ${result.teamName}.',
        tone: result.joined ? AppTone.success : AppTone.info,
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    // Ler a area de transferencia falha em parte dos navegadores (o Firefox
    // nao expoe `readText`, e o Safari exige gesto proprio). No Android nunca
    // falhou; na Web, sem este `try`, o botao "Colar" quebrava em silencio.
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {
      data = null;
    }

    final text = data?.text;
    if (text == null) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Seu navegador não deixou ler a área de transferência. Cole o '
          'código no campo.',
          tone: AppTone.warning,
        );
      }
      return;
    }

    // Aceita o texto inteiro compartilhado no WhatsApp: extraimos o código.
    final match = RegExp(r'[0-9A-HJKMNP-TV-Z]{5}(?:-[0-9A-HJKMNP-TV-Z]{5}){3}')
        .firstMatch(text.toUpperCase());

    _code.text = match?.group(0) ?? text.trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _checking || _joining;
    final authenticated =
        ref.watch(authControllerProvider).status == AuthStatus.authenticated;
    final code = cleanInviteCode(_code.text);

    return FormScaffold(
      appBar: AppBar(title: const Text('Convite')),
      title: 'Entrar com convite',
      subtitle: 'Cole o código que o líder da sua equipe enviou.',
      children: [
        TextField(
          controller: _code,
          decoration: InputDecoration(
            labelText: 'Código do convite',
            hintText: 'ABCDE-FGHIJ-KLMNO-PQRST',
            suffixIcon: IconButton(
              tooltip: 'Colar',
              icon: const Icon(Icons.content_paste_rounded),
              onPressed: busy ? null : _pasteFromClipboard,
            ),
          ),
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enabled: !busy,
          style: theme.textTheme.titleMedium?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_checking)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          )
        else if (_preview != null)
          _PreviewCard(preview: _preview!),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          FormErrorBanner(message: _error!),
        ],
        const SizedBox(height: AppSpacing.md),
        AppSubmitButton(
          label: authenticated ? 'Entrar na equipe' : 'Entrar para aceitar',
          loading: _joining,
          loadingLabel: 'Entrando na equipe',
          onPressed: _preview == null || busy
              ? null
              : authenticated
                  ? _join
                  : () => context.go('/login?convite=$code'),
        ),
        if (!authenticated && _preview != null)
          TextButton(
            onPressed:
                busy ? null : () => context.go('/cadastro?convite=$code'),
            child: const Text('Não tenho conta. Criar agora'),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'O código tem 20 caracteres. Maiúsculas, minúsculas e hífens tanto '
          'faz.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final InvitePreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // `AppCard` e não o `Card` do Material: era o último lugar do app com um
    // cartão de outra família -- outro raio, outra borda, outra sombra.
    return AppCard(
      color: scheme.primaryContainer,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  preview.teamName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            [
              if (preview.invitedBy != null)
                'Convite enviado por ${preview.invitedBy}.',
              if (preview.invitedName != null)
                'Você entrará como ${preview.invitedName}, com as funções '
                    'que já foram cadastradas para você.',
            ].join(' '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
