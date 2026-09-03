import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_choice_bar.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/application/auth_controller.dart';
import '../../songs/data/song_repository.dart';
import '../../songs/domain/song_models.dart';
import '../../songs/presentation/add_song_screen.dart';
import '../data/suggestion_repository.dart';
import '../domain/song_suggestion.dart';
import 'suggest_song_sheet.dart';

/// As sugestões da equipe.
///
/// **Para todo mundo, e não só para quem lidera.** Quem sugeriu precisa ver o
/// que aconteceu com a sugestão dele — inclusive o "por enquanto não" e o
/// motivo, quando houver. Foi por não enxergar isso que o Repertório já esteve
/// escondido atrás da engrenagem de Gerenciar equipe.
class SuggestionsScreen extends ConsumerStatefulWidget {
  const SuggestionsScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen> {
  SuggestionScope _scope = SuggestionScope.open;

  @override
  Widget build(BuildContext context) {
    final query = (teamId: widget.teamId, scope: _scope);
    final suggestions = ref.watch(suggestionsProvider(query));
    final team = ref
        .watch(authControllerProvider)
        .teams
        .where((t) => t.teamId == widget.teamId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Sugestões da equipe')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSuggestSongSheet(context, teamId: widget.teamId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Sugerir'),
      ),
      body: SafeArea(
        top: false,
        child: AppContentWidth.reading(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                ),
                child: AppChoiceBar<SuggestionScope>(
                  value: _scope,
                  onChanged: (value) => setState(() => _scope = value),
                  options: const [
                    AppChoice(
                      value: SuggestionScope.open,
                      label: 'Abertas',
                    ),
                    AppChoice(
                      value: SuggestionScope.closed,
                      label: 'Encerradas',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: suggestions.when(
                  loading: () => const AppLoading(),
                  error: (error, _) => AppErrorState(
                    message: error is ApiException
                        ? error.message
                        : 'Não foi possível carregar as sugestões.',
                    onRetry: () => ref.invalidate(suggestionsProvider(query)),
                  ),
                  data: (list) {
                    if (list.isEmpty) return _vazio();

                    return RefreshIndicator(
                      onRefresh: () async =>
                          ref.refresh(suggestionsProvider(query).future),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.listPadding,
                          0,
                          AppSpacing.listPadding,
                          96,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, index) => _SuggestionCard(
                          suggestion: list[index],
                          teamId: widget.teamId,
                          canManage: team?.canManage ?? false,
                          isMine: list[index].createdBy.membershipId ==
                              team?.membershipId,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vazio() {
    if (_scope == SuggestionScope.closed) {
      return const AppEmptyState(
        icon: Icons.inbox_rounded,
        title: 'Nada encerrado ainda',
        message: 'As sugestões respondidas e as de domingos que já passaram '
            'aparecem aqui.',
      );
    }
    return AppEmptyState(
      icon: Icons.lightbulb_outline_rounded,
      title: 'Nenhuma sugestão por enquanto',
      message: 'Qualquer pessoa da equipe pode sugerir uma música — para o '
          'repertório, ou para um domingo específico.',
      actionLabel: 'Sugerir uma música',
      onAction: () => showSuggestSongSheet(context, teamId: widget.teamId),
    );
  }
}

class _SuggestionCard extends ConsumerStatefulWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.teamId,
    required this.canManage,
    required this.isMine,
  });

  final SongSuggestion suggestion;
  final String teamId;
  final bool canManage;
  final bool isMine;

  @override
  ConsumerState<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends ConsumerState<_SuggestionCard> {
  bool _busy = false;

  SongSuggestion get s => widget.suggestion;

  void _refresh() {
    ref.invalidate(suggestionsProvider);
    ref.invalidate(openSuggestionCountProvider);
    ref.invalidate(eventSuggestionsProvider);
  }

  Future<void> _run(Future<void> Function() action, String ok) async {
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
      if (mounted) showAppSnackBar(context, ok, tone: AppTone.success);
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, tone: AppTone.danger);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Acolher a sugestão.
  ///
  /// Sem cadastro, o caminho passa pela tela de adicionar música — **e é ali
  /// que o líder decide o `isNew`**, que já nasce marcado naquela tela. Ligar
  /// a marca aqui seria deduzir "a equipe está aprendendo" de "alguém
  /// sugeriu", que é justamente o que o campo existe para não fazer.
  Future<void> _accept() async {
    String? songId = s.songId;

    if (songId == null) {
      // `Navigator.push` sobre esta tela, e não `context.push` do go_router: a
      // lista continua viva embaixo e volta intacta se o cadastro for
      // abandonado. A busca já abre preenchida com o nome sugerido.
      final criada = await Navigator.of(context).push<Song>(
        MaterialPageRoute(
          builder: (rota) => AddSongScreen(
            teamId: widget.teamId,
            initialSearch: s.title,
            onCreated: (song) => Navigator.of(rota).pop(song),
          ),
        ),
      );
      if (criada == null || !mounted) return;
      songId = criada.id;
      ref.invalidate(songsProvider);
    }

    await _run(
      () => ref
          .read(suggestionRepositoryProvider)
          .accept(widget.teamId, s.id, songId: songId)
          .then((_) {}),
      'Sugestão acolhida.',
    );
  }

  /// "Por enquanto não" — nunca "recusar".
  ///
  /// O motivo é opcional e a tela **não** empurra ninguém a escrever: às vezes
  /// o motivo certo (teologia, por exemplo) é uma conversa pessoal, e o app não
  /// é o canal. O rótulo avisa que quem sugeriu vai ler — sem isso, um líder
  /// escreve achando que é nota interna e o app entrega na cara da pessoa.
  Future<void> _decline() async {
    final controller = TextEditingController();
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Por enquanto não'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${s.title}" sai da lista de abertas.'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                helperText: 'Quem sugeriu vai ler. Pode deixar em branco e '
                    'conversar pessoalmente.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    final motivo = controller.text.trim();
    controller.dispose();
    if (confirmou != true) return;

    await _run(
      () => ref
          .read(suggestionRepositoryProvider)
          .decline(widget.teamId, s.id, reason: motivo)
          .then((_) {}),
      'Respondido.',
    );
  }

  Future<void> _reopen() => _run(
        () => ref
            .read(suggestionRepositoryProvider)
            .reopen(widget.teamId, s.id)
            .then((_) {}),
        'Sugestão reaberta.',
      );

  Future<void> _remove() async {
    final confirmou = await showConfirmDialog(
      context,
      title: 'Excluir sugestão?',
      message: '"${s.title}" some da lista para todo mundo.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!confirmou) return;

    await _run(
      () => ref.read(suggestionRepositoryProvider).remove(widget.teamId, s.id),
      'Sugestão excluída.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title, style: theme.textTheme.titleMedium),
                    if ((s.artist ?? '').isNotEmpty)
                      Text(
                        s.artist!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              _selo(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppBadge(
                label: s.isForRepertoire
                    ? 'Para o repertório'
                    : _dataCurta(s.targetDate!),
                icon: s.isForRepertoire
                    ? Icons.library_music_outlined
                    : Icons.event_rounded,
                tone: s.isForRepertoire ? AppTone.neutral : AppTone.primary,
              ),
              if (s.inRepertoire)
                const AppBadge(
                  label: 'Já está no repertório',
                  icon: Icons.check_rounded,
                  tone: AppTone.neutral,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // A justificativa inteira, sem cortar: ela é o conteúdo da sugestão,
          // não um detalhe. É o que o líder lê para decidir.
          Text(s.reason, style: theme.textTheme.bodyMedium),

          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              AppAvatar(
                name: s.createdBy.displayName,
                imageUrl: s.createdBy.avatarUrl,
                radius: 12,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _assinatura(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),

          // O motivo do adiamento, quando existe. Em branco não vira rótulo
          // pendurado no vazio -- campo vazio é uso legítimo, não esquecimento.
          if ((s.declineReason ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              surface: CardSurface.sunken,
              child: Text(
                s.declineReason!,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],

          if (_acoes().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: AppSpacing.xs,
                children: _acoes(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Quem resolveu **não** aparece: recusa com o nome do líder do lado azeda a
  /// equipe. O selo diz o quê, não quem.
  Widget _selo() => switch (s.status) {
        SuggestionStatus.accepted => const AppBadge(
            label: 'Acolhida',
            tone: AppTone.success,
            icon: Icons.check_circle_outline_rounded,
          ),
        SuggestionStatus.declined => const AppBadge(
            label: 'Por enquanto não',
            tone: AppTone.neutral,
          ),
        SuggestionStatus.pending => const SizedBox.shrink(),
      };

  String _assinatura() {
    final quem = widget.isMine ? 'Você' : s.createdBy.displayName;
    if (s.alsoSuggestedBy.isEmpty) return 'Sugerida por $quem';

    // Repetida é sinal, não erro: dizer quantos mais querem a mesma música é
    // metade do que o líder precisa para priorizar.
    final outros = s.alsoSuggestedBy;
    final lista = outros.length == 1
        ? outros.first
        : '${outros.take(outros.length - 1).join(', ')} e ${outros.last}';
    return 'Sugerida por $quem · $lista também sugeriu'
        '${outros.length > 1 ? 'ram' : ''}';
  }

  List<Widget> _acoes() {
    if (_busy) {
      return const [
        Padding(
          padding: EdgeInsets.all(AppSpacing.sm),
          child: SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ];
    }

    return [
      if (widget.canManage && s.status.isPending) ...[
        TextButton(onPressed: _decline, child: const Text('Por enquanto não')),
        FilledButton.tonal(onPressed: _accept, child: const Text('Acolher')),
      ],
      if (widget.canManage && s.status.isResolved)
        TextButton(onPressed: _reopen, child: const Text('Reabrir')),
      if (widget.isMine || widget.canManage)
        IconButton(
          tooltip: 'Excluir',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: _remove,
        ),
    ];
  }
}

const _meses = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

String _dataCurta(DateTime date) => '${date.day} ${_meses[date.month - 1]}';
