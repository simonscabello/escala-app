import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_choice_bar.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_pressable.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/application/auth_controller.dart';
import '../data/song_repository.dart';
import '../domain/song_models.dart';
import '../domain/song_themes.dart';
import 'song_theme_picker.dart';

/// Repertório da equipe.
///
/// O filtro "Novas" é o modo de trabalho desta tela: mostra o que a equipe está
/// aprendendo, e é por ele que a marca se gerencia — a lista fica curta e dá
/// para tirar de uma vez as que a igreja já canta junto, em vez de lembrar de
/// música por música.
///
/// Havia também um filtro "faltando dados", por tom da equipe, hino/cântico e
/// andamento. Saiu a pedido: essas três decisões continuam existindo na edição,
/// mas cobrá-las numa aba não era o jeito desta equipe trabalhar.
class SongsScreen extends ConsumerStatefulWidget {
  const SongsScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends ConsumerState<SongsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  String _search = '';
  SongFilter _filter = SongFilter.canticos;
  Set<String> _themes = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Sem espera, cada letra digitada viraria uma consulta.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _search = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = SongQuery(
      teamId: widget.teamId,
      search: _search,
      filter: _filter,
      themes: _themes,
    );
    final songs = ref.watch(songsProvider(query));
    final canManage = ref
            .watch(authControllerProvider)
            .teams
            .where((t) => t.teamId == widget.teamId)
            .firstOrNull
            ?.canManage ??
        false;

