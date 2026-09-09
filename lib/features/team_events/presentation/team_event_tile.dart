import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_date_badge.dart';
import '../../../shared/widgets/app_pressable.dart';
import '../../events/domain/event_datetime.dart';
import '../domain/team_event.dart';

/// Um evento da equipe como linha de lista, ao lado das escalas.
///
/// **A mesma arrumação da linha da escala** ([CompactScheduleTile]): bloco de
/// data à esquerda, texto à direita, superfície do grupo, fio entre as linhas.
/// Elas convivem na mesma lista, e duas arrumações diferentes fariam a agenda
/// parecer duas listas empilhadas.
///
/// **O que troca de lugar é o que identifica a coisa.** Numa escala a data é o
/// nome — "domingo, 13" basta —, então ela é a linha grande. Num evento o nome
/// é o nome: "quinta, 17" não diz se é reunião de liderança ou churrasco. Por
/// isso aqui o título vem primeiro e a data desce para a linha de apoio.
///
/// O selo "Evento" existe por causa dessa mesma troca: sem ele, uma linha que
/// começa com texto grande e não é uma data se lê como uma escala com título
/// especial ("Ceia", "Batismo"), que é coisa diferente.
class TeamEventTile extends StatelessWidget {
  const TeamEventTile({
    super.key,
    required this.event,
    this.wide = false,
  });

  final TeamEvent event;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final timezone = event.timezone;

    final dateBadge = AppDateBadge(
      weekday: formatEventBadgeWeekday(event.startsAt, timezone),
      day: formatEventDayNumber(event.startsAt, timezone),
    );

    final title = Text(
      event.title,
      style: theme.textTheme.titleMedium,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    final quando = Text(
      [
        formatEventWeekdayDate(event.startsAt, timezone),
        teamEventHours(event),
        if (event.hasLocation) event.location!,
      ].join(' · '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        fontFeatures: AppTypography.tabular,
      ),
    );

    const selo = AppBadge(label: 'Evento', tone: AppTone.info);

    final chevron = Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, right: 4),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
      ),
    );

    return AppPressable(
      onTap: () => context.push('/eventos/${event.id}'),
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
                  Expanded(child: quando),
                  const SizedBox(width: AppSpacing.lg),
                  selo,
                  chevron,
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
                        // Alinhado à esquerda e sem esticar: o selo tem a
                        // largura do que diz. Numa `Column` `stretch` ele
                        // atravessaria a linha e viraria uma faixa.
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: selo,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        title,
                        const SizedBox(height: 3),
                        quando,
                      ],
                    ),
                  ),
                  chevron,
                ],
              ),
      ),
    );
  }
}

/// "19:30" ou "12:00 às 18:00".
///
/// Sem hora de término não há travessão pendurado: a ausência é o normal —
/// churrasco não tem hora para acabar —, e escrever "12:00 – " prometeria um
/// dado que ninguém tem.
String teamEventHours(TeamEvent event) {
  final inicio = formatEventTime(event.startsAt, event.timezone);
  final fim = event.endsAt;
  if (fim == null) return inicio;
  return '$inicio às ${formatEventTime(fim, event.timezone)}';
}
