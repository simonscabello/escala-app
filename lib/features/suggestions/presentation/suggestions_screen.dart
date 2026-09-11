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
import '../../../shared/widgets/app_states.dart';
import '../../auth/application/auth_controller.dart';
import '../data/suggestion_repository.dart';
import '../domain/song_suggestion.dart';
import 'suggest_song_sheet.dart';
import 'suggestion_detail_screen.dart';

/// As sugestões da equipe.
///
/// **Para todo mundo, e não só para quem lidera.** Quem sugeriu precisa ver o
/// que aconteceu com a sugestão dele — inclusive o "por enquanto não" e o
/// motivo, quando houver. Foi por não enxergar isso que o Repertório já esteve
/// escondido atrás da engrenagem de Gerenciar equipe.
///
/// **A lista é índice, não é o conteúdo.** O cartão nasceu mostrando a
/// justificativa inteira e as duas decisões do líder; com dezenas de sugestões
/// numa equipe ativa, cada uma ocupava meia tela e encontrar a de hoje virava
/// rolagem. Agora a linha responde só "qual música, para quando, de quem, e
/// tem material?" — o resto mora na tela de detalhes, que é onde também ficam
/// as decisões. Ler a lista e decidir uma sugestão passaram a ser dois gestos
/// diferentes, e é assim que a página densa deixa de ser perigosa.
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
                        itemBuilder: (_, index) => SuggestionCard(
                          suggestion: list[index],
                          teamId: widget.teamId,
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

/// Uma linha da lista. **Índice, não resumo executivo.**
///
/// Quatro fatos e nada mais: qual música, para quando, por que (a primeira
/// linha do motivo), quem pediu — e uns pontinhos dizendo que há cifra, áudio
/// ou vídeo esperando do outro lado. O cartão inteiro é o toque; não há botão
/// nenhum aqui, de propósito: decisão que se toma de raspão numa lista é
/// decisão que se toma sem ler o motivo, e o motivo é a razão de o campo ser
/// obrigatório.
class SuggestionCard extends StatelessWidget {
  const SuggestionCard({
    super.key,
    required this.suggestion,
    required this.teamId,
    required this.isMine,
  });

  final SongSuggestion suggestion;
  final String teamId;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = suggestion;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      // Mais apertado que o cartão de leitura: vertical menor porque são
      // quatro linhas curtas, horizontal cheio porque o `Clip.antiAlias` do
      // canto arredondado come a primeira letra de quem encosta na borda.
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onTap: () => openSuggestionDetail(
        context,
        teamId: teamId,
        suggestion: s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Para quando. Em primeiro plano porque é o que muda a urgência:
              // domingo marcado corre contra o relógio, repertório espera.
              AppBadge(
                label: s.isForRepertoire
                    ? 'Repertório'
                    : _dataCurta(s.targetDate!),
                icon: s.isForRepertoire
                    ? Icons.library_music_outlined
                    : Icons.event_rounded,
                tone: s.isForRepertoire ? AppTone.neutral : AppTone.primary,
              ),
            ],
          ),
          if ((s.artist ?? '').isNotEmpty)
            Text(
              s.artist!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          // Uma linha só. O motivo inteiro é o conteúdo da sugestão e continua
          // inteiro — na tela de detalhes. Aqui ele é a isca que faz abrir.
          Text(
            s.reason,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              AppAvatar(
                name: s.createdBy.displayName,
                imageUrl: s.createdBy.avatarUrl,
                radius: 9,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _assinatura(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              // Os materiais como pontinhos, e não como botões: aqui eles só
              // respondem "tem o que ouvir e o que ler?". Quem abre são os
              // botões da tela de detalhes.
              SuggestionMaterialDots(materials: s.materials),
              if (s.status.isResolved) ...[
                const SizedBox(width: AppSpacing.xs),
                _selo(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Quem resolveu **não** aparece: recusa com o nome do líder do lado azeda a
  /// equipe. O selo diz o quê, não quem.
  Widget _selo() => switch (suggestion.status) {
        SuggestionStatus.accepted => const AppBadge(
            label: 'Acolhida',
            tone: AppTone.success,
            icon: Icons.check_circle_outline_rounded,
          ),
        SuggestionStatus.declined => const AppBadge(
            label: 'Recusada',
            tone: AppTone.neutral,
          ),
        SuggestionStatus.pending => const SizedBox.shrink(),
      };

  String _assinatura() {
    final quem = isMine ? 'Você' : suggestion.createdBy.displayName;
    final outros = suggestion.alsoSuggestedBy;
    // Repetida é sinal, não erro. Na lista vira contagem: o nome de cada um
    // não caberia numa linha, e o que o líder usa para priorizar é o número.
    if (outros.isEmpty) return quem;
    return '$quem · +${outros.length} ${outros.length == 1 ? 'pessoa' : 'pessoas'}';
  }
}

/// Os pontinhos de material. Ícones miúdos e apagados, sem rótulo.
///
/// Vive aqui e não na tela de detalhes porque é a **lista** que precisa dizer
/// muito em pouco espaço; no detalhe os mesmos materiais viram botões com
/// nome. Cada ícone leva o rótulo no leitor de tela: sem isso a informação
/// existiria só para quem enxerga.
class SuggestionMaterialDots extends StatelessWidget {
  const SuggestionMaterialDots({super.key, required this.materials});

  final List<SuggestionMaterial> materials;

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final material in materials)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Tooltip(
              message: material.label,
              child: Icon(
                suggestionMaterialIcon(material.kind),
                size: 14,
                color: scheme.onSurfaceVariant,
                semanticLabel: material.label,
              ),
            ),
          ),
      ],
    );
  }
}

/// O ícone de cada material, num lugar só: a lista e o detalhe mostram o mesmo
/// desenho para a mesma coisa.
IconData suggestionMaterialIcon(SuggestionMaterialKind kind) => switch (kind) {
      SuggestionMaterialKind.lyrics => Icons.article_outlined,
      SuggestionMaterialKind.spotify => Icons.headphones_rounded,
      SuggestionMaterialKind.youtube => Icons.play_circle_outline_rounded,
    };

const _meses = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

String _dataCurta(DateTime date) => '${date.day} ${_meses[date.month - 1]}';
