import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/cache_stamp_banner.dart';
import '../../../shared/widgets/position_icon.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/share_action.dart';
import '../../../shared/widgets/unavailable_badge.dart';
import '../../../shared/widgets/you_highlight.dart';
import '../../auth/application/auth_controller.dart';
import '../data/event_repository.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';
import '../domain/schedule_share_text.dart';
import '../../unavailability/domain/unavailability_models.dart';
import 'duplicate_event_dialog.dart';
import 'event_song_sheet.dart';
import 'event_times.dart';

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
        final myTeam = teams.where((t) => t.teamId == event.teamId).firstOrNull;
        final myMembershipId = myTeam?.membershipId;
        final canManage = myTeam?.canManage ?? false;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Escala'),
            actions: [
              if (!event.isDraft)
                IconButton(
                  tooltip: 'Compartilhar escala',
                  onPressed: () =>
                      shareText(context, buildScheduleShareText(event)),
                  icon: const Icon(Icons.share_outlined),
                ),
              if (canManage)
                PopupMenuButton<String>(
                  tooltip: 'Mais opções desta escala',
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
                      case 'unpublish':
                        await _confirmUnpublish(context, ref, event);
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
                      child: Text('Editar dia e horários'),
                    ),
                    if (FeatureFlags.duplicateSchedule)
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Text('Duplicar escala'),
                      ),
                    if (!event.isDraft)
                      const PopupMenuItem(
                        value: 'unpublish',
                        child: Text('Voltar a rascunho'),
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
            child: AppContentWidth.reading(
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
          ),
          bottomNavigationBar:
              canManage && event.isDraft ? _PublishBar(event: event) : null,
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Event event,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Excluir escala?',
      message: 'A escala de ${event.describe()} será removida para toda a '
          'equipe. Não dá para desfazer.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(eventRepositoryProvider).remove(event.id);
      ref.invalidate(eventsProvider((event.teamId, 'upcoming')));
      ref.invalidate(eventsProvider((event.teamId, 'past')));
      ref.invalidate(eventProvider(event.id));
      if (context.mounted) {
        context.pop();
        showAppSnackBar(context, 'Escala excluída.', tone: AppTone.success);
      }
    } on ApiException catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(context, error.message, tone: AppTone.danger);
    }
  }

  Future<void> _confirmUnpublish(
    BuildContext context,
    WidgetRef ref,
    Event event,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Voltar a rascunho?',
      message: 'A equipe deixa de ver esta escala até você publicá-la de novo.',
      confirmLabel: 'Voltar a rascunho',
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(eventRepositoryProvider).unpublish(event.id);
      ref.invalidate(eventProvider(event.id));
      ref.invalidate(eventsProvider((event.teamId, 'upcoming')));
      ref.invalidate(eventsProvider((event.teamId, 'past')));
      if (context.mounted) {
        showAppSnackBar(
          context,
          'A escala voltou a ser rascunho.',
          tone: AppTone.warning,
        );
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, error.message, tone: AppTone.danger);
      }
    }
  }
}

class _PublishBar extends ConsumerStatefulWidget {
  const _PublishBar({required this.event});

  final Event event;

  @override
  ConsumerState<_PublishBar> createState() => _PublishBarState();
}

