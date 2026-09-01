import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../data/song_repository.dart';
import '../domain/song_models.dart';
import 'song_theme_picker.dart';

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
    // A equipe DESTA música, e não a primeira da lista: quem participa de duas
    // veria o lápis de editar num repertório onde é apenas membro.
    final canManage = ref
            .watch(authControllerProvider)
            .teams
            .where((t) => t.teamId == teamId)
            .firstOrNull
            ?.canManage ??
        false;

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
          // Só depois que a música carregou: o rótulo do menu depende de ela
          // estar arquivada ou não, e um menu que muda de texto sozinho depois
          // de aberto seria pior que menu nenhum.
          if (canManage && song.valueOrNull != null)
            PopupMenuButton<String>(
              tooltip: 'Mais opções',
              onSelected: (_) => _toggleArchived(context, ref, song.value!),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'archive',
                  child: Text(
                    song.value!.isArchived ? 'Restaurar' : 'Arquivar',
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AppContentWidth(
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
      ),
    );
  }

  /// Arquivar é o que existe no lugar de excluir: a API recusa apagar música
  /// que já foi tocada, para não abrir buracos nas escalas passadas. O caminho
  /// de volta fica em Repertório → arquivadas.
  Future<void> _toggleArchived(
    BuildContext context,
    WidgetRef ref,
    Song song,
  ) async {
    final restoring = song.isArchived;

    if (!restoring) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Arquivar ${song.title}?',
        message: 'Ela sai do repertório e da busca do repertório da escala. '
            'As escalas em que já foi tocada continuam como estão, e dá para '
            'restaurar quando quiser.',
        confirmLabel: 'Arquivar',
      );
      if (!confirmed || !context.mounted) return;
    }

    try {
      await ref.read(songRepositoryProvider).setArchived(
            teamId,
            songId,
            isArchived: !restoring,
          );
      ref.invalidate(songProvider((teamId: teamId, songId: songId)));
      ref.invalidate(songsProvider);
      if (context.mounted) {
        showAppSnackBar(
          context,
          restoring
              ? '${song.title} voltou para o repertório.'
              : '${song.title} foi arquivada.',
          tone: AppTone.success,
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        showAppSnackBar(context, e.message, tone: AppTone.danger);
      }
    }
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
        // `Wrap` e não `Row`: título longo em `headlineSmall` ocupa duas linhas,
        // e a etiqueta desce inteira em vez de espremer o nome.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Text(
              // O número antes do nome, como o hinário e o púlpito dizem:
              // "cento e quarenta e dois, Pão da Vida".
              song.isHymn ? '${song.hymnNumber} · ${song.title}' : song.title,
              style: theme.textTheme.headlineSmall,
            ),
            if (song.isNew)
              const AppBadge(
                label: 'Nova',
                tone: AppTone.info,
                semanticsLabel: 'A equipe está aprendendo esta música',
              ),
            // Aberta a partir de uma escala antiga, a música arquivada não
            // teria como se explicar: some do repertório e continua ali.
            if (song.isArchived)
              const AppBadge(
                label: 'Arquivada',
                tone: AppTone.warning,
                semanticsLabel: 'Esta música está fora do repertório',
              ),
          ],
        ),
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
        // Entre os fatos e os links, e não no rodapé: é a resposta de "esta
        // música serve para o culto que estou montando?", que vem antes de
        // abrir a cifra. Sem tema nenhum, a seção inteira some -- e some
        // calada, porque cobrar classificação de 1.210 músicas numa tela de
        // leitura seria alarme permanente.
        if (song.themes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SongThemeChips(themes: song.themes),
        ],
        const SizedBox(height: AppSpacing.xl),
        _Links(song: song),
        if (song.hasLyrics) ...[
          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            title: 'Letra',
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
          ),
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
      showAppSnackBar(
        context,
        'Não foi possível abrir o link.',
        tone: AppTone.danger,
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
