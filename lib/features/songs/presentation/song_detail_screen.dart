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
import '../../../shared/widgets/app_group.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../data/song_repository.dart';
import '../domain/song_history.dart';
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
        child: AppContentWidth.reading(
          child: song.when(
            loading: () => const AppLoading(),
            error: (error, _) => AppErrorState(
              message: error is ApiException
                  ? error.message
                  : 'Não foi possível carregar a música.',
              onRetry: () => ref.invalidate(songProvider(args)),
            ),
            data: (value) => _Body(
              song: value,
              teamId: teamId,
              showHistory: canManage,
            ),
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
        message: 'Ela sai do repertório, mas continua nas escalas em que já '
            'foi tocada. Dá para restaurar depois.',
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
      ref.invalidate(learningSongsProvider(teamId));
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

/// A tela da música, na ordem em que o músico a usa: **o que é** (nome, tom,
/// tipo, andamento, temas), **como ensaiar** (cifra, letra, YouTube, Spotify),
/// a letra, e por último **quando foi cantada** — que é consulta de quem monta
/// o culto, e não do músico que abriu a música para tirar o tom.
class _Body extends StatelessWidget {
  const _Body({
    required this.song,
    required this.teamId,
    required this.showHistory,
  });

  final Song song;
  final String teamId;

  /// Só para quem lidera: o histórico é relatório, e o servidor o recusa ao
  /// integrante. Pedir e esconder o erro seria uma requisição à toa.
  final bool showHistory;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.lg,
        AppSpacing.screenPadding,
        AppSpacing.xxl,
      ),
      children: [
        _Header(song: song),
        const SizedBox(height: AppSpacing.lg),
        _Facts(song: song),
        // Logo abaixo dos fatos, e não no rodapé: é a resposta de "esta música
        // serve para o culto que estou montando?", que vem antes de abrir a
        // cifra. Sem tema nenhum, some calada — cobrar classificação de 1.210
        // músicas numa tela de leitura seria alarme permanente.
        if (song.themes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SongThemeChips(themes: song.themes),
        ],
        const SizedBox(height: AppSpacing.xl),
        _Preparation(song: song),
        if (song.hasLyrics) ...[
          // Menos que entre os outros blocos: o cabeçalho da letra tem a altura
          // do botão "Ver completa", e a folga dele já faz parte do respiro.
          const SizedBox(height: AppSpacing.md),
          _LyricsPreview(song: song),
        ],
        if (showHistory) _SongHistorySection(teamId: teamId, songId: song.id),
      ],
    );
  }
}

/// "142 · Pão da Vida": o número antes do nome, como o hinário e o púlpito
/// dizem — "cento e quarenta e dois, Pão da Vida".
String _displayTitle(Song song) =>
    song.hymnal != null ? '${song.hymnal!.number} · ${song.title}' : song.title;

Future<void> _openLink(BuildContext context, String url) async {
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

void _openLyrics(BuildContext context, Song song) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => SongLyricsScreen(song: song)),
  );
}

bool _filled(String? value) => value != null && value.trim().isNotEmpty;

/// O artista em versalete, abaixo do nome.
///
/// Caixa alta **só no desenho**: o leitor de tela recebe o nome como foi
/// escrito, senão soletraria "M-I-N-I-S-T-É-R-I-O".
class _ArtistLine extends StatelessWidget {
  const _ArtistLine({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      song.subtitle.toUpperCase(),
      semanticsLabel: song.subtitle,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // `Wrap` e não `Row`: título longo ocupa duas linhas, e a etiqueta
        // desce inteira em vez de espremer o nome.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Text(_displayTitle(song), style: theme.textTheme.headlineMedium),
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
        _ArtistLine(song: song),
        // Os hinários, todos: aqui é a tela da música, e a que está no Cantor
        // Cristão e no HCC precisa mostrar os dois números -- é justamente o
        // que a estrutura anterior não sabia dizer. A escala mostra só a
        // principal, porque lá cabe uma.
        if (song.hymnals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            song.hymnals.map((ref) => '${ref.number} ${ref.name}').join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
          ),
        ],
      ],
    );
  }
}

