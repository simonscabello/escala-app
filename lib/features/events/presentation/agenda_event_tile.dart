import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_date_badge.dart';
import '../../../shared/widgets/app_pressable.dart';
import '../../../shared/widgets/you_highlight.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';
import '../domain/open_date.dart';
import 'duplicate_event_dialog.dart';
import 'event_schedule_facts.dart';

/// Uma escala como linha de lista.
///
/// **Linha, e não cartão.** Uma agenda em que cada data é um cartão com sua
/// moldura e sua sombra vira uma pilha de caixinhas: o olho para em cada
/// fronteira e a lista deixa de ser varrida. Aqui a superfície é do grupo (ver
/// `AppGroup`) e a separação é um fio — o que permite ler oito datas de relance,
/// que é o que a tela precisa entregar depois da manchete.
///
/// **O bloco de data abre a linha.** Ele é a coluna fixa que dá prumo à lista:
/// o número sempre no mesmo lugar, e o título sempre começando na mesma
/// margem. A data por extenso continua ao lado, porque "13" sozinho não diz
/// domingo nem setembro.
///
/// **Duas arrumações, o mesmo conteúdo.** No celular tudo se empilha à direita
/// do bloco: é a única forma de caber em 375px. Onde há largura, a mesma linha
/// vira colunas — data, horários, sua função — e a lista passa a ser lida de
/// cima a baixo por coluna, que é o que faz uma agenda de trinta escalas
/// funcionar num monitor. As duas usam exatamente os mesmos campos do modelo.
class CompactScheduleTile extends ConsumerWidget {
  const CompactScheduleTile({
    super.key,
    required this.event,
    required this.canManage,
    required this.membershipId,
    this.wide = false,
  });

  final Event event;
  final bool canManage;
  final String membershipId;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final timezone =
        event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone;
    final youPositions = event.positionsForMembership(membershipId);
    final facts = ScheduleFacts.of(event, timezone);
    // Rascunho fala do que falta para publicar; escala publicada sem
    // repertório fala do repertório. Uma das duas, ou nenhuma.
    final temEstado = event.isDraft || event.servicesWithoutSongs.isNotEmpty;

    final dateBadge = AppDateBadge(
      weekday: formatEventBadgeWeekday(event.startsAt, timezone),
      day: formatEventDayNumber(event.startsAt, timezone),
      // Violeta onde você entra. É o mesmo sinal da pílula "VOCÊ", antecipado
      // para a coluna que o olho percorre — quem rola a agenda procurando os
      // próprios domingos para nos blocos tingidos antes de ler qualquer linha.
      tone: youPositions.isEmpty ? DateBadgeTone.normal : DateBadgeTone.primary,
    );

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatEventWeekdayDate(event.startsAt, timezone),
          style: theme.textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (event.hasTitle)
          Text(
            event.title!,
            style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );

    final timesText = Text(
      facts.summary,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        fontFeatures: AppTypography.tabular,
      ),
    );

    final trailing = canManage && FeatureFlags.duplicateSchedule
        // O menu do item só existe por causa de "Duplicar escala"; com a
        // funcionalidade escondida, a linha volta a ser só um atalho.
        ? PopupMenuButton<String>(
            tooltip: 'Mais opções desta escala',
            icon: Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            onSelected: (value) async {
              if (value == 'duplicate') {
                await showDuplicateEventDialog(
                  context: context,
                  ref: ref,
                  source: event,
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'duplicate', child: Text('Duplicar escala')),
            ],
          )
        : Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm, right: 4),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          );

    return AppPressable(
      onTap: () => context.push('/agenda/${event.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  dateBadge,
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(width: 230, child: title),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: timesText),
                  const SizedBox(width: AppSpacing.lg),
                  SizedBox(
                    width: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (temEstado)
                          ScheduleStatusLines(
                            event: event,
                            alignment: CrossAxisAlignment.end,
                          ),
                        if (youPositions.isNotEmpty) ...[
                          if (temEstado) const SizedBox(height: AppSpacing.xs),
                          YouHighlight(positionNames: youPositions),
                        ],
                      ],
                    ),
                  ),
                  trailing,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  dateBadge,
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (event.isDraft) ...[
                          const AppBadge(
                            label: 'Rascunho',
                            tone: AppTone.warning,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        title,
                        const SizedBox(height: 3),
                        timesText,
                        if (youPositions.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          // Alinhado à esquerda e sem esticar: a pílula tem a
                          // largura do que diz. Numa `Column` `stretch` ela
                          // atravessaria a linha inteira e viraria uma faixa.
                          Align(
                            alignment: Alignment.centerLeft,
                            child: YouHighlight(positionNames: youPositions),
                          ),
                        ],
                        if (temEstado) ...[
                          const SizedBox(height: AppSpacing.sm),
                          ScheduleStatusLines(event: event),
                        ],
                      ],
                    ),
                  ),
                  trailing,
                ],
              ),
      ),
    );
  }
}

