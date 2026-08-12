import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/section_header.dart';
import '../../songs/data/song_repository.dart';
import '../domain/event_models.dart';

/// A música aberta de dentro da escala: tom, recado, links e letra.
///
/// Folha e não navegação para a tela do repertório por dois motivos. O tom que
/// vale aqui é o **desta escala** (o `keyOverride`, quando existe), e a tela da
/// música mostra o tom da equipe — quem abrisse de dentro da escala leria o
/// número errado. E quem abre isto está de instrumento na mão, minutos antes de
/// tocar: fechar a folha devolve a escala exatamente como estava.
///
/// **Vale para MEMBER.** É justamente quem toca que precisa da cifra; o líder
/// já tem o caminho da edição.
Future<void> showEventSongSheet({
  required BuildContext context,
  required String teamId,
  required EventSong song,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EventSongSheet(teamId: teamId, song: song),
  );
}

class _EventSongSheet extends ConsumerWidget {
  const _EventSongSheet({required this.teamId, required this.song});

  /// A equipe **da escala**, e não a equipe ativa: quem participa de duas veria
  /// a letra ser procurada no repertório errado.
  final String teamId;

  final EventSong song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, controller) => ListView(
        controller: controller,
        // O recuo da barra de navegação entra no fim da lista: a folha vai até
        // a borda da tela, e sem isto as últimas linhas da letra ficavam por
        // baixo dos botões do sistema -- justamente no fim da música, que é
        // onde se está olhando quando ela acaba.
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          0,
          AppSpacing.screenPadding,
          AppSpacing.xxl + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          // `Wrap` e não `Row`: título longo em `headlineSmall` ocupa duas
          // linhas, e a etiqueta desce inteira em vez de espremer o nome.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Text(song.title, style: theme.textTheme.headlineSmall),
              if (song.isNew)
                const AppBadge(
                  label: 'Nova',
                  tone: AppTone.info,
                  semanticsLabel: 'Música nova: a equipe ainda não tocou esta',
                ),
            ],
          ),
          if (song.artist?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              song.artist!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _KeyCard(song: song),
          if (song.note?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.md),
            _NoteBand(note: song.note!),
          ],
          const SizedBox(height: AppSpacing.lg),
          _Links(song: song),
          const SizedBox(height: AppSpacing.xl),
          // A escala não carrega a letra -- são centenas de caracteres por
          // música e ela já é a tela mais pesada. Aqui a busca é de uma música
          // só, e só quando alguém abriu esta folha.
          _Lyrics(teamId: teamId, songId: song.songId),
        ],
      ),
    );
  }
}

/// O tom desta escala, em destaque.
///
/// Quando a escala mudou o tom, o da equipe aparece embaixo em vez de sumir:
/// quem decorou "sempre em G" precisa ver que hoje é diferente, e por quê.
class _KeyCard extends StatelessWidget {
  const _KeyCard({required this.song});

  final EventSong song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final temTom = song.key?.isNotEmpty ?? false;

    return AppCard(
      color: song.hasCustomKey ? scheme.primaryContainer : null,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Icon(
            Icons.piano_rounded,
            color: song.hasCustomKey ? scheme.onPrimaryContainer : scheme.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  temTom ? 'Tom nesta escala' : 'Tom não definido',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: song.hasCustomKey
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  temTom ? song.key! : '—',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: song.hasCustomKey
                        ? scheme.onPrimaryContainer
                        : scheme.onSurface,
                  ),
                ),
                if (song.hasCustomKey &&
                    (song.defaultKey?.isNotEmpty ?? false))
                  Text(
                    'A equipe costuma cantar em ${song.defaultKey}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteBand extends StatelessWidget {
  const _NoteBand({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.sticky_note_2_outlined,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(note, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class _Links extends StatelessWidget {
  const _Links({required this.song});

  final EventSong song;

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
    final theme = Theme.of(context);

    // A cifra primeiro: é o que o instrumentista abre, e é o link que a escala
    // existia para não alcançar.
    final entries = <(IconData, String, String?)>[
      (Icons.music_note_rounded, 'Cifra', song.chordsUrl),
      (Icons.article_outlined, 'Letra', song.lyricsUrl),
      (Icons.play_circle_outline_rounded, 'YouTube', song.youtubeUrl),
      (Icons.headphones_rounded, 'Spotify', song.spotifyUrl),
    ].where((e) => e.$3?.isNotEmpty ?? false).toList();

    if (entries.isEmpty) {
      return Text(
        'Esta música ainda não tem cifra nem link cadastrado.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

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

/// A letra guardada no banco.
///
/// Texto e não link: site de letra sai do ar, muda de endereço e não abre no
/// meio do culto com a internet da igreja.
class _Lyrics extends ConsumerWidget {
  const _Lyrics({required this.teamId, required this.songId});

  final String teamId;
  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final song = ref.watch(songProvider((teamId: teamId, songId: songId)));

    return song.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      // Falhar aqui não pode esconder o tom e a cifra, que já estão na tela e
      // vieram junto com a escala.
      error: (_, __) => Text(
        'Não foi possível carregar a letra agora.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      data: (value) {
        if (!value.hasLyrics) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Letra',
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
            ),
            SelectableText(
              value.lyrics!,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ],
        );
      },
    );
  }
}
