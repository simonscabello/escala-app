import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/section_header.dart';
import '../../team/data/team_repository.dart';
import '../../team/domain/team_models.dart';
import '../data/invite_repository.dart';
import '../domain/invite_models.dart';

/// Tela do líder: gera o convite geral da equipe e um convite individual por
/// membro que ainda não tem conta.
///
/// Esta era a tela mais atrasada do app, e por motivos concretos: usava `Card`
/// cru em vez do cartão do app, mostrava `Text('$e')` — a exceção do Dart, com
/// pilha e tudo — quando a lista de integrantes falhava, e **apagava um convite
/// no primeiro toque**, sem perguntar, num ícone de lixeira ao lado do botão de
/// copiar.
///
/// O código também era só mais uma linha de texto. Ele é o produto desta tela:
/// agora tem tamanho, espaçamento de leitura e um botão de largura inteira,
/// porque o que se faz aqui é copiar e colar no grupo do WhatsApp.
class InvitesScreen extends ConsumerWidget {
  const InvitesScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(invitesProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('Convites')),
      // Sem a barra inferior nesta rota, ninguem consome o recuo dos botoes de
      // navegacao do Android -- o fim da lista ficava por baixo deles.
      body: SafeArea(
        top: false,
        child: AppContentWidth.reading(
          child: invites.when(
            loading: () => const AppListSkeleton(itemCount: 3),
            error: (error, _) => AppErrorState(
              message: error is ApiException
                  ? error.message
                  : 'Não foi possível carregar os convites.',
              onRetry: () => ref.invalidate(invitesProvider(teamId)),
            ),
            data: (list) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(invitesProvider(teamId));
                ref.invalidate(membersProvider(teamId));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                children: [
                  const SectionHeader(
                    title: 'Convite geral',
                    subtitle: 'Qualquer pessoa com este código entra na '
                        'equipe como membro.',
                  ),
                  ...list.where((invite) => !invite.isIndividual).map(
                        (invite) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _InviteCard(invite: invite, teamId: teamId),
                        ),
                      ),
                  _GenerateButton(
                    teamId: teamId,
                    label: list.any((invite) => !invite.isIndividual)
                        ? 'Gerar outro código'
                        : 'Gerar convite geral',
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  const SectionHeader(
                    title: 'Convites individuais',
                    subtitle: 'Quem aceitar assume o cadastro que você já '
                        'criou, com as funções preenchidas.',
                  ),
                  _IndividualSection(teamId: teamId, invites: list),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IndividualSection extends ConsumerWidget {
  const _IndividualSection({required this.teamId, required this.invites});

  final String teamId;
  final List<Invite> invites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider(teamId));

    return members.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
      // Antes: `Text('$e')`. A pessoa recebia o objeto de exceção do Dart na
      // tela, sem nada a fazer com ele.
      error: (error, _) => _InlineNotice(
        icon: Icons.error_outline_rounded,
        tone: AppTone.danger,
        title: 'Não foi possível carregar os integrantes',
        message: error is ApiException
            ? error.message
            : 'Puxe a tela para baixo para tentar de novo.',
      ),
      data: (all) {
        final pending = all.where((m) => !m.hasAccount).toList();

        if (pending.isEmpty) {
          return const _InlineNotice(
            icon: Icons.check_circle_outline_rounded,
            tone: AppTone.success,
            title: 'Todo mundo já tem conta',
            message: 'Nenhum convite individual pendente.',
          );
        }

        return Column(
          children: [
            for (final member in pending)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _IndividualRow(
                  teamId: teamId,
                  member: member,
                  invite: invites
                      .where((i) => i.forMembershipId == member.id)
                      .firstOrNull,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _IndividualRow extends ConsumerWidget {
  const _IndividualRow({
    required this.teamId,
    required this.member,
    required this.invite,
  });

  final String teamId;
  final Member member;
  final Invite? invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (invite != null) {
      return _InviteCard(
        invite: invite!,
        teamId: teamId,
        title: member.displayName,
      );
    }

    final theme = Theme.of(context);

    return AppCard(
      surface: CardSurface.sunken,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Text(member.displayName, style: theme.textTheme.titleSmall),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.tonal(
            onPressed: () => _generate(context, ref),
            child: const Text('Convidar'),
          ),
        ],
      ),
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(inviteRepositoryProvider)
          .create(teamId, membershipId: member.id);
      ref.invalidate(invitesProvider(teamId));
      if (context.mounted) {
        showAppSnackBar(
          context,
          'Convite de ${member.displayName} gerado.',
          tone: AppTone.success,
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        showAppSnackBar(context, e.message, tone: AppTone.danger);
      }
    }
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard({
    required this.invite,
    required this.teamId,
    this.title,
  });

  final Invite invite;
  final String teamId;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final expires = DateFormat("d 'de' MMMM", 'pt_BR').format(invite.expiresAt);
    final expiringSoon =
        invite.expiresAt.difference(DateTime.now()).inDays <= 2;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title!, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.md),
          ],
          // O código é o produto desta tela. Numa caixa própria, grande e com
          // espaçamento de leitura -- quem digita à mão precisa distinguir
          // caractere por caractere, e antes ele era uma linha de texto entre
          // outras.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: SelectableText(
              invite.formattedCode,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFamily: 'monospace',
                letterSpacing: 3,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              AppBadge(
                icon: Icons.schedule_rounded,
                label: 'Vale até $expires',
                tone: expiringSoon ? AppTone.warning : AppTone.neutral,
                semanticsLabel: expiringSoon
                    ? 'Atenção: este convite vence em $expires'
                    : 'Vale até $expires',
              ),
              if (invite.maxUses != null) ...[
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: '${invite.uses} de ${invite.maxUses} usos',
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Copiar ocupa a largura toda: é o que se faz aqui em 99 de 100
          // visitas. Cancelar virou texto discreto abaixo — era um ícone de
          // lixeira encostado no botão de copiar, e apagava sem perguntar.
          FilledButton.icon(
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar convite'),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: () => _revoke(context, ref),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('Cancelar este convite'),
          ),
        ],
      ),
    );
  }

  /// Copia a mensagem pronta para colar no grupo do WhatsApp -- e assim que a
  /// equipe vai receber o convite na pratica.
  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: invite.shareMessage));

    if (context.mounted) {
      showAppSnackBar(
        context,
        'Convite copiado. É só colar no WhatsApp.',
        tone: AppTone.success,
      );
    }
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancelar este convite?',
      message: 'O código para de funcionar na hora. Quem já entrou com ele '
          'continua na equipe.',
      confirmLabel: 'Cancelar convite',
      cancelLabel: 'Voltar',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(inviteRepositoryProvider).revoke(teamId, invite.id);
      ref.invalidate(invitesProvider(teamId));
      if (context.mounted) {
        showAppSnackBar(
          context,
          'Convite cancelado.',
          tone: AppTone.success,
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        showAppSnackBar(context, e.message, tone: AppTone.danger);
      }
    }
  }
}

class _GenerateButton extends ConsumerStatefulWidget {
  const _GenerateButton({required this.teamId, required this.label});

  final String teamId;
  final String label;

  @override
  ConsumerState<_GenerateButton> createState() => _GenerateButtonState();
}

class _GenerateButtonState extends ConsumerState<_GenerateButton> {
  bool _loading = false;

  Future<void> _generate() async {
    setState(() => _loading = true);

    try {
      await ref.read(inviteRepositoryProvider).create(widget.teamId);
      ref.invalidate(invitesProvider(widget.teamId));
      if (mounted) {
        showAppSnackBar(
          context,
          'Código gerado.',
          tone: AppTone.success,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        showAppSnackBar(context, e.message, tone: AppTone.danger);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : _generate,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add_rounded, size: 18),
      label: Text(widget.label),
    );
  }
}

/// Aviso curto dentro do fluxo da tela: sem ação, só contando o estado.
class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.tone,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final AppTone tone;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppStatusColors.of(context).resolve(
      tone,
      theme.colorScheme,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.container,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: palette.onContainer),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: palette.onContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.onContainer.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