/// Uma data da grade que ainda não virou escala, na arrumação de
/// [CompactScheduleTile] — e de propósito mais apagada que ela.
///
/// Data e horários no cinza do texto de apoio, bloco de data sem tinta, sem
/// selo e sem linha de estado: não há nada a resolver ainda, e pintar de âmbar
/// todo domingo do mês faria a cor de "isto precisa de você" perder o sentido
/// nas escalas que realmente travaram. O que a linha promete é o toque, e quem
/// diz isso é o "+" à direita, no lugar onde as escalas existentes têm a seta.
class OpenDateTile extends StatelessWidget {
  const OpenDateTile({super.key, required this.date, required this.wide});

  final OpenDate date;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final timezone = date.timezone;

    final dateBadge = AppDateBadge(
      weekday: formatEventBadgeWeekday(date.startsAt, timezone),
      day: formatEventDayNumber(date.startsAt, timezone),
      tone: DateBadgeTone.muted,
    );

    final title = Text(
      formatEventWeekdayDate(date.startsAt, timezone),
      style: theme.textTheme.titleMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    final times = Text(
      [
        for (final service in date.services)
          '${service.label} ${formatEventTime(service.startsAt, timezone)}',
      ].join('  ·  '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        fontFeatures: AppTypography.tabular,
      ),
    );

    return AppPressable(
      onTap: () => context.push('/agenda/novo?data=${date.dateParam}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment:
              wide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            dateBadge,
            const SizedBox(width: AppSpacing.md),
            if (wide) ...[
              SizedBox(width: 230, child: title),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: times),
            ] else
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 3),
                    times,
                  ],
                ),
              ),
            const SizedBox(width: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Icon(
                Icons.add_circle_outline_rounded,
                size: 20,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O estado da escala no item da agenda: até duas linhas curtas.
///
/// **Rascunho** responde "dá para publicar?"; **repertório em aberto**
/// responde "as músicas já saíram?". São perguntas diferentes desde que a
/// escala passou a poder ir para a equipe sem música -- juntar as duas numa
/// linha só fazia "falta música" parecer impedimento, que é justamente o que
/// ele deixou de ser.
///
/// Daí os tons: âmbar no que a liderança precisa resolver para publicar,
/// ardósia no que é só notícia -- para a equipe inteira, inclusive quem só
/// quer saber se já pode ensaiar.
class ScheduleStatusLines extends StatelessWidget {
  const ScheduleStatusLines({
    super.key,
    required this.event,
    this.alignment = CrossAxisAlignment.start,
  });

  final Event event;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final cores = AppStatusColors.of(context);
    final semRepertorio = event.servicesWithoutSongs;
    final blockers = event.publicationBlockers;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        if (event.isDraft)
          _StatusLine(
            icon: blockers.isEmpty
                ? Icons.check_circle_outline
                : Icons.pending_actions,
            text: blockers.isEmpty
                ? 'Pronta para publicar'
                : 'Falta ${blockers.join(' e ')}',
            palette: cores.warning,
          ),
        if (semRepertorio.isNotEmpty) ...[
          if (event.isDraft) const SizedBox(height: AppSpacing.xs),
          _StatusLine(
            icon: Icons.music_note_outlined,
            // Sem nenhuma música, nomear os cultos só repetiria a linha de
            // horários logo acima.
            text: event.hasNoSongs
                ? 'Músicas a definir'
                : 'Músicas a definir: ${semRepertorio.join(' e ')}',
            palette: cores.info,
          ),
        ],
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.text,
    required this.palette,
  });

  final IconData icon;
  final String text;
  final StatusPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: palette.foreground),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}