    return Scaffold(
      appBar: AppBar(title: const Text('Repertório')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/equipe/musicas/nova'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar'),
            )
          : null,
      body: SafeArea(
        top: false,
        child: AppContentWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                ),
                // `ListenableBuilder` no controlador: o botão de limpar era
                // desenhado a partir de `_searchController.text`, que só era
                // relido quando o `setState` do debounce disparava. Resultado:
                // o X aparecia 350ms depois da primeira letra, e por um
                // instante depois de limpar o campo ele continuava lá.
                child: ListenableBuilder(
                  listenable: _searchController,
                  builder: (context, _) => TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Buscar por título, artista ou compositor',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpar busca',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                ),
                child: AppChoiceBar<SongFilter>(
                  value: _filter,
                  onChanged: (value) => setState(() => _filter = value),
                  options: const [
                    AppChoice(value: SongFilter.canticos, label: 'Cânticos'),
                    AppChoice(value: SongFilter.hinos, label: 'Hinos'),
                    AppChoice(value: SongFilter.novas, label: 'Novas'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ThemeFilterBar(
                selected: _themes,
                onChanged: (themes) => setState(() => _themes = themes),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: songs.when(
                  loading: () => const AppListSkeleton(
                    itemCount: 6,
                    leadingBlock: true,
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      0,
                      AppSpacing.screenPadding,
                      AppSpacing.xl,
                    ),
                  ),
                  error: (error, _) => AppErrorState(
                    message: error is ApiException
                        ? error.message
                        : 'Não foi possível carregar o repertório.',
                    onRetry: () => ref.invalidate(songsProvider(query)),
                  ),
                  data: (list) => _SongList(
                    songs: list,
                    teamId: widget.teamId,
                    query: query,
                    filter: _filter,
                    hasSearch: _search.trim().isNotEmpty,
                    themes: _themes,
                    onClearThemes: () => setState(() => _themes = {}),
                    canManage: canManage,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SongList extends ConsumerWidget {
  const _SongList({
    required this.songs,
    required this.teamId,
    required this.query,
    required this.filter,
    required this.hasSearch,
    required this.themes,
    required this.onClearThemes,
    required this.canManage,
  });

  final List<Song> songs;
  final String teamId;
  final SongQuery query;
  final SongFilter filter;
  final bool hasSearch;
  final Set<String> themes;
  final VoidCallback onClearThemes;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) {
      // Com tema marcado, é ELE que explica a lista vazia e é ele que se
      // desfaz — dizer "nenhum cântico" a quem filtrou por "Ceia" descreveria
      // o acervo inteiro e esconderia o que de fato tirou as linhas da tela.
      if (themes.isNotEmpty) {
        return RefreshableMessage(
          onRefresh: () async => ref.refresh(songsProvider(query).future),
          child: AppEmptyState(
            icon: Icons.sell_outlined,
            title: 'Nada com esses temas',
            message: hasSearch
                ? 'Nenhuma música com esses temas e esse nome. Tire um dos '
                    'dois para alargar a busca.'
                : switch (filter) {
                    SongFilter.canticos =>
                      'Nenhum cântico classificado assim. Se for hino, toque '
                          'em Hinos.',
                    SongFilter.hinos =>
                      'Nenhum hino classificado assim. Se for cântico, toque '
                          'em Cânticos.',
                    SongFilter.novas =>
                      'Nenhuma música em aprendizado com esses temas.',
                  },
            actionLabel: 'Tirar os temas',
            onAction: onClearThemes,
          ),
        );
      }

      // A ação só existe quando ela é possível: antes o callback era passado
      // sempre, e só o rótulo era condicional -- um integrante sem permissão
      // via a tela sem saída, e a ação ficava presa a um botão invisível.
      final canAdd = !hasSearch && filter == SongFilter.canticos && canManage;

      return RefreshableMessage(
        onRefresh: () async => ref.refresh(songsProvider(query).future),
        child: AppEmptyState(
          icon: hasSearch
              ? Icons.search_off_rounded
              : Icons.library_music_outlined,
          tone: filter == SongFilter.novas && !hasSearch
              ? AppTone.success
              : AppTone.primary,
          title: hasSearch
              ? 'Nada encontrado'
              : switch (filter) {
                  // Lista vazia aqui é boa notícia, e não um buraco: quer
                  // dizer que a equipe já domina tudo o que canta.
                  SongFilter.novas => 'Nada em aprendizado',
                  SongFilter.hinos => 'Nenhum hino',
                  SongFilter.canticos => 'Nenhum cântico',
                },
          // Com a busca preenchida, a mensagem diz em qual acervo se procurou.
          // Sem isso, quem digita "142" em Cânticos vê "Nada encontrado" e
          // conclui que o hino não existe -- quando ele está na aba do lado.
          message: hasSearch
              ? switch (filter) {
                  SongFilter.canticos =>
                    'Procuramos só nos cânticos. Se for hino, toque em Hinos.',
                  SongFilter.hinos =>
                    'Procuramos só nos hinos. Se for cântico, toque em Cânticos.',
                  SongFilter.novas =>
                    'Nenhuma música em aprendizado com esse nome.',
                }
              : switch (filter) {
                  SongFilter.novas =>
                    'Marque uma música como nova ao adicioná-la, ou na edição.',
                  SongFilter.hinos =>
                    'O Cantor Cristão ainda não foi importado nesta equipe.',
                  SongFilter.canticos => canManage
                      ? 'Adicione as músicas que a equipe canta.'
                      : 'Quando o líder cadastrar as músicas, elas aparecem '
                          'aqui com letra, cifra e tom.',
                },
          actionLabel: canAdd ? 'Adicionar música' : null,
          onAction:
              canAdd ? () => context.push('/equipe/musicas/nova') : null,
        ),
      );
    }

    // Linhas com fio na página, e **não** um grupo de superfície única como no
    // Perfil ou em Gerenciar equipe. A regra que separa os dois casos:
    //
    //   grupo fechado  → conjunto finito e curto, que se lê inteiro
    //   linhas na página → lista longa, que se percorre e se filtra
    //
    // O repertório desta igreja tem 286 músicas. Envolvê-las numa moldura só
    // seria uma moldura de dois metros de altura — e, pior, exigiria construir
    // as 286 linhas de uma vez, porque uma `Column` dentro de moldura não é
    // preguiçosa. Aqui o `ListView.separated` continua construindo só o que
    // aparece.
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(songsProvider(query).future),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl * 2),
        itemCount: songs.length,
        separatorBuilder: (context, __) => Divider(
          height: 1,
          thickness: 1,
          indent: AppSpacing.screenPadding + 46 + AppSpacing.md,
          endIndent: AppSpacing.screenPadding,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        itemBuilder: (_, index) => _SongRow(
          song: songs[index],
          teamId: teamId,
        ),
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  const _SongRow({required this.song, required this.teamId});

  final Song song;
  final String teamId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPressable(
      onTap: () => context.push('/equipe/musicas/${song.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            // No hino, o número toma o lugar do tom neste bloco: é por ele que
            // se percorre o hinário, e é o que o pastor anuncia no culto. O tom
            // desce para a linha de baixo, onde continua legível.
            if (song.isHymn)
              _HymnNumber(song: song)
            else
              // O tom é a informação que o músico procura primeiro. Vazio, vira
              // um convite a preencher em vez de um espaço em branco.
              _KeyBadge(song: song),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      // Também fora do filtro "Novas": percorrendo o repertório
                      // inteiro é assim que se lembra do que ainda está sendo
                      // aprendido.
                      if (song.isNew) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const AppBadge(label: 'Nova', tone: AppTone.info),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    [
                      song.subtitle,
                      // "Hino" ao lado de um número seria repetir em palavra o
                      // que o número já diz. No hino entra o tom, que saiu do
                      // bloco da esquerda.
                      if (song.isHymn) ...[
                        if (song.defaultKey != null) 'Tom ${song.defaultKey}',
                      ] else ...[
                        if (song.kind != null) kindLabel(song.kind),
                        if (song.pace != null) paceLabel(song.pace),
                      ],
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _LinkDots(song: song),
          ],
        ),
      ),
    );
  }
}

/// Tom da equipe. Sem ele, mostra o tom da gravação em âmbar — não é a decisão
/// de vocês, e a cor diz isso sem precisar de legenda.
///
/// Âmbar e não cinza: das 286 músicas importadas, a maioria chegou sem tom, e
/// em cinza esse buraco lia-se como "está tudo certo". O âmbar é o papel de
/// **atenção** da paleta: algo a resolver, sem o susto do vermelho, que aqui
/// significa erro.
///
/// **A cor não pode ser o único sinal** (WCAG 1.4.1): para quem não distingue
/// o âmbar do azul, os dois estados eram a mesma caixa com "F#" dentro. O lápis
/// abaixo do tom diz "isto ainda é para preencher" sem depender de cor, e o
/// `Semantics` diz a frase inteira para quem usa leitor de tela.
class _KeyBadge extends StatelessWidget {
  const _KeyBadge({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = AppStatusColors.of(context);
    final own = song.defaultKey;
    final suggestion = song.originalKey;

    final label = own ?? suggestion ?? '?';
    final isOwn = own != null;
    final palette = isOwn
        ? status.resolve(AppTone.primary, scheme)
        : status.warning;

    return Semantics(
      label: isOwn
          ? 'Tom da equipe: $label'
          : suggestion != null
              ? 'Sem tom definido. A gravação está em $suggestion.'
              : 'Sem tom definido.',
      excludeSemantics: true,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.container,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.onContainer,
                height: 1.1,
              ),
            ),
            if (!isOwn)
              Icon(
                Icons.edit_outlined,
                size: 11,
                color: palette.onContainer.withValues(alpha: 0.8),
              ),
          ],
        ),
      ),
    );
  }
}

