import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_group.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/application/auth_controller.dart';
import '../../events/domain/event_datetime.dart';
import '../../team/data/team_repository.dart';
import '../data/team_event_repository.dart';
import '../domain/team_event.dart';
import 'team_event_tile.dart';

/// O evento aberto: o que é, quando, onde e o recado.
///
/// **Tela de leitura, e curta.** Não há escalação para montar nem repertório
/// para conferir — o que a pessoa veio ver é se precisa levar alguma coisa e a
/// que horas chegar. Quem lidera ganha os dois botões de administrar no fim,
/// que é onde eles não competem com o conteúdo.
class TeamEventDetailScreen extends ConsumerWidget {
  const TeamEventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evento = ref.watch(teamEventProvider(eventId));
    final teamId = ref.watch(activeTeamIdProvider);
    final auth = ref.watch(authControllerProvider);
    final canManage = auth.teams
            .where((t) => t.teamId == teamId)
            .firstOrNull
            ?.canManage ??
        false;

    return Scaffold(
      appBar: AppBar(title: const Text('Evento')),
      body: SafeArea(
        child: AppContentWidth.reading(
          child: evento.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AppErrorState(
              message: error is ApiException
                  ? error.message
                  : 'Não foi possível carregar o evento.',
              onRetry: () => ref.invalidate(teamEventProvider(eventId)),
            ),
            data: (data) => _Corpo(
              event: data,
              canManage: canManage,
              teamId: teamId,
            ),
          ),
        ),
      ),
    );
  }
}

class _Corpo extends ConsumerWidget {
  const _Corpo({
    required this.event,
    required this.canManage,
    required this.teamId,
  });

  final TeamEvent event;
  final bool canManage;
  final String? teamId;

  Future<void> _excluir(BuildContext context, WidgetRef ref) async {
    final confirmado = await showConfirmDialog(
      context,
      title: 'Cancelar este evento?',
      // A frase diz o que o sistema NÃO faz. Prometer que "a equipe será
      // avisada" seria mentira: só a criação notifica, e quem já leu o aviso
      // vai continuar contando com o churrasco.
      message: 'O evento sai da agenda de todo mundo. A equipe não recebe '
          'aviso de cancelamento — quem já viu o evento precisa ser avisado '
          'por você.',
      confirmLabel: 'Cancelar evento',
      destructive: true,
    );
    if (!confirmado || !context.mounted) return;

    try {
      await ref.read(teamEventRepositoryProvider).remove(event.id);
      if (teamId != null) {
        for (final scope in ['upcoming', 'past']) {
          ref.invalidate(teamEventsProvider((teamId!, scope)));
        }
      }
      if (!context.mounted) return;
      showAppSnackBar(context, 'Evento cancelado.');
      context.go('/agenda');
    } on ApiException catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, error.message, tone: AppTone.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        Text(event.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xl),
        AppGroup(
          children: [
            AppGroupRow(
              icon: Icons.event_rounded,
              title: capitalizeWeekday(
                formatEventWeekdayDate(event.startsAt, event.timezone),
              ),
              subtitle: teamEventHours(event),
              showChevron: false,
            ),
            if (event.hasLocation)
              AppGroupRow(
                icon: Icons.place_rounded,
                title: event.location!,
                showChevron: false,
              ),
          ],
        ),
        if (event.hasNotes) ...[
          const SizedBox(height: AppSpacing.xl),
          AppGroup(
            title: 'Recado',
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  event.notes!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
        if (canManage) ...[
          const SizedBox(height: AppSpacing.xxl),
          OutlinedButton.icon(
            onPressed: () => context.push('/eventos/${event.id}/editar'),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Editar evento'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: () => _excluir(context, ref),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Cancelar evento'),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
          ),
        ],
      ],
    );
  }
}
