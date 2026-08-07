import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/application/auth_controller.dart';
import '../data/song_repository.dart';
import '../domain/song_models.dart';

class SongDetailScreen extends ConsumerWidget {
  const SongDetailScreen({
    super.key,
    required this.teamId,
    required this.songId,
  });

  final String teamId;
  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (teamId: teamId, songId: songId);
    final song = ref.watch(songProvider(args));
    final canManage =
        ref.watch(authControllerProvider).teams.firstOrNull?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Música'),
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(
                '/equipe/musicas/$songId/editar',
                extra: song.valueOrNull,
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: song.when(
          loading: () => const AppLoading(),
          error: (error, _) => AppErrorState(
            message: error is ApiException
                ? error.message
                : 'Não foi possível carregar a música.',
            onRetry: () => ref.invalidate(songProvider(args)),
          ),
          data: (value) => _Body(song: value),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        Text(song.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          song.subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (song.composer != null && song.composer != song.artist) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Composição: ${song.composer}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        _Facts(song: song),
        const SizedBox(height: AppSpacing.xl),
        _Links(song: song),
        if (song.hasLyrics) ...[
          const SizedBox(height: AppSpacing.xxl),
          Text('Letra', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SelectableText(
              song.lyrics!,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

/// Tom, tipo e andamento. O tom da equipe vem primeiro e em destaque; o da
/// gravação aparece embaixo, como sugestão — são coisas diferentes.
class _Facts extends StatelessWidget {
  const _Facts({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: _Fact(
              label: 'Nosso tom',
              value: song.defaultKey ?? '—',
              hint: song.defaultKey == null && song.originalKey != null
                  ? 'gravação: ${song.originalKey}'
                  : null,
              highlight: song.defaultKey != null,
            ),
          ),
          Container(width: 1, height: 42, color: scheme.outlineVariant),
          Expanded(
            child: _Fact(label: 'Tipo', value: kindLabel(song.kind)),
          ),
          Container(width: 1, height: 42, color: scheme.outlineVariant),
          Expanded(
            child: _Fact(
              label: 'Andamento',
              value: paceLabel(song.pace),
              hint: song.pace == null && song.bpm != null
                  ? '${song.bpm} bpm'
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    this.hint,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String? hint;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: highlight ? scheme.primary : scheme.onSurface,
          ),
        ),
        if (hint != null)
          Text(
            hint!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _Links extends StatelessWidget {
  const _Links({required this.song});

  final Song song;

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = <(IconData, String, String?)>[
      (Icons.music_note_rounded, 'Cifra', song.chordsUrl),
      (Icons.article_outlined, 'Letra', song.lyricsUrl),
      (Icons.play_circle_outline_rounded, 'YouTube', song.youtubeUrl),
      (Icons.headphones_rounded, 'Spotify', song.spotifyUrl),
    ].where((e) => e.$3 != null).toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final (icon, label, url) in entries)
          ActionChip(
            avatar: Icon(icon, size: 18),
            label: Text(label),
            onPressed: () => _open(context, url!),
          ),
      ],
    );
  }
}