class _PublishBarState extends ConsumerState<_PublishBar> {
  bool _publishing = false;

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      await ref.read(eventRepositoryProvider).publish(widget.event.id);
      ref.invalidate(eventProvider(widget.event.id));
      ref.invalidate(eventsProvider((widget.event.teamId, 'upcoming')));
      ref.invalidate(eventsProvider((widget.event.teamId, 'past')));
      if (mounted) {
        showAppSnackBar(
          context,
          'Escala publicada para a equipe.',
          tone: AppTone.success,
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, tone: AppTone.danger);
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pending = widget.event.publicationPendingItems;
    final ready = pending.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        child: AppContentWidth.reading(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppBadge(label: 'Rascunho', tone: AppTone.warning),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        ready
                            ? 'Pronta para a equipe'
                            : 'Falta ${pending.join(' e ')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                FilledButton(
                  onPressed: _publishing ? null : _publish,
                  child: _publishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Publicar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
              // A identidade da escala — data, título, horários, "você" — no
              // mesmo cartão de manchete da agenda. As duas telas mostram a
              // mesma coisa e precisam mostrá-la igual: abrir a escala não deve
              // reapresentar o que a agenda já disse, num formato diferente.
              _EventHeader(
                event: event,
                timezone: timezone,
                youPositions: youPositions,
              ),
              const SizedBox(height: AppSpacing.xl),
              _EventNotes(event: event),
              if (event.warnings.unavailableAssigned.isNotEmpty) ...[
                _UnavailableWarningBand(
                  people: event.warnings.unavailableAssigned,
                  canManage: canManage,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              _TeamSection(event: event, canManage: canManage),
              const SizedBox(height: AppSpacing.xl),
              _SongsSection(event: event, canManage: canManage),
              const SizedBox(height: AppSpacing.xl),
              // Para a equipe inteira, e não dentro do menu de quem lidera:
              // "quem me tirou da escala?" é pergunta de quem foi tirado.
              _HistoryLink(eventId: event.id),
            ],
          ),
        ),
      ],
    );
  }
}

/// Porta do histórico, discreta e no fim da tela: ela não compete com a
/// escala em si, que é o que se abre para ver.
class _HistoryLink extends StatelessWidget {
  const _HistoryLink({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => context.push('/agenda/$eventId/historico'),
        icon: const Icon(Icons.history_rounded, size: 18),
        label: const Text('Histórico de alterações'),
        style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// A manchete da escala: data, título, horários, local e "onde você entra".
///
/// Mesmo cartão e mesma folga do destaque da agenda. Chegou a ficar sem
/// moldura, e a lição foi a mesma dos dois lados: sem fundo, o bloco não se lê
/// como um objeto — parece texto derramado no começo da tela. A hierarquia
/// contra os blocos de baixo (equipe, músicas) vem do corpo da data e da folga
/// interna, não de tirar o chão dele.
class _EventHeader extends StatelessWidget {
  const _EventHeader({
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
    final hasLocation = event.location?.isNotEmpty ?? false;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sem selo de data: ele dizia "DOM 9 AGO" logo ao lado de "Domingo,
          // 9 de agosto". A data por extenso sozinha basta.
          Text(
            formatEventWeekdayDate(event.startsAt, timezone),
            style: theme.textTheme.displaySmall,
          ),
          if (event.hasTitle)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                event.title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          EventTimesList(event: event, timezone: timezone),
          // Fora de etiqueta: um endereço longo não caberia e estouraria a
          // linha. Aqui ele tem a largura toda e corta com "…".
          if (hasLocation) ...[
            const SizedBox(height: AppSpacing.sm),
            _MetaLine(
              icon: Icons.location_on_outlined,
              text: event.location!,
              maxLines: 1,
            ),
          ],
          if (youPositions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: YouHighlight(positionNames: youPositions),
            ),
          ],
        ],
      ),
    );
  }
}

/// Paleta de cores e observações do líder.
///
/// Saíram do cartão de identidade e viraram um bloco próprio: são recados sobre
/// a escala, não o que a escala **é**. Só aparecem quando existem.
class _EventNotes extends StatelessWidget {
  const _EventNotes({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final hasPalette = event.colorPalette?.isNotEmpty ?? false;
    final hasNotes = event.notes?.isNotEmpty ?? false;
    if (!hasPalette && !hasNotes) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: AppCard(
        surface: CardSurface.sunken,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasPalette)
              _MetaLine(
                icon: Icons.palette_outlined,
                text: event.colorPalette!,
                maxLines: 2,
              ),
            if (hasPalette && hasNotes) const SizedBox(height: AppSpacing.sm),
            if (hasNotes)
              _MetaLine(
                icon: Icons.sticky_note_2_outlined,
                text: event.notes!,
                maxLines: 4,
              ),
          ],
        ),
      ),
    );
  }
}