/// Tom, tipo e andamento, numa faixa só.
///
/// O tom da equipe vem primeiro e na cor da marca quando existe; sem ele, o da
/// gravação aparece embaixo, como sugestão — são coisas diferentes.
///
/// **Nada aqui vira reticências.** "Modera…" não diz se é moderada ou outra
/// coisa. Primeiro saem os ícones — ajudam a achar a coluna, mas é o valor que
/// a pessoa veio ler —, e se nem assim couber (320px com a fonte do sistema
/// aumentada) o texto encolhe um pouco em vez de ser cortado.
///
/// A decisão dos ícones é medida com a fonte e a escala do aparelho, como faz
/// a `AppChoiceBar` — e contra o vocabulário inteiro, não contra os valores
/// desta música: senão "Calma" teria ícones e "Moderada" não, e a faixa
/// mudaria de desenho de uma música para outra no mesmo celular.
class _Facts extends StatelessWidget {
  const _Facts({required this.song});

  final Song song;

  static const _dividerWidth = AppSpacing.md;

  static bool _iconsFit(BuildContext context, double column) {
    final theme = Theme.of(context);
    final texts = [
      for (final label in ['Tom', 'Tipo', 'Andamento'])
        (label, _Fact.labelStyle(theme)),
      for (final value in [
        'C#m',
        ...['HYMN', 'SONG'].map(kindLabel),
        ...['CALM', 'MODERATE', 'UPBEAT'].map(paceLabel),
      ])
        (value, _Fact.valueStyle(theme)),
    ];

    return texts.every((entry) {
      final painter = TextPainter(
        text: TextSpan(text: entry.$1, style: entry.$2),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final fits = painter.width + _Fact.iconSpace <= column;
      painter.dispose();
      return fits;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasKey = _filled(song.defaultKey);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final column = (constraints.maxWidth - 2 * _dividerWidth) / 3;
          final showIcons = _iconsFit(context, column);
          final divider = VerticalDivider(
            width: _dividerWidth,
            thickness: 1,
            color: theme.colorScheme.outlineVariant,
          );

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Fact(
                    icon: showIcons ? Icons.piano_rounded : null,
                    label: 'Tom',
                    value: hasKey ? song.defaultKey!.trim() : '—',
                    // Anotação antiga ("G (capo 2)") quebra em duas linhas em
                    // vez de encolher até ninguém ler. Tom da lista sempre
                    // cabe.
                    wrapValue: true,
                    hint: !hasKey && _filled(song.originalKey)
                        ? 'gravação: ${song.originalKey}'
                        : null,
                    highlight: hasKey,
                  ),
                ),
                divider,
                Expanded(
                  child: _Fact(
                    icon: showIcons ? Icons.library_music_outlined : null,
                    label: 'Tipo',
                    value: kindLabel(song.kind),
                  ),
                ),
                divider,
                Expanded(
                  child: _Fact(
                    icon: showIcons ? Icons.speed_rounded : null,
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
        },
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    this.icon,
    this.hint,
    this.highlight = false,
    this.wrapValue = false,
  });

  final String label;
  final String value;

  /// Nulo quando a coluna não comporta ícone.
  final IconData? icon;
  final String? hint;
  final bool highlight;
  final bool wrapValue;

  static const _iconSize = 20.0;

  /// O que o ícone ocupa na coluna, com o intervalo até o texto.
  static const iconSpace = _iconSize + AppSpacing.sm;

  static TextStyle? labelStyle(ThemeData theme) =>
      theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );

  static TextStyle? valueStyle(ThemeData theme) =>
      theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget oneLine(String text, TextStyle? style) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(text, maxLines: 1, style: style),
        );

