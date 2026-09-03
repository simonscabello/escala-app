import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/responsive/app_breakpoints.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../core/theme/app_typography.dart';
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
import '../../invites/presentation/invite_actions.dart';
import '../../suggestions/data/suggestion_repository.dart';
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
    final wide = AppBreakpoints.of(context).isWide;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipe'),
        actions: [
          // Uma entrada só. Antes eram dois ícones — corrente e igreja — e
          // ninguém adivinha que "corrente" leva a convites. Cada configuração
          // nova acrescentaria mais um ícone mudo aqui.
          //
          // No monitor ele sai: a barra lateral já lista "Gerenciar equipe" com
          // nome escrito, e duas portas para o mesmo lugar na mesma tela é uma
          // a mais.
          if (canManage && !wide)
            IconButton(
              tooltip: 'Gerenciar equipe',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/equipe/gerenciar'),
            ),
          if (canManage && wide)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: FilledButton.icon(
                onPressed: () => context.push('/equipe/membros/novo'),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Adicionar integrante'),
              ),
            ),
        ],
      ),
      // Mesma razão da agenda: o botão flutuante é o canto que o polegar
      // alcança. Com mouse, a ação principal vai para o cabeçalho.
      floatingActionButton: canManage && !wide
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/equipe/membros/novo'),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Adicionar'),
            )
          : null,
      body: SafeArea(
        top: false,
        child: AppContentWidth.wide(
          child: members.when(
            loading: () =>
                const AppListSkeleton(itemCount: 5, leadingBlock: true),
            error: (error, _) => AppErrorState(
              message: error is ApiException
                  ? error.message
                  : 'Não foi possível carregar a equipe.',
              onRetry: () => ref.invalidate(membersProvider(teamId)),
            ),
            data: (list) => LayoutBuilder(
              builder: (context, constraints) => RefreshIndicator(
                onRefresh: () async =>
                    ref.refresh(membersProvider(teamId).future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.listPadding,
                    AppSpacing.lg,
                    AppSpacing.listPadding,
                    wide ? AppSpacing.xxl : 96,
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
                        // Ao lado do repertório e para todo mundo, pelo mesmo
                        // motivo dele: quem sugere é a equipe inteira, e quem
                        // sugeriu precisa ver o que aconteceu.
                        AppGroupRow(
                          icon: Icons.lightbulb_outline_rounded,
                          title: 'Sugestões',
                          subtitle:
                              'Músicas que a equipe pediu, e por quê',
                          trailing: canManage
                              ? _SuggestionCountBadge(teamId: teamId)
                              : null,
                          onTap: () => context.push('/equipe/sugestoes'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    if (list.isEmpty) ...[
                      const SectionHeader(title: 'Integrantes'),
                      _NoMembers(canManage: canManage),
                    ] else if (constraints.maxWidth >= 860)
                      // A largura da **lista**, e não a da janela: com a barra
                      // lateral aberta um monitor de 1024px deixa ~700px aqui,
                      // e as quatro colunas da tabela precisam de 860 para não
                      // se espremerem. Abaixo disso a mesma equipe volta a ser
                      // a lista do celular, que continua correta.
                      _MembersTable(
                        members: list,
                        teamId: teamId,
                        canManage: canManage,
                      )
                    else
                      // Uma superfície para a equipe inteira, e não um cartão
                      // por pessoa. Doze integrantes viravam doze retângulos
                      // com borda e margem própria: a tela parecia um mural de
                      // fichas soltas, quando o que existe ali é **uma** lista.
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
      ),
    );
  }
}

/// A equipe como tabela, onde há largura para isso.
///
/// **É a mesma lista, com as colunas alinhadas.** No celular cada pessoa é um
/// bloco que se lê inteiro antes de passar ao próximo; num monitor, com doze
/// integrantes, a pergunta muda: "quem toca guitarra?", "quem ainda não tem
/// conta?". Essas se respondem varrendo uma coluna, e para isso os campos
/// precisam começar sempre no mesmo x. Nenhum campo novo entrou — são os
/// mesmos do cartão, postos lado a lado.
class _MembersTable extends StatelessWidget {
  const _MembersTable({
    required this.members,
    required this.teamId,
    required this.canManage,
  });

  final List<Member> members;
  final String teamId;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Integrantes',
          trailing: AppBadge(
            label: '${members.length}',
            semanticsLabel: members.length == 1
                ? '1 integrante'
                : '${members.length} integrantes',
          ),
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.md,
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: scheme.surfaceContainerLow,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 260,
                      child:
                          Text('Pessoa', style: AppTypography.eyebrow(context)),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Text(
                        'Funções',
                        style: AppTypography.eyebrow(context),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    SizedBox(
                      width: 150,
                      child:
                          Text('Conta', style: AppTypography.eyebrow(context)),
                    ),
                    // Largura do menu, para o cabeçalho não desalinhar das
                    // linhas que o têm.
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              for (var i = 0; i < members.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: scheme.outlineVariant,
                  ),
                _MemberTableRow(
                  member: members[i],
                  teamId: teamId,
                  canManage: canManage,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberTableRow extends ConsumerWidget {
  const _MemberTableRow({
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
      // Sem `hoverColor` o mouse não recebe resposta nenhuma numa linha que é
      // clicável — no toque o respingo basta, com cursor não.
      hoverColor: scheme.onSurface.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 260,
              child: Row(
                children: [
                  AppAvatar(
                    name: member.displayName,
                    imageUrl: member.avatarUrl,
                    radius: 18,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
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
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: member.positions.isEmpty
                  ? Text(
                      'Sem função definida',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final position in member.positions)
                          _PositionLabel(position: position),
                      ],
                    ),
            ),
            const SizedBox(width: AppSpacing.lg),
            SizedBox(
              width: 150,
              child: member.hasAccount
                  ? Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 15,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Tem conta',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : const AppBadge(
                      label: 'Sem conta',
                      tone: AppTone.warning,
                    ),
            ),
            SizedBox(
              width: 48,
              child: canManage && !member.isOwner
                  ? _MemberMenu(member: member, teamId: teamId)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionLabel extends StatelessWidget {
  const _PositionLabel({required this.position});

  final Position position;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PositionIcon(position.name, category: position.category, size: 12),
        const SizedBox(width: 5),
        Text(position.name, style: Theme.of(context).textTheme.bodySmall),
      ],
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
                      _PositionLabel(position: position),
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
            ? _MemberMenu(member: member, teamId: teamId)
            : null,
      ),
    );
  }
}

/// Editar, convidar e remover — o mesmo menu nas duas arrumações.
class _MemberMenu extends ConsumerWidget {
  const _MemberMenu({required this.member, required this.teamId});

  final Member member;
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Opções de ${member.displayName}',
      onSelected: (action) => _onAction(context, ref, action),
      itemBuilder: (menuContext) => [
        const PopupMenuItem(value: 'edit', child: Text('Editar')),
        // Só para quem ainda não tem conta: é a linha em que o líder percebe
        // que falta convidar, e até aqui o caminho era sair desta lista e
        // procurar "Convites" nas configurações.
        if (!member.hasAccount)
          const PopupMenuItem(value: 'invite', child: Text('Convidar')),
        PopupMenuItem(
          value: 'remove',
          child: Text(
            'Remover da equipe',
            style: TextStyle(color: Theme.of(menuContext).colorScheme.error),
          ),
        ),
      ],
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

    if (action == 'invite') {
      await copyIndividualInvite(
        context,
        ref,
        teamId: teamId,
        membershipId: member.id,
        displayName: member.displayName,
      );
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

/// Quantas sugestões estão de pé, na linha do menu.
///
/// **Sem push no projeto, é por este número que o líder descobre que alguém
/// sugeriu alguma coisa** — sugestão que ninguém vê é sugestão que ninguém faz
/// duas vezes. Só para quem pode responder: para o integrante, uma contagem
/// que ele não pode resolver seria enfeite.
///
/// Falha ou carregamento não desenham nada: a linha existe e funciona sem o
/// selo, e um erro aqui não pode virar um "!" vermelho no menu da equipe.
class _SuggestionCountBadge extends ConsumerWidget {
  const _SuggestionCountBadge({required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abertas = ref.watch(openSuggestionCountProvider(teamId));

    return abertas.maybeWhen(
      data: (total) => total == 0
          ? const SizedBox.shrink()
          : AppBadge(
              label: '$total',
              tone: AppTone.primary,
              emphasis: BadgeEmphasis.solid,
              semanticsLabel: total == 1
                  ? '1 sugestao aguardando resposta'
                  : '$total sugestoes aguardando resposta',
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