/// Linha de apoio (local, paleta, observações): ícone à esquerda, texto que
/// ocupa o resto da largura.
class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
    required this.maxLines,
  });

  final IconData icon;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
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
    final palette = AppStatusColors.of(context).danger;
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
        color: palette.container,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border(
          left: BorderSide(color: palette.foreground, width: 4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.event_busy_rounded,
            color: palette.onContainer,
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
                    color: palette.onContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (reasons.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    reasons,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.onContainer,
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
                      color: palette.onContainer.withValues(alpha: 0.85),
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

/// Quem toca o quê nesta escala.
///
/// O vazio deixou de ser uma frase mandando procurar: dizia "O líder pode
/// montar a escala pelo menu", num app em que "o menu" são três pontinhos no
/// canto superior. **A ação principal de uma escala recém-criada é escalar a
/// equipe** — ela agora é um botão, no lugar onde a falta é percebida, com a
/// mesma forma do botão de montar o repertório logo abaixo.
class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.event, required this.canManage});

  final Event event;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final empty = event.assignments.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Equipe escalada',
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          trailing: canManage
              ? TextButton.icon(
                  onPressed: () => context.push('/agenda/${event.id}/escalar'),
                  icon: Icon(
                    empty ? Icons.add_rounded : Icons.edit_outlined,
                    size: 18,
                  ),
                  label: Text(empty ? 'Escalar' : 'Editar'),
                )
              : null,
        ),
        if (empty)
          AppCard(
            color: scheme.surfaceContainerLow,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              canManage
                  ? 'Ninguém escalado ainda. Toque em "Escalar" para escolher '
                      'quem toca o quê.'
                  : 'A equipe desta escala ainda não foi definida.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          _AssignedTeamCard(
            groups: event.assignments,
            minister: event.minister,
            unavailable: {
              for (final person in event.unavailable)
                person.membershipId: person.reason,
            },
          ),
      ],
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
    this.minister,
    this.unavailable = const {},
  });

  final List<AssignmentGroup> groups;

  /// Quem conduz a ministração do louvor.
  final EventMinister? minister;

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
          if (minister != null) ...[
            _MinisterBanner(name: minister!.displayName),
            const SizedBox(height: AppSpacing.md),
            Divider(color: scheme.outlineVariant, height: 1),
            const SizedBox(height: AppSpacing.md),
          ],
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

