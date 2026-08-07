import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/position_icon.dart';
import '../../auth/application/auth_controller.dart';
import '../data/team_repository.dart';
import '../domain/team_models.dart';

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider(teamId));
    final myTeam = ref.watch(authControllerProvider).teams.firstOrNull;
    final canManage = myTeam?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipe'),
        actions: [
          // Uma entrada só. Antes eram dois ícones — corrente e igreja — e
          // ninguém adivinha que "corrente" leva a convites. Cada configuração
          // nova acrescentaria mais um ícone mudo aqui.
          if (canManage)
            IconButton(
              tooltip: 'Gerenciar equipe',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/equipe/gerenciar'),
            ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/equipe/membros/novo'),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Adicionar'),
            )
          : null,
      body: SafeArea(
        top: false,
        child: members.when(
        loading: () => const AppLoading(),
        error: (error, _) => AppErrorState(
          message: error is ApiException
              ? error.message
              : 'Não foi possível carregar a equipe.',
          onRetry: () => ref.invalidate(membersProvider(teamId)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.refresh(membersProvider(teamId).future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.55,
                    child: AppEmptyState(
                      icon: Icons.groups_outlined,
                      title: 'Nenhum integrante',
                      message: canManage
                          ? 'Adicione as pessoas da equipe para montar as escalas.'
                          : 'A equipe ainda não tem integrantes cadastrados.',
                      actionLabel: canManage ? 'Adicionar' : null,
                      onAction: canManage
                          ? () => context.push('/equipe/membros/novo')
                          : null,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(membersProvider(teamId).future),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.listPadding,
                AppSpacing.sm,
                AppSpacing.listPadding,
                96,
              ),
              itemCount: list.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _Header(count: list.length);
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _MemberTile(
                    member: list[index - 1],
                    teamId: teamId,
                    canManage: canManage,
                  ),
                );
              },
            ),
          );
        },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Text(
        count == 1 ? '1 integrante' : '$count integrantes',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.member,
    required this.teamId,
    required this.canManage,
  });

  final Member member;
  final String teamId;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      onTap: canManage
          ? () => context.push('/equipe/membros/editar', extra: member)
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        leading: AppAvatar(
          name: member.displayName,
          imageUrl: member.avatarUrl,
        ),
        title: Row(
          children: [
            Flexible(child: Text(member.displayName)),
            if (member.role != 'MEMBER') ...[
              const SizedBox(width: AppSpacing.sm),
              _Tag(label: member.roleLabel, tone: scheme.primary),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Antes era "Vocalista, Violao" em texto corrido. Com o icone na
            // frente de cada uma da para saber o que a pessoa faz sem ler a
            // linha inteira -- que e o que se faz ao procurar alguem na lista.
            if (member.positions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final position in member.positions)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PositionIcon(
                            position.name,
                            category: position.category,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            position.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            if (!member.hasAccount)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Ainda sem conta no app',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        trailing: canManage && !member.isOwner
            ? PopupMenuButton<String>(
                onSelected: (action) => _onAction(context, ref, action),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'remove', child: Text('Remover')),
                ],
              )
            : null,
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    if (action == 'edit') {
      context.push('/equipe/membros/editar', extra: member);
      return;
    }

    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remover ${member.displayName}?'),
        content: const Text(
          'As escalas passadas continuam como estao. As escalas futuras perdem '
          'esta pessoa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(teamRepositoryProvider).removeMember(teamId, member.id);
      ref.invalidate(membersProvider(teamId));
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: tone, fontWeight: FontWeight.w600),
      ),
    );
  }
}
