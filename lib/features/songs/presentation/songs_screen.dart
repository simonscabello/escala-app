import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/application/auth_controller.dart';
import '../data/song_repository.dart';
import '../domain/song_models.dart';

/// Repertório da equipe.
///
/// O filtro "faltando dados" é o coração desta tela. O acervo chega dos
/// serviços externos com artista, links, tom original e andamento, mas tom da
/// equipe, hino/cântico e "calma ou agitada" **nenhuma API responde** -- são
/// decisão de quem canta. Em vez de uma tarefa de centenas de linhas, isso
/// vira alguns toques quando a música entra numa escala.
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
  SongFilter _filter = SongFilter.todas;

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
    );
    final songs = ref.watch(songsProvider(query));
    final canManage =
        ref.watch(authControllerProvider).teams.firstOrNull?.canManage ?? false;

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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.md,
                AppSpacing.screenPadding,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar por título, artista ou compositor',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: Row(
                children: [
                  for (final option in SongFilter.values) ...[
                    ChoiceChip(
                      label: Text(
                        option == SongFilter.todas ? 'Todas' : 'Faltando dados',
                      ),
                      selected: _filter == option,
                      onSelected: (_) => setState(() => _filter = option),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: songs.when(
                loading: () => const AppLoading(),
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
                  canManage: canManage,
                ),
              ),
            ),
          ],
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
    required this.canManage,
  });

  final List<Song> songs;
  final String teamId;
  final SongQuery query;
  final SongFilter filter;
  final bool hasSearch;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => ref.refresh(songsProvider(query).future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.5,
              child: AppEmptyState(
                icon: Icons.library_music_outlined,
                title: hasSearch
                    ? 'Nada encontrado'
                    : filter == SongFilter.faltandoDados
                        ? 'Está tudo preenchido'
                        : 'Nenhuma música',
                message: hasSearch
                    ? 'Tente outro trecho do título ou o nome do artista.'
                    : filter == SongFilter.faltandoDados
                        ? 'Todas as músicas já têm tom, tipo e andamento.'
                        : 'Adicione as músicas que a equipe canta.',
                actionLabel: !hasSearch &&
                        filter == SongFilter.todas &&
                        canManage
                    ? 'Adicionar'
                    : null,
                onAction: () => context.push('/equipe/musicas/nova'),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(songsProvider(query).future),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          0,
          AppSpacing.screenPadding,
          AppSpacing.xxl * 2,
        ),
        itemCount: songs.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, index) => _SongTile(
          song: songs[index],
          teamId: teamId,
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({required this.song, required this.teamId});

  final Song song;
  final String teamId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      onTap: () => context.push('/equipe/musicas/${song.id}'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          // O tom é a informação que o músico procura primeiro. Vazio, vira
          // um convite a preencher em vez de um espaço em branco.
          _KeyBadge(song: song),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  song.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (song.kind != null || song.pace != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    [
                      if (song.kind != null) kindLabel(song.kind),
                      if (song.pace != null) paceLabel(song.pace),
                    ].join(' · '),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _LinkDots(song: song),
        ],
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
class _KeyBadge extends StatelessWidget {
  const _KeyBadge({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final own = song.defaultKey;
    final suggestion = song.originalKey;

    final label = own ?? suggestion ?? '?';
    final isOwn = own != null;

    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isOwn ? scheme.primaryContainer : scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color:
              isOwn ? scheme.onPrimaryContainer : scheme.onTertiaryContainer,
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

    final icons = <IconData>[
      if (song.chordsUrl != null) Icons.music_note_rounded,
      if (song.lyricsUrl != null) Icons.article_outlined,
      if (song.youtubeUrl != null) Icons.play_circle_outline_rounded,
      if (song.spotifyUrl != null) Icons.headphones_rounded,
    ];

    if (icons.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final icon in icons)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          ),
      ],
    );
  }
}