/// Quem conduz a ministracao, no topo da equipe escalada.
///
/// Linha discreta acima das funcoes: e a primeira pergunta de quem abre a
/// escala pensando "quem vai conduzir?". Sem faixa colorida — o peso vem do
/// rotulo e do icone.
class _MinisterBanner extends StatelessWidget {
  const _MinisterBanner({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          Icons.record_voice_over_rounded,
          size: 18,
          color: scheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Ministrante · ',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: name,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
                AppBadge(
                  label: 'fora do cadastro',
                  tone: AppTone.warning,
                  semanticsLabel: '${member.displayName} não tem esta função '
                      'no cadastro da equipe',
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

/// Repertório da escala, com uma seção por culto.
///
/// O cabeçalho do culto aparece sempre, mesmo quando a escala tem um só: é o
/// que faz "3ª música" querer dizer a mesma coisa em toda escala, e é o que
/// impede o vocalista da noite de ensaiar o repertório da manhã.
///
/// O tom aparece ao lado de cada música porque é a informação que o músico
/// procura primeiro. Quando esta escala mudou o tom, ele vem destacado — a
/// mesma canção sobe ou desce conforme quem canta.
class _SongsSection extends StatelessWidget {
  const _SongsSection({required this.event, required this.canManage});

  final Event event;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final timezone =
        event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone;
    final grupos = event.songsByService;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: event.songs.isEmpty
              ? 'Músicas'
              : 'Músicas (${event.songs.length})',
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          trailing: canManage
              ? TextButton.icon(
                  onPressed: () => context.push(
                    '/agenda/${event.id}/repertorio',
                    extra: event,
                  ),
                  icon: Icon(
                    event.songs.isEmpty
                        ? Icons.add_rounded
                        : Icons.edit_outlined,
                    size: 18,
                  ),
                  label: Text(event.songs.isEmpty ? 'Montar' : 'Editar'),
                )
              : null,
        ),
        // Escala inteira sem música: um aviso só. Repetir "sem músicas" em cada
        // culto diria a mesma coisa duas vezes e ocuparia o dobro da tela.
        if (event.songs.isEmpty)
          AppCard(
            color: scheme.surfaceContainerLow,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              canManage
                  ? 'Nenhuma música escolhida ainda. Toque em "Montar" para '
                      'escolher o repertório.'
                  : 'O repertório ainda não foi definido.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < grupos.length; i++) ...[
                  if (i > 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    Divider(color: scheme.outlineVariant, height: 1),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _ServiceSongsSection(
                    teamId: event.teamId,
                    service: grupos[i].service,
                    songs: grupos[i].songs,
                    timezone: timezone,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Um culto e o repertório dele. Mesma forma da seção de função em "Equipe
/// escalada": o rótulo uma vez no topo, os itens listados abaixo.
class _ServiceSongsSection extends StatelessWidget {
  const _ServiceSongsSection({
    required this.teamId,
    required this.service,
    required this.songs,
    required this.timezone,
  });

  final String teamId;
  final EventService service;
  final List<EventSong> songs;
  final String timezone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.church_rounded, size: 15, color: scheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${service.label} '
                '${formatEventTime(service.startsAt, timezone)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ),
            if (songs.length > 1)
              Text(
                '${songs.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        // Culto sem música numa escala que já tem repertório é informação, não
        // vazio: quer dizer que falta montar este aqui.
        if (songs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs, left: 23),
            child: Text(
              'Repertório ainda não montado.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (var i = 0; i < songs.length; i++)
            _SongRow(teamId: teamId, song: songs[i], position: i + 1),
      ],
    );
  }
}

class _SongRow extends StatelessWidget {
  const _SongRow({
    required this.teamId,
    required this.song,
    required this.position,
  });

  final String teamId;
  final EventSong song;
  final int position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasKey = song.key != null && song.key!.isNotEmpty;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      // O que faltava: o vocalista e o instrumentista viam título, tom e
      // recado, mas não alcançavam a cifra nem a letra -- que é justamente o
      // que se procura antes de tocar. Vale para MEMBER, não só para o líder.
      onTap: () => showEventSongSheet(
        context: context,
        teamId: teamId,
        song: song,
      ),
      leading: Text(
        '$position',
        style: theme.textTheme.titleSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
      // A etiqueta fica ao lado do título, e não no `trailing`: ali já está o
      // tom, e dois selos disputando a mesma ponta espremiam os dois numa
      // linha que o nome da música já ocupa.
      title: Row(
        children: [
          Flexible(
            child: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          if (song.isNew) ...[
            const SizedBox(width: AppSpacing.sm),
            const AppBadge(
              label: 'Nova',
              tone: AppTone.info,
              semanticsLabel: 'Música nova: a equipe ainda não tocou esta',
            ),
          ],
        ],
      ),
      subtitle: song.artist == null && song.note == null
          ? null
          : Text(
              [
                if (song.artist != null && song.artist!.isNotEmpty)
                  song.artist!,
                if (song.note != null && song.note!.isNotEmpty) song.note!,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: !hasKey
          ? null
          : AppBadge(
              label: song.key!,
              tone: song.hasCustomKey ? AppTone.primary : AppTone.neutral,
              semanticsLabel: song.hasCustomKey
                  ? 'Tom desta escala: ${song.key}'
                  : 'Tom: ${song.key}',
            ),
    );
  }
}