    final valueColored = valueStyle(theme)?.copyWith(
      color: highlight ? scheme.primary : scheme.onSurface,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: _iconSize,
            color: highlight ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              oneLine(label, labelStyle(theme)),
              if (wrapValue)
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: valueColored,
                )
              else
                oneLine(value, valueColored),
              if (hint != null) oneLine(hint!, labelStyle(theme)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Cifra, letra, YouTube e Spotify: o que se abre para ensaiar.
///
/// **As quatro sempre, no mesmo lugar**, e apagadas quando não há o que abrir.
/// Esconder a que falta faria a grade mudar de forma de uma música para outra,
/// e "esta música está sem cifra" é justamente a informação que a equipe
/// precisa ver para ir atrás dela.
///
/// A letra é a única que tem duas fontes: guardada no banco ela abre aqui
/// dentro (sem rede, sem site fora do ar); sem ela, vale o link. Quando há os
/// dois, o link continua a um toque, no topo da tela da letra.
class _Preparation extends StatelessWidget {
  const _Preparation({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    _PrepItem link({
      required IconData icon,
      required String label,
      required String? url,
      required String action,
    }) =>
        _PrepItem(
          icon: icon,
          label: label,
          status: _filled(url) ? action : 'Sem link',
          onTap: _filled(url) ? () => _openLink(context, url!.trim()) : null,
        );

    final items = [
      link(
        icon: Icons.music_note_rounded,
        label: 'Cifra',
        url: song.chordsUrl,
        action: 'Abrir cifra',
      ),
      song.hasLyrics
          ? _PrepItem(
              icon: Icons.article_outlined,
              label: 'Letra',
              status: 'Ler no app',
              onTap: () => _openLyrics(context, song),
            )
          : link(
              icon: Icons.article_outlined,
              label: 'Letra',
              url: song.lyricsUrl,
              action: 'Abrir no site',
            ),
      link(
        icon: Icons.play_circle_outline_rounded,
        label: 'YouTube',
        url: song.youtubeUrl,
        action: 'Ver no YouTube',
      ),
      link(
        icon: Icons.headphones_rounded,
        label: 'Spotify',
        url: song.spotifyUrl,
        action: 'Ouvir no Spotify',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // O recuo de 4 é o do `AppGroup` ("Uso nas escalas", mais abaixo):
        // os títulos da tela alinham entre si.
        const SectionHeader(
          title: 'Preparação',
          padding: EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
        ),
        for (var row = 0; row < items.length; row += 2) ...[
          if (row > 0) const SizedBox(height: AppSpacing.sm),
          // Altura igual nas duas colunas: com a fonte do sistema aumentada,
          // um rótulo quebra e o vizinho ficaria mais baixo.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _PrepTile(item: items[row])),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _PrepTile(item: items[row + 1])),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PrepItem {
  const _PrepItem({
    required this.icon,
    required this.label,
    required this.status,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String status;
  final VoidCallback? onTap;
}

class _PrepTile extends StatelessWidget {
  const _PrepTile({required this.item});

  final _PrepItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final available = item.onTap != null;
    final muted = scheme.onSurfaceVariant;

    return AppCard(
      onTap: item.onTap,
      // Sem nada para abrir, o ladrilho afunda na página: sem borda e sem
      // seta, lê-se como vaga, não como botão que não responde.
      surface: available ? CardSurface.plain : CardSurface.sunken,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                item.icon,
                size: 22,
                color: available ? scheme.primary : muted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: available ? scheme.onSurface : muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
              if (available)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: muted.withValues(alpha: 0.7),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A letra, em prévia quando é comprida.
///
/// Inteira, ela empurrava o resto da tela para baixo de três ou quatro telas
/// de rolagem — e a letra não é o que se lê primeiro aqui. O corte é medido
/// com a largura e a fonte de verdade: contar quebras de linha erraria nas
/// estrofes de linha longa que o celular dobra.
///
/// Curta, aparece inteira e selecionável, sem "Ver completa" para abrir o
/// mesmo texto.
class _LyricsPreview extends StatelessWidget {
  const _LyricsPreview({required this.song});

  final Song song;

  static const _previewLines = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lyrics = song.lyrics!.trim();
    // Na prévia as estrofes se juntam: a linha em branco entre elas gastaria
    // um terço das seis linhas mostrando nada. A letra inteira mantém.
    final preview = lyrics.replaceAll(RegExp(r'\n\s*\n'), '\n');
    final style = theme.textTheme.bodyMedium?.copyWith(height: 1.6);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: preview, style: style),
          maxLines: _previewLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth - 2 * AppSpacing.lg);
        final long = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Título e link na mesma linha, centrados um no outro. Não é o
            // `SectionHeader`: lá a ação ao lado tem largura fixa, e a 320px com
            // a fonte do sistema aumentada ela empurrava o título para fora. O
            // título é uma palavra curta; o link fica com o resto da linha.
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xs,
                bottom: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Semantics(
                    header: true,
                    child: Text('Letra', style: theme.textTheme.titleMedium),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: long
                        ? Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton.icon(
                              onPressed: () => _openLyrics(context, song),
                              iconAlignment: IconAlignment.end,
                              icon: const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Ver completa',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                        // A altura do botão mesmo sem ele: a prévia não pula
                        // de lugar entre uma música e outra.
                        : const SizedBox(height: AppSpacing.touchTarget),
                  ),
                ],
              ),
            ),
            AppCard(
              onTap: long ? () => _openLyrics(context, song) : null,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: long
                  ? Text(
                      preview,
                      maxLines: _previewLines,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    )
                  : SelectableText(lyrics, style: style),
            ),
          ],
        );
      },
    );
  }
}

/// A letra inteira, sem nada em volta.
///
/// É a tela de quem está ensaiando com o celular na estante: título para
/// saber que é a música certa, e o texto em corpo maior. O link do site da
/// letra, quando existe, fica no topo — a letra guardada é a preferida, mas o
/// link continua sendo um recurso da música.
class SongLyricsScreen extends StatelessWidget {
  const SongLyricsScreen({super.key, required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final url = song.lyricsUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Letra'),
        actions: [
          if (_filled(url))
            IconButton(
              tooltip: 'Abrir no site',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () => _openLink(context, url!.trim()),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AppContentWidth.reading(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.lg,
              AppSpacing.screenPadding,
              AppSpacing.xxl,
            ),
            children: [
              Text(_displayTitle(song), style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              _ArtistLine(song: song),
              const SizedBox(height: AppSpacing.lg),
              Divider(height: 1, color: scheme.outlineVariant),
              const SizedBox(height: AppSpacing.lg),
              SelectableText(
                (song.lyrics ?? '').trim(),
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quando a equipe cantou esta música e em que momentos do culto.
///
/// Os momentos são **lidos das escalas**, e não cadastrados: é o que responde
/// "essa serve para a oferta?" sem ninguém ter precisado dizer isso ao app.
///
/// Fica no fim da tela: é consulta de quem monta o culto. Carregando ou com
/// falha, a seção não aparece — a tela da música é a da cifra e da letra, e o
/// histórico é o complemento.
class _SongHistorySection extends ConsumerWidget {
  const _SongHistorySection({required this.teamId, required this.songId});

  final String teamId;
  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(songHistoryProvider(teamId)).valueOrNull;
    if (all == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final history = all[songId];
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: AppGroup(
        title: 'Uso nas escalas',
        trailing: Tooltip(
          message: 'Só escalas publicadas que já aconteceram.',
          triggerMode: TooltipTriggerMode.tap,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        dividerIndent: AppGroup.textIndent,
        children: history == null
            ? const [
                AppGroupRow(title: 'Ainda não entrou em escala publicada'),
              ]
            : [
                AppGroupRow(
                  title: lastPlayedPhrase(history.lastPlayedAt, now) ??
                      'Ainda não cantada',
                  subtitle: '${timesLabel(history.last6Months)} nos últimos '
                      '6 meses · ${timesLabel(history.playCount)} no total',
                ),
                for (final moment in history.moments.take(4))
                  AppGroupRow(
                    title: moment.displayLabel,
                    trailing: Text(
                      timesLabel(moment.count),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
      ),
    );
  }
}
