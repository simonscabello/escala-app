import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/event_repository.dart';
import '../domain/event_change.dart';

/// Histórico da escala.
///
/// Responde à pergunta que sempre chegou pelo WhatsApp — "quem me tirou da
/// escala?" — sem depender da memória de quem estava com o app aberto. Com
/// mais de um líder montando a mesma escala, ninguém sabia dizer.
///
/// É leitura para a equipe inteira, e não só para quem lidera: o integrante é
/// quem mais precisa da resposta.
class EventHistoryScreen extends ConsumerWidget {
  const EventHistoryScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(eventHistoryProvider(eventId));

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico da escala')),
      body: SafeArea(
        top: false,
        child: AppContentWidth(
          child: history.when(
            loading: () => const AppListSkeleton(itemCount: 5),
            error: (error, _) => AppErrorState(
              message: error is ApiException
                  ? error.message
                  : 'Não foi possível carregar o histórico.',
              onRetry: () => ref.invalidate(eventHistoryProvider(eventId)),
            ),
            data: (changes) {
              if (changes.isEmpty) {
                return RefreshableMessage(
                  onRefresh: () async =>
                      ref.refresh(eventHistoryProvider(eventId).future),
                  child: const AppEmptyState(
                    icon: Icons.history_rounded,
                    title: 'Nada registrado ainda',
                    message: 'As mudanças passam a aparecer aqui a partir da '
                        'próxima vez que alguém mexer nesta escala.',
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async =>
                    ref.refresh(eventHistoryProvider(eventId).future),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  itemCount: changes.length,
                  itemBuilder: (_, index) => _ChangeRow(
                    change: changes[index],
                    isLast: index == changes.length - 1,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Uma mudança, na forma de linha do tempo: o fio à esquerda liga as entradas
/// e diz, sem escrever, que a lista é uma sequência no tempo — e não um
/// conjunto de avisos soltos.
class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change, required this.isLast});

  final EventChange change;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainerHigh,
                ),
                child: Icon(
                  _iconFor(change.kind),
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: scheme.outlineVariant),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${change.actorName} · ${_when(change.createdAt)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final line in change.summary)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(line, style: theme.textTheme.bodyMedium),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String kind) => switch (kind) {
        'CREATED' => Icons.add_rounded,
        'ASSIGNMENTS' => Icons.people_alt_rounded,
        'SETLIST' => Icons.library_music_rounded,
        'STATUS' => Icons.campaign_rounded,
        _ => Icons.edit_rounded,
      };

  /// "Hoje às 09:12" para o que acabou de acontecer; a data por extenso para o
  /// resto. Quem abre o histórico está atrás de "foi agora ou faz tempo?",
  /// antes de estar atrás do dia exato.
  static String _when(DateTime instant) {
    final local = instant.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final hour = DateFormat('HH:mm').format(local);

    if (day == today) return 'hoje às $hour';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'ontem às $hour';
    }
    return '${DateFormat("d 'de' MMM", 'pt_BR').format(local)} às $hour';
  }
}