/// Número do hino, no mesmo bloco onde o cântico mostra o tom.
///
/// Mesma medida e mesmo raio do [_KeyBadge] de propósito: as duas abas rolam
/// com o olho na mesma coluna, e um bloco de tamanho diferente faria a lista
/// tremer ao trocar de aba.
///
/// Tinta neutra, e não a `primary` do tom: aqui não há nada a decidir nem a
/// preencher. O número é fato impresso no hinário — ele identifica, não cobra.
class _HymnNumber extends StatelessWidget {
  const _HymnNumber({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      label: 'Cantor Cristão, hino ${song.hymnNumber}',
      excludeSemantics: true,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Text(
          // Com zero à esquerda, como o hinário imprime: além de fiel, alinha
          // a coluna de números de uma a três casas.
          song.hymnNumber!.toString().padLeft(3, '0'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Quais links a música tem, sem ocupar uma linha de texto.
class _LinkDots extends StatelessWidget {
  const _LinkDots({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final links = <(IconData, String)>[
      if (song.chordsUrl != null) (Icons.music_note_rounded, 'cifra'),
      if (song.lyricsUrl != null) (Icons.article_outlined, 'letra'),
      if (song.youtubeUrl != null) (Icons.play_circle_outline_rounded, 'vídeo'),
      if (song.spotifyUrl != null) (Icons.headphones_rounded, 'áudio'),
    ];

    if (links.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: 'Tem ${links.map((l) => l.$2).join(', ')}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final link in links)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Icon(link.$1, size: 15, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// A linha de filtro por tema, logo abaixo das abas.
///
/// **Uma tira que rola, e não um painel.** O que precisa estar visível o tempo
/// todo é *quais* temas estão filtrando — sem isso, uma lista curta parece
/// acervo pequeno em vez de filtro ligado, e foi assim que a aba "Novas" já
/// confundiu antes. Cada tema marcado vira uma etiqueta com "x", que é o
/// caminho mais curto para desfazer: um toque, sem reabrir o seletor.
///
/// O botão de abrir vem **primeiro** e não some quando há escolha: a mesma
/// posição sempre, esteja o filtro ligado ou não.
class _ThemeFilterBar extends StatelessWidget {
  const _ThemeFilterBar({required this.selected, required this.onChanged});

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  Future<void> _open(BuildContext context) async {
    final escolha = await showSongThemePicker(context, selected: selected);
    if (escolha != null) onChanged(escolha);
  }

  @override
  Widget build(BuildContext context) {
    // `SingleChildScrollView` + `Row`, como o `AppChoiceBar` logo acima, e nao
    // um `ListView` de altura fixa: com a fonte do sistema aumentada o chip
    // cresce, e uma caixa de altura fixa o cortaria com a listra amarela de
    // overflow. Aqui a tira toma a altura do que tem dentro.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
      ),
      child: Row(
        children: [
          ActionChip(
            avatar: const Icon(Icons.sell_outlined, size: 18),
            label: Text(
              selected.isEmpty ? 'Temas' : 'Temas (${selected.length})',
            ),
            tooltip: 'Filtrar por tema',
            onPressed: () => _open(context),
          ),
          // Na ordem do catálogo: a tira não pode se remexer conforme a ordem
          // em que a pessoa foi marcando.
          for (final tema in songThemeValues)
            if (selected.contains(tema))
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: InputChip(
                  label: Text(songThemeLabel(tema)),
                  selected: true,
                  showCheckmark: false,
                  onDeleted: () => onChanged({...selected}..remove(tema)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  deleteButtonTooltipMessage: 'Tirar ${songThemeLabel(tema)}',
                  onSelected: (_) => _open(context),
                ),
              ),
        ],
      ),
    );
  }
}
