import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_states.dart';
import '../../team/data/team_repository.dart';
import '../../team/domain/team_models.dart';
import '../data/invite_repository.dart';
import '../domain/invite_models.dart';

/// Tela do líder: gera o convite geral da equipe e um convite individual por
/// membro que ainda não tem conta.
class InvitesScreen extends ConsumerWidget {
  const InvitesScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(invitesProvider(teamId));
    final members = ref.watch(membersProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('Convites')),
      body: invites.when(
        loading: () => const AppLoading(),
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
            padding: const EdgeInsets.all(AppSpacing.listPadding),
            children: [
              const _SectionTitle('Convite geral'),
              Text(
                'Qualquer pessoa com este código entra na equipe como membro.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...list
                  .where((invite) => !invite.isIndividual)
                  .map((invite) => _InviteCard(invite: invite, teamId: teamId)),
              _GenerateButton(
                teamId: teamId,
                label: 'Gerar convite geral',
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _SectionTitle('Convites individuais'),
              Text(
                'Quem aceitar assume o cadastro que você já criou, com as '
                'funções preenchidas.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              members.when(
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
                error: (e, _) => Text('$e'),
                data: (all) => _IndividualSection(
                  teamId: teamId,
                  pending: all.where((m) => !m.hasAccount).toList(),
                  invites: list.where((invite) => invite.isIndividual).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IndividualSection extends ConsumerWidget {
  const _IndividualSection({
    required this.teamId,
    required this.pending,
    required this.invites,
  });

  final String teamId;
  final List<Member> pending;
  final List<Invite> invites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pending.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.check_circle_outline),
          title: Text('Todo mundo já tem conta'),
          subtitle: Text('Nenhum convite individual pendente.'),
        ),
      );
    }

    return Column(
      children: [
        for (final member in pending)
          Builder(
            builder: (context) {
              final invite = invites
                  .where((i) => i.forMembershipId == member.id)
                  .firstOrNull;

              if (invite != null) {
                return _InviteCard(
                  invite: invite,
                  teamId: teamId,
                  title: member.displayName,
                );
              }

              return Card(
                child: ListTile(
                  title: Text(member.displayName),
                  subtitle: const Text('Sem convite gerado'),
                  trailing: FilledButton.tonal(
                    onPressed: () => _generate(context, ref, member.id),
                    child: const Text('Convidar'),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _generate(
    BuildContext context,
    WidgetRef ref,
    String membershipId,
  ) async {
    try {
      await ref
          .read(inviteRepositoryProvider)
          .create(teamId, membershipId: membershipId);
      ref.invalidate(invitesProvider(teamId));
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
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
    final expires = DateFormat("d 'de' MMMM", 'pt_BR').format(invite.expiresAt);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
            ],
            SelectableText(
              invite.formattedCode,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'monospace',
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Vale até $expires'
              '${invite.maxUses != null ? ' - ${invite.uses}/${invite.maxUses} usos' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copiar convite'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Cancelar convite',
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: () => _revoke(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Copia a mensagem pronta para colar no grupo do WhatsApp -- e assim que a
  /// equipe vai receber o convite na pratica.
  Future<void> _copy(BuildContext context) async {
    final message = [
      'Você foi convidado para a nossa equipe de louvor.',
      '',
      'Código: ${invite.formattedCode}',
      if (invite.url != null) invite.url!,
      '',
      'Abra o app, toque em "Recebi um convite" e cole o código.',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: message));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Convite copiado. Cole no WhatsApp.')),
      );
    }
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(inviteRepositoryProvider).revoke(teamId, invite.id);
      ref.invalidate(invitesProvider(teamId));
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
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
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : _generate,
      icon: const Icon(Icons.add_link),
      label: Text(widget.label),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
