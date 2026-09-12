import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_states.dart';
import '../../events/domain/event_datetime.dart';
import '../data/unavailability_repository.dart';
import '../domain/unavailability_models.dart';
import 'multi_date_picker.dart';

/// "Não posso nesses dias".
///
/// O modelo é avisar antes, não confirmar depois: em vez de a escala sair e
/// cada pessoa aceitar ou recusar, quem sabe que vai faltar marca o dia com
/// antecedência e quem monta a escala já enxerga isso na hora de escalar.
class MyUnavailabilityScreen extends ConsumerStatefulWidget {
  const MyUnavailabilityScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<MyUnavailabilityScreen> createState() =>
      _MyUnavailabilityScreenState();
}

class _MyUnavailabilityScreenState
    extends ConsumerState<MyUnavailabilityScreen> {
  bool _saving = false;

  /// O calendário edita o conjunto inteiro: o que a pessoa desmarcar é
  /// removido, o que marcar é criado. Assim o calendário mostra a verdade e
  /// não vira só um formulário de inclusão.
  Future<void> _editDays(List<Unavailability> current) async {
    final existing = {
      for (final item in current)
        if (!item.date.isBefore(_today)) item.date: item.id,
    };

    final result = await showMultiDatePicker(
      context: context,
      initialSelection: existing.keys.toSet(),
    );

    if (result == null || !mounted) return;

    final added = result.difference(existing.keys.toSet()).toList()..sort();
    final removedIds = [
      for (final entry in existing.entries)
        if (!result.contains(entry.key)) entry.value,
    ];

    if (added.isEmpty && removedIds.isEmpty) return;

    // Motivo só faz sentido quando há dias novos.
    final reason = added.isEmpty ? null : await _askReason();
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      final repository = ref.read(unavailabilityRepositoryProvider);

      for (final id in removedIds) {
        await repository.remove(widget.teamId, id);
      }
      if (added.isNotEmpty) {
        await repository.add(widget.teamId, dates: added, reason: reason);
      }

      ref.invalidate(myUnavailabilityProvider(widget.teamId));

      // Antes o calendário fechava e a tela simplesmente aparecia diferente.
      // Quem marca uma ausência precisa saber que o aviso chegou -- é a única
      // forma de a equipe descobrir que a pessoa não pode.
      if (mounted) {
        showAppSnackBar(
          context,
          added.isEmpty
              ? 'Dias atualizados. A equipe já vê.'
              : added.length == 1
                  ? 'Aviso enviado para 1 dia.'
                  : 'Aviso enviado para ${added.length} dias.',
          tone: AppTone.success,
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, tone: AppTone.danger);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// A caixa do motivo, nas duas entradas: ao marcar dias novos e ao corrigir
  /// um dia que já estava marcado.
  ///
  /// Devolve `null` quando a pessoa desistiu e a string quando confirmou --
  /// **vazia inclusive**, que é como se apaga um motivo. A diferença só
  /// importa ao corrigir: desistir não pode limpar o que estava escrito.
  Future<String?> _askReason({String? initial, bool editing = false}) {
    final controller = TextEditingController(text: initial ?? '');

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(editing ? 'Motivo desse dia' : 'Quer dizer o motivo?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          // O mesmo teto do servidor: cortar aqui poupa a ida de rede que
          // voltaria com o texto recusado depois de escrito.
          maxLength: 120,
          decoration: const InputDecoration(
            hintText: 'Viagem, trabalho... (opcional)',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            // Ao marcar, "Pular" segue com os dias e sem motivo; ao corrigir,
            // desistir tem de deixar o motivo como estava.
            onPressed: () =>
                Navigator.of(dialogContext).pop(editing ? null : ''),
            child: Text(editing ? 'Cancelar' : 'Pular'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  /// Corrigir o motivo de **um** dia.
  ///
  /// O motivo nasce por lote -- uma viagem cobre cinco domingos --, e depois
  /// um deles vira outra coisa. Sem isto a saída era desmarcar o dia e marcar
  /// de novo, que chega para quem lidera como uma ausência nova. O dia em si
  /// não se edita aqui: trocar de domingo é apagar um aviso e dar outro, e
  /// isso já é o que o calendário faz.
  Future<void> _editReason(Unavailability item) async {
    final reason = await _askReason(initial: item.reason, editing: true);
    if (reason == null || !mounted) return;
    if (reason == (item.reason ?? '')) return;

    try {
      await ref.read(unavailabilityRepositoryProvider).updateReason(
            widget.teamId,
            item.id,
            reason: reason,
          );
      ref.invalidate(myUnavailabilityProvider(widget.teamId));
      if (mounted) {
        showAppSnackBar(
          context,
          // Apagar o motivo não é desmarcar o dia, e a frase diz isso: quem
          // toca em "Salvar" com o campo vazio precisa saber que continua
          // indisponível.
          reason.isEmpty
              ? 'Motivo apagado. O dia continua marcado.'
              : 'Motivo atualizado. A equipe já vê.',
          tone: AppTone.success,
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, tone: AppTone.danger);
      }
    }
  }

  Future<void> _remove(Unavailability item) async {
    try {
      await ref
          .read(unavailabilityRepositoryProvider)
          .remove(widget.teamId, item.id);
      ref.invalidate(myUnavailabilityProvider(widget.teamId));
      if (mounted) {
        showAppSnackBar(
          context,
          'Você voltou a ficar disponível nesse dia.',
          tone: AppTone.success,
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, tone: AppTone.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = ref.watch(myUnavailabilityProvider(widget.teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('Minha disponibilidade')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving
            ? null
            : () => _editDays(
                  ref.read(myUnavailabilityProvider(widget.teamId)).value ??
                      const [],
                ),
        icon: const Icon(Icons.edit_calendar_rounded),
        label: const Text('Escolher dias'),
      ),
      body: SafeArea(
        top: false,
        child: AppContentWidth.reading(
          child: items.when(
            loading: () => const AppListSkeleton(itemCount: 3, leadingBlock: true),
            error: (error, _) => AppErrorState(
              message: error is ApiException
                  ? error.message
                  : 'Não foi possível carregar seus dias.',
              onRetry: () =>
                  ref.invalidate(myUnavailabilityProvider(widget.teamId)),
            ),
            data: (list) {
              final upcoming = list
                  .where((i) => !i.date.isBefore(_today))
                  .toList(growable: false);

              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(myUnavailabilityProvider(widget.teamId)),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.xxxl * 2,
                  ),
                  children: [
                    Text(
                      'Marque os dias em que você não pode ser escalado. Quem '
                      'monta a escala vê esse aviso na hora de escalar.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (upcoming.isEmpty)
                      // Dentro do fluxo, e não ocupando a tela por uma altura
                      // chutada em porcentagem: acima dele há a explicação, que
                      // é conteúdo, e um vazio de tela cheia a empurrava para
                      // fora da vista.
                      AppCard(
                        surface: CardSurface.sunken,
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_available_outlined,
                              size: 32,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Disponível em todos os dias',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Você não marcou nenhum dia. Toque em "Escolher '
                              'dias" se precisar avisar sobre alguma ausência.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final item in upcoming)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _UnavailabilityTile(
                            item: item,
                            onEditReason: () => _editReason(item),
                            onRemove: () => _remove(item),
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

/// Um dia marcado, com o motivo logo abaixo da data.
///
/// **O cartão inteiro abre o motivo.** O motivo entra por lote no momento de
/// marcar os dias, e aí ele é um chute sobre vários domingos de uma vez;
/// corrigir um deles era desmarcar e marcar de novo. O toque fica no cartão e
/// não num lápis ao lado do X: dois ícones minúsculos e vizinhos, um deles
/// destrutivo, é como se toca no errado.
class _UnavailabilityTile extends StatelessWidget {
  const _UnavailabilityTile({
    required this.item,
    required this.onEditReason,
    required this.onRemove,
  });

  final Unavailability item;
  final VoidCallback onEditReason;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = capitalizeWeekday(
      DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(item.date),
    );
    final reason = item.reason?.isNotEmpty ?? false ? item.reason! : null;

    return AppCard(
      onTap: onEditReason,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          // O ícone perdeu o ladrilho tingido atrás dele — o mesmo enfeite que
          // saiu das linhas de navegação. Aqui ele custava ainda mais: pintado
          // de azul, dizia "isto está certo" numa lista de "não posso neste
          // dia"; e vermelho seria alarme para uma coisa normal de avisar.
          // Sem tinta nenhuma, a linha volta a dizer só o que é.
          Icon(
            Icons.event_busy_outlined,
            size: 22,
            color: AppStatusColors.of(context).info.foreground,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                // Sem motivo, a segunda linha convida em vez de sumir: é o
                // que diz que o cartão abre alguma coisa. O motivo escrito
                // dispensa o convite -- quem já escreveu sabe que dá para
                // mexer, e "toque para editar" embaixo de cada dia viraria
                // ruído na lista inteira.
                Text(
                  reason ?? 'Toque para dizer o motivo',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: reason == null ? FontStyle.italic : null,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remover',
            icon: const Icon(Icons.close_rounded),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
