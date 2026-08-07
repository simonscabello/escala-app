import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/song_repository.dart';
import '../domain/song_models.dart';

/// Adicionar música: uma caixa de busca, duas fontes.
///
/// Primeiro o que outras equipes já cadastraram — é instantâneo, não gasta
/// chamada externa e **vem com letra**, que é o que nenhuma API entrega.
/// Depois o Spotify, para o que ninguém tem ainda.
///
/// A pessoa escolhe: título sozinho é ambíguo ("Aleluia" existe em cinco
/// versões) e casar automaticamente erraria calado.
class AddSongScreen extends ConsumerStatefulWidget {
  const AddSongScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends ConsumerState<AddSongScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<CatalogCandidate> _catalog = [];
  List<ExternalCandidate> _external = [];
  bool _searching = false;
  bool _adding = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _catalog = [];
        _external = [];
        _searched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String term) async {
    setState(() {
      _searching = true;
      _error = null;
    });

    final repository = ref.read(songRepositoryProvider);

    try {
      // As duas juntas: uma é local e a outra sai para o Spotify, e esperar
      // em fila dobraria o tempo à toa.
      final results = await Future.wait([
        repository.catalog(widget.teamId, term),
        repository.searchExternal(widget.teamId, term),
      ]);

      if (!mounted) return;
      setState(() {
        _catalog = results[0] as List<CatalogCandidate>;
        _external = results[1] as List<ExternalCandidate>;
        _searched = true;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add(Future<Song> Function() create) async {
    setState(() {
      _adding = true;
      _error = null;
    });

    try {
      final song = await create();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${song.title}" entrou no repertório.')),
      );
      context.pushReplacement('/equipe/musicas/${song.id}');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repository = ref.read(songRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar música')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                autofocus: true,
                enabled: !_adding,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Nome da música e artista',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                ),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            Expanded(
              child: _adding
                  ? const AppLoading(message: 'Buscando cifra e tom...')
                  : _Results(
                      catalog: _catalog,
                      external: _external,
                      searched: _searched,
                      onPickCatalog: (c) => _add(
                        () => repository.copyFromCatalog(
                          widget.teamId,
                          c.sourceSongId,
                        ),
                      ),
                      onPickExternal: (c) => _add(
                        () => repository.createFromExternal(widget.teamId, c),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.catalog,
    required this.external,
    required this.searched,
    required this.onPickCatalog,
    required this.onPickExternal,
  });

  final List<CatalogCandidate> catalog;
  final List<ExternalCandidate> external;
  final bool searched;
  final ValueChanged<CatalogCandidate> onPickCatalog;
  final ValueChanged<ExternalCandidate> onPickExternal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!searched) {
      return const AppEmptyState(
        icon: Icons.search_rounded,
        title: 'Procure a música',
        message: 'Digite o nome e, se souber, o artista. Buscamos no que '
            'outras equipes já cadastraram e no Spotify.',
      );
    }

    if (catalog.isEmpty && external.isEmpty) {
      return const AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nada encontrado',
        message: 'Tente escrever o artista junto, ou cadastre a música '
            'manualmente pelo botão de editar depois de criá-la.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        0,
        AppSpacing.screenPadding,
        AppSpacing.xxl,
      ),
      children: [
        if (catalog.isNotEmpty) ...[
          const _SectionTitle(
            title: 'Já cadastrada por outra equipe',
            subtitle: 'Vem completa, inclusive a letra',
          ),
          for (final item in catalog)
            _CatalogTile(item: item, onTap: () => onPickCatalog(item)),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (external.isNotEmpty) ...[
          const _SectionTitle(
            title: 'Spotify',
            subtitle: 'Buscamos a cifra e o tom ao adicionar',
          ),
          for (final item in external)
            _ExternalTile(item: item, onTap: () => onPickExternal(item)),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          'A letra não vem do Spotify. Se ninguém tiver essa música ainda, '
          'você pode colar a letra depois, na edição.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({required this.item, required this.onTap});

  final CatalogCandidate item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final traz = [
      if (item.hasLyrics) 'letra',
      if (item.hasChords) 'cifra',
      if (item.originalKey != null) 'tom ${item.originalKey}',
      if (item.hasYoutube) 'YouTube',
      if (item.hasSpotify) 'Spotify',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.library_add_check_outlined, color: scheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: theme.textTheme.titleSmall),
                  Text(
                    item.artist ?? 'Sem artista',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (traz.isNotEmpty)
                    Text(
                      'Traz ${traz.join(', ')}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.add_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ExternalTile extends StatelessWidget {
  const _ExternalTile({required this.item, required this.onTap});

  final ExternalCandidate item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.headphones_rounded, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    [item.artist, if (item.year != null) item.year!]
                        .where((e) => e.isNotEmpty)
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
