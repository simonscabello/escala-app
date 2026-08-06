import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/cache_stamp_banner.dart';
import '../../../shared/widgets/date_badge.dart';
import '../../../shared/widgets/position_icon.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/unavailable_badge.dart';
import '../../../shared/widgets/you_highlight.dart';
import '../../auth/application/auth_controller.dart';
import '../data/event_repository.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';
import '../domain/schedule_share_text.dart';
import '../../unavailability/domain/unavailability_models.dart';
import 'duplicate_event_dialog.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventId));
    final teams = ref.watch(authControllerProvider).teams;

    return eventAsync.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Escala')),
        body: AppErrorState(
          message: error is ApiException
              ? error.message
              : 'Não foi possível carregar a escala.',
          onRetry: () => ref.invalidate(eventProvider(eventId)),
        ),
      ),
      data: (cached) {
        final event = cached.data;
        // Permissao e identidade vem da equipe DO CULTO, nao da primeira da
        // lista: quem participa de mais de uma equipe veria o menu de lider
        // num culto onde e apenas membro.
        final myTeam =
            teams.where((t) => t.teamId == event.teamId).firstOrNull;
        final myMembershipId = myTeam?.membershipId;
        final canManage = myTeam?.canManage ?? false;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Escala'),
            actions: [
              IconButton(
                tooltip: 'Compartilhar escala',
                onPressed: () => SharePlus.instance.share(
                  ShareParams(text: buildScheduleShareText(event)),
                ),
                icon: const Icon(Icons.share_outlined),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'assign':
                        context.push('/agenda/${event.id}/escalar');
                      case 'edit':
                        context.push('/agenda/${event.id}/editar');
                      case 'duplicate':
                        await showDuplicateEventDialog(
                          context: context,
                          ref: ref,
                          source: event,
                        );
                      case 'delete':
                        await _confirmDelete(context, ref, event);
                    }
                  },
                  itemBuilder: (menuContext) => [
                    const PopupMenuItem(
                      value: 'assign',
                      child: Text('Escalar equipe'),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Editar escala'),
                    ),
                    if (FeatureFlags.duplicateSchedule)
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Text('Duplicar escala'),
                      ),
                    // Em vermelho: é a única opção destrutiva do menu e estava
                    // com o mesmo peso visual das outras.
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Excluir escala',
                        style: TextStyle(
                          color: Theme.of(menuContext).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Sem `SafeArea` o fim da lista ficava embaixo dos botoes de
          // navegacao do Android. Esta tela nao tem barra inferior propria,
          // entao ninguem estava consumindo o recuo do sistema.
          body: SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(eventProvider(eventId).future),
              child: _EventDetailBody(
                event: event,
                myMembershipId: myMembershipId,
                canManage: canManage,
                fromCache: cached.fromCache,
                cachedAt: cached.cachedAt,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Event event,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir escala?'),
        content: Text('A escala "${event.title}" será removida.'),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => dialogContext.pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(eventRepositoryProvider).remove(event.id);
      ref.invalidate(eventsProvider((event.teamId, 'upcoming')));
      ref.invalidate(eventsProvider((event.teamId, 'past')));
      ref.invalidate(eventProvider(event.id));
      if (context.mounted) context.pop();
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }
}

class _EventDetailBody extends StatelessWidget {
  const _EventDetailBody({
    required this.event,
    required this.myMembershipId,
    required this.canManage,
    required this.fromCache,
    required this.cachedAt,
  });

  final Event event;
  final String? myMembershipId;
  final bool canManage;
  final bool fromCache;
  final DateTime? cachedAt;

  @override
  Widget build(BuildContext context) {
    final timezone =
        event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final youPositions = event.positionsForMembership(myMembershipId);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        if (fromCache && cachedAt != null)
          CacheStampBanner(cachedAt: cachedAt!),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.xl,
            AppSpacing.screenPadding,
            AppSpacing.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Um cartão só para "o que é esta escala": destaque pessoal,
              // data, título, horários e observações. Antes eram quatro blocos
              // soltos, e a tela parecia uma pilha de avisos sem relação entre
              // si — o cartão diz que tudo ali descreve o mesmo evento.
              _EventSummaryCard(
                event: event,
                timezone: timezone,
                youPositions: youPositions,
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (event.warnings.unavailableAssigned.isNotEmpty) ...[
                _UnavailableWarningBand(
                  people: event.warnings.unavailableAssigned,
                  canManage: canManage,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              const SectionHeader(title: 'Equipe escalada'),
              if (event.assignments.isEmpty)
                Text(
                  'Ninguém escalado ainda. O líder pode montar a escala pelo menu.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                _AssignedTeamCard(
                  groups: event.assignments,
                  unavailable: {
                    for (final person in event.unavailable)
                      person.membershipId: person.reason,
                  },
                ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                color: scheme.surfaceContainerLow,
                child: ListTile(
                  leading: Icon(
                    Icons.music_note_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                  title: Text(
                    'Músicas',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  subtitle: Text(
                    'Em breve — repertório da escala.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Cartão único do topo: destaque pessoal, data, título, horários, local e
/// observações.
///
/// Todos esses blocos respondem à mesma pergunta ("que escala é esta?"), e
/// separados em quatro cartões davam a impressão de quatro assuntos. As
/// divisórias internas continuam separando as partes, sem multiplicar bordas
/// e sombras.
class _EventSummaryCard extends StatelessWidget {
  const _EventSummaryCard({
    required this.event,
    required this.timezone,
    required this.youPositions,
  });

  final Event event;
  final String timezone;
  final List<String> youPositions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasPalette = event.colorPalette?.isNotEmpty ?? false;
    final hasNotes = event.notes?.isNotEmpty ?? false;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (youPositions.isNotEmpty) ...[
            YouAssignmentBanner(positionNames: youPositions),
            const SizedBox(height: AppSpacing.lg),
          ],
          Row(
            children: [
              DateBadge(
                date: event.startsAt,
                timezone: timezone,
                size: DateBadgeSize.large,
                background: scheme.primaryContainer,
                foreground: scheme.onPrimaryContainer,
                muted: scheme.onPrimaryContainer.withValues(alpha: 0.75),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                // Sem repetir a data ao lado do bloco que já a mostra: ela
                // aparecia três vezes seguidas (bloco, linha e cartão).
                child: Text(
                  event.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(color: scheme.outlineVariant, height: 1),
          const SizedBox(height: AppSpacing.lg),
          _ScheduleTimes(
            startsAt: event.startsAt,
            rehearsalAt: event.rehearsalAt,
            location: event.location,
            timezone: timezone,
          ),
          if (hasPalette || hasNotes) ...[
            const SizedBox(height: AppSpacing.lg),
            _PaletteNotesBlock(
              palette: hasPalette ? event.colorPalette : null,
              notes: hasNotes ? event.notes : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleTimes extends StatelessWidget {
  const _ScheduleTimes({
    required this.startsAt,
    required this.rehearsalAt,
    required this.location,
    required this.timezone,
  });

  final DateTime startsAt;
  final DateTime? rehearsalAt;
  final String? location;
  final String timezone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        _DetailItem(
          // Mesmos ícones das pílulas do cartão herói na agenda.
          icon: Icons.church_rounded,
          label: 'Culto',
          value:
              // Só o horário: a data já está no bloco logo acima.
              formatEventTime(startsAt, timezone),
          emphasized: true,
        ),
        if (rehearsalAt != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Divider(color: scheme.outlineVariant, height: 1),
          const SizedBox(height: AppSpacing.lg),
          _DetailItem(
            icon: Icons.music_note_rounded,
            label: 'Ensaio',
            value:
                // O ensaio quase sempre é em outro dia; a data só aparece
                // quando realmente difere da do culto.
                isSameLocalDay(rehearsalAt!, startsAt, timezone)
                    ? formatEventTime(rehearsalAt!, timezone)
                    : '${formatEventWeekdayDate(rehearsalAt!, timezone)} '
                        'às ${formatEventTime(rehearsalAt!, timezone)}',
          ),
        ],
        if (location?.isNotEmpty ?? false) ...[
          const SizedBox(height: AppSpacing.lg),
          Divider(color: scheme.outlineVariant, height: 1),
          const SizedBox(height: AppSpacing.lg),
          _DetailItem(
            icon: Icons.location_on_outlined,
            label: 'Local',
            value: location!,
          ),
        ],
      ],
    );
  }
}

class _PaletteNotesBlock extends StatelessWidget {
  const _PaletteNotesBlock({this.palette, this.notes});

  final String? palette;
  final String? notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        color: scheme.tertiaryContainer.withValues(alpha: 0.45),
        border: Border(
          left: BorderSide(color: scheme.tertiary, width: 4),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (palette != null) ...[
            Row(
              children: [
                Icon(
                  Icons.palette_outlined,
                  size: 18,
                  color: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Paleta',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              palette!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (palette != null && notes != null)
            const SizedBox(height: AppSpacing.md),
          if (notes != null) ...[
            Text(
              'Observações',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(notes!, style: theme.textTheme.bodyLarge),
          ],
        ],
      ),
    );
  }
}

/// Destaque "onde eu apareço" — visível sem rolar.
///
/// Continua existindo como widget nomeado porque é o contrato do teste da
/// Etapa 5; a aparência agora vem do [YouHighlight] compartilhado, para o
/// destaque ser idêntico aqui e na agenda.
class YouAssignmentBanner extends StatelessWidget {
  const YouAssignmentBanner({super.key, required this.positionNames});

  final List<String> positionNames;

  @override
  Widget build(BuildContext context) =>
      YouHighlight(positionNames: positionNames);
}

/// Faixa de alerta quando alguém escalado já tinha avisado que não pode.
///
/// Fica logo acima de "Equipe escalada", e não no topo da tela: assim não
/// disputa atenção com o destaque pessoal ("VOCÊ") e aparece colada na lista
/// de nomes a que se refere.
class _UnavailableWarningBand extends StatelessWidget {
  const _UnavailableWarningBand({
    required this.people,
    required this.canManage,
  });

  final List<UnavailableMember> people;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final names = joinNames(people.map((p) => p.displayName));
    final single = people.length == 1;

    // Motivos só aparecem quando existem; ninguém é obrigado a justificar.
    final reasons = people
        .where((p) => p.reason?.isNotEmpty ?? false)
        .map((p) => '${p.displayName}: ${p.reason}')
        .join(' · ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border(
          left: BorderSide(color: scheme.error, width: 4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.event_busy_rounded,
            color: scheme.onErrorContainer,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  single
                      ? '$names avisou que não pode neste dia'
                      : '$names avisaram que não podem neste dia',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (reasons.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    reasons,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ],
                if (canManage) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    single
                        ? 'Ainda está na escala. Ajuste em "Escalar equipe".'
                        : 'Ainda estão na escala. Ajuste em "Escalar equipe".',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A escala inteira em um cartão, com uma seção por função.
///
/// Um cartão por função gastava a tela toda para mostrar cinco nomes: cada
/// pessoa vinha embrulhada em sombra, borda e margem própria. Aqui a função
/// aparece **uma vez** como cabeçalho e as pessoas dela vêm listadas logo
/// abaixo — inclusive quando são várias, que era o caso em que "Vocalista"
/// acabava escrito duas vezes.
class _AssignedTeamCard extends StatelessWidget {
  const _AssignedTeamCard({
    required this.groups,
    this.unavailable = const {},
  });

  final List<AssignmentGroup> groups;

  /// membershipId -> motivo (ou nulo) de quem avisou que não pode neste dia.
  final Map<String, String?> unavailable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Divider(color: scheme.outlineVariant, height: 1),
              const SizedBox(height: AppSpacing.md),
            ],
            _AssignmentGroupSection(
              group: groups[i],
              unavailable: unavailable,
            ),
          ],
        ],
      ),
    );
  }
}

class _AssignmentGroupSection extends StatelessWidget {
  const _AssignmentGroupSection({
    required this.group,
    required this.unavailable,
  });

  final AssignmentGroup group;
  final Map<String, String?> unavailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Sem `category`: o backend so devolve o nome da funcao no grupo
            // da escala. O mapa de icones resolve pelo nome.
            PositionIcon(
              group.positionName,
              size: 15,
              color: scheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                group.positionName,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ),
            // Com mais de uma pessoa na função, dizer quantas evita ter de
            // contar os avatares.
            if (group.members.length > 1)
              Text(
                '${group.members.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < group.members.length; i++)
          _AssignedMemberRow(
            member: group.members[i],
            unavailableReason: unavailable[group.members[i].membershipId],
            isUnavailable:
                unavailable.containsKey(group.members[i].membershipId),
            isLast: i == group.members.length - 1,
          ),
      ],
    );
  }
}

class _AssignedMemberRow extends StatelessWidget {
  const _AssignedMemberRow({
    required this.member,
    required this.unavailableReason,
    required this.isUnavailable,
    required this.isLast,
  });

  final AssignmentMember member;
  final String? unavailableReason;
  final bool isUnavailable;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasNote = member.note?.isNotEmpty ?? false;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: member.displayName, radius: 14),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  member.displayName,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              // A etiqueta ao lado do nome diz *quem*; a faixa acima diz que
              // há um problema. Uma sem a outra obriga a procurar.
              if (isUnavailable)
                UnavailableBadge(reason: unavailableReason)
              else if (!member.isRegisteredForPosition)
                Text(
                  'fora do cadastro',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.tertiary,
                  ),
                ),
            ],
          ),
          if (hasNote)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 2),
              child: Text(
                member.note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: emphasized ? scheme.primary : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: (emphasized
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.bodyLarge)
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
