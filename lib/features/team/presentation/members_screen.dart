import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_group.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/position_icon.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../data/team_repository.dart';
import '../domain/team_models.dart';

/// A aba Equipe: as músicas da equipe e as pessoas da equipe.
///
/// O repertório abre a tela e é **visível para todo mundo**. Ele vivia dentro
/// de "Gerenciar equipe", atrás do ícone de engrenagem que só aparece para
/// líderes — de modo que o integrante que precisa achar a cifra antes do ensaio
/// não tinha caminho nenhum até ela. Quem lidera continua sendo o único que
/// escreve; isso é decidido lá dentro, e não escondendo a porta.
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider(teamId));
    final myTeam = ref
            .watch(authControllerProvider)
            .teams
            .where((t) => t.teamId == teamId)
            .firstOrNull ??
        ref.watch(authControllerProvider).teams.firstOrNull;
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
        child: AppContentWidth(
          child: members.when(
            loading: () => const AppListSkeleton(itemCount: 5, leadingBlock: true),
            error: (error, _) => AppErrorState(
              message: error is ApiException
                  ? error.message
                  : 'Não foi possível carregar a equipe.',
              onRetry: () => ref.invalidate(membersProvider(teamId)),
            ),
            data: (list) => RefreshIndicator(
              onRefresh: () async => ref.refresh(membersProvider(teamId).future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.listPadding,
                  AppSpacing.lg,
                  AppSpacing.listPadding,
                  96,
                ),
                children: [
                  AppGroup(
                    children: [
                      AppGroupRow(
                        icon: Icons.library_music_outlined,
                        title: 'Repertório',
                        subtitle:
                            'As músicas da equipe, com letra, cifra e tom',
                        onTap: () => context.push('/equipe/musicas'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (list.isEmpty) ...[
                    const SectionHeader(title: 'Integrantes'),
                    _NoMembers(canManage: canManage),
                  ] else
                    // Uma superfície para a equipe inteira, e não um cartão por
                    // pessoa. Doze integrantes viravam doze retângulos com
                    // borda e margem própria: a tela parecia um mural de fichas
                    // soltas, quando o que existe ali é **uma** lista.
                    AppGroup(
                      title: 'Integrantes',
                      dividerIndent: AppSpacing.lg + 40 + AppSpacing.md,
                      trailing: AppBadge(
                        label: '${list.length}',
                        semanticsLabel: list.length == 1
                            ? '1 integrante'
                            : '${list.length} integrantes',
                      ),
                      children: [
                        for (final member in list)
                          _MemberRow(
                            member: member,
                            teamId: teamId,
                            canManage: canManage,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Equipe sem ninguém cadastrado.
///
/// Fica dentro da lista, e não ocupando a tela: acima dele continua havendo o
/// repertório, que é conteúdo de verdade. Um vazio de tela cheia aqui esconderia
/// uma parte funcional da aba.
class _NoMembers extends StatelessWidget {
  const _NoMembers({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      surface: CardSurface.sunken,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            canManage
                ? 'Ninguém cadastrado ainda'
                : 'A equipe ainda não tem integrantes',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            canManage
                ? 'Cadastre as pessoas para poder montar as escalas. Elas não '
                    'precisam ter conta no app.'
                : 'Quando o líder cadastrar as pessoas, elas aparecem aqui.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (canManage) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.push('/equipe/membros/novo'),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Adicionar integrante'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Uma pessoa, como linha do grupo.
class _MemberRow extends ConsumerWidget {
  const _MemberRow({
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

    return InkWell(
      onTap: canManage
          ? () => context.push('/equipe/membros/editar', extra: member)
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        leading: AppAvatar(
          name: member.displayName,
          imageUrl: member.avatarUrl,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                member.displayName,
                style: theme.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (member.role != 'MEMBER') ...[
              const SizedBox(width: AppSpacing.sm),
              AppBadge(label: member.roleLabel, tone: AppTone.primary),
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
                padding: const EdgeInsets.only(top: 3),
                child: Wrap(
                  spacing: AppSpacing.md,
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
                          const SizedBox(width: 5),
                          Text(
                            position.name,
                            style: theme.textTheme.bodySmall,
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
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        trailing: canManage && !member.isOwner
            ? PopupMenuButton<String>(
                tooltip: 'Opções de ${member.displayName}',
                onSelected: (action) => _onAction(context, ref, action),
                itemBuilder: (menuContext) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(
                      'Remover da equipe',
                      style: TextStyle(
                        color: Theme.of(menuContext).colorScheme.error,
                      ),
                    ),
                  ),
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

    final confirmed = await showConfirmDialog(
      context,
      title: 'Remover ${member.displayName}?',
      message: 'As escalas passadas continuam como estão. As escalas futuras '
          'perdem esta pessoa.',
      confirmLabel: 'Remover',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(teamRepositoryProvider).removeMember(teamId, member.id);
      ref.invalidate(membersProvider(teamId));
      if (context.mounted) {
        showAppSnackBar(
          context,
          '${member.displayName} saiu da equipe.',
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
