import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_group.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/song_repository.dart';
import '../domain/repertoire_health.dart';
import '../domain/song_history.dart';

/// Quantas linhas cada lista mostra antes do "Ver todas".
const _preview = 5;

/// Análise do repertório: o que se repete, o que sumiu e o que falta cadastrar.
///
/// **Tela de manutenção, aberta de propósito** — por isso fica em Gerenciar
/// equipe, ao lado de "Uso do repertório", e não na lista do repertório. O
/// filtro "faltando dados" já morou lá e saiu: cobrar tom de centenas de
/// músicas no lugar onde a equipe procura a cifra não combinava com o jeito
/// dela trabalhar.
///
/// Cartão de resumo e listas em que dá para agir; cada música abre o próprio
/// detalhe. Lista vazia **some**: "0 músicas sem tom" é boa notícia, e um bloco
/// inteiro para dizer nada seria peso na tela.
class RepertoireHealthView extends ConsumerWidget {
  const RepertoireHealthView({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(repertoireHealthProvider(teamId));

    return health.when(
      loading: () => const AppListSkeleton(itemCount: 6),
      error: (error, _) => AppErrorState(
        message: error is ApiException
            ? error.message
            : 'Não foi possível carregar a análise do repertório.',
        onRetry: () => ref.invalidate(repertoireHealthProvider(teamId)),
      ),
      data: (value) => RefreshIndicator(
        onRefresh: () => ref.refresh(repertoireHealthProvider(teamId).future),
        child: _HealthBody(health: value, now: DateTime.now()),
      ),
    );
  }
}

class _HealthBody extends StatelessWidget {
  const _HealthBody({required this.health, required this.now});

  final RepertoireHealth health;
  final DateTime now;

  String? _when(RepertoireHealthSong song) => lastPlayedPhrase(song.lastPlayedAt, now);

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      if (health.frequent.isNotEmpty)
        _HealthSection(
          title: 'Cantadas com muita frequência',
          subtitle: '${health.frequentMinLast3Months} vezes ou mais nos '
              'últimos 3 meses',
          songs: health.frequent,
          details: (song) => [
            '${song.last3Months} vezes em 3 meses',
            if (_when(song) case final quando?) quando,
          ].join(' · '),
        ),
      if (health.idle.isNotEmpty)
        _HealthSection(
          title: 'Há muito tempo sem cantar',
          subtitle: 'Já cantadas, mas não nos últimos ${health.idleMonths} '
              'meses',
          songs: health.idle,
          details: _when,
        ),
      if (health.learning.isNotEmpty)
        _HealthSection(
          title: 'Músicas novas',
          subtitle: 'As marcadas como novas no repertório',
          songs: health.learning,
          details: (song) => [
            _when(song) ?? 'Ainda não entrou em escala',
            if (recentCountPhrase(song.last6Months) case final vezes?) vezes,
          ].join(' · '),
        ),
      if (health.missingKey.isNotEmpty)
        _HealthSection(
          title: 'Sem tom definido',
          subtitle: 'As mais cantadas primeiro',
          songs: health.missingKey,
          details: (song) => _when(song) ?? 'Ainda não cantada',
        ),
      if (health.missingReference.isNotEmpty)
        _HealthSection(
          title: 'Sem cifra nem gravação',
          subtitle: 'Sem link de cifra, YouTube ou Spotify, e fora de '
              'hinário. As mais cantadas primeiro',
          songs: health.missingReference,
          details: (song) => _when(song) ?? 'Ainda não cantada',
        ),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        AppSpacing.xxl,
      ),
      children: [
        _Summary(health: health),
        for (final section in sections) ...[
          const SizedBox(height: AppSpacing.xl),
          section,
        ],
      ],
    );
  }
}

/// O retrato em poucas linhas: quantas músicas, quantas em aprendizado, e
/// quanto do repertório a equipe de fato canta.
class _Summary extends StatelessWidget {
  const _Summary({required this.health});

  final RepertoireHealth health;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final apoio = [
      if (health.learningCount > 0)
        health.learningCount == 1
            ? '1 em aprendizado'
            : '${health.learningCount} em aprendizado',
      if (health.neverPlayedCount > 0)
        health.neverPlayedCount == 1
            ? '1 ainda não entrou em escala'
            : '${health.neverPlayedCount} ainda não entraram em escala',
    ].join(' · ');

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            health.activeCount == 1
                ? '1 música no repertório'
                : '${health.activeCount} músicas no repertório',
            style: theme.textTheme.titleMedium,
          ),
          if (apoio.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(apoio, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Músicas cantadas',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Três colunas com fio entre elas, como os fatos da tela da música:
          // os números ficam comparáveis de relance.
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: health.usedInLast3Months,
                  label: 'em 3 meses',
                ),
              ),
              Container(width: 1, height: 36, color: scheme.outlineVariant),
              Expanded(
                child: _Stat(
                  value: health.usedInLast6Months,
                  label: 'em 6 meses',
                ),
              ),
              Container(width: 1, height: 36, color: scheme.outlineVariant),
              Expanded(
                child: _Stat(
                  value: health.usedInLast12Months,
                  label: 'em 12 meses',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '$value músicas cantadas $label',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// Uma lista da saúde: as primeiras linhas e, havendo mais, "Ver todas".
///
/// "Ver todas" abre a lista inteira numa tela própria, com rolagem preguiçosa:
/// "Sem tom definido" pode ter centenas de hinos, e desenhá-los todos dentro
/// desta tela travaria a rolagem de quem só queria as cinco primeiras.
class _HealthSection extends StatelessWidget {
  const _HealthSection({
    required this.title,
    required this.subtitle,
    required this.songs,
    required this.details,
  });

  final String title;
  final String subtitle;
  final List<RepertoireHealthSong> songs;
  final String? Function(RepertoireHealthSong song) details;

  @override
  Widget build(BuildContext context) {
    return AppGroup(
      title: title,
      subtitle: subtitle,
      dividerIndent: AppGroup.textIndent,
      children: [
        for (final song in songs.take(_preview))
          _HealthRow(song: song, details: details(song)),
        if (songs.length > _preview)
          AppGroupRow(
            title: 'Ver todas (${songs.length})',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _HealthListScreen(
                  title: title,
                  songs: songs,
                  details: details,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.song, required this.details});

  final RepertoireHealthSong song;
  final String? details;

  @override
  Widget build(BuildContext context) {
    return AppGroupRow(
      title: song.displayTitle,
      subtitle: details,
      onTap: () => context.push('/equipe/musicas/${song.songId}'),
    );
  }
}

class _HealthListScreen extends StatelessWidget {
  const _HealthListScreen({
    required this.title,
    required this.songs,
    required this.details,
  });

  final String title;
  final List<RepertoireHealthSong> songs;
  final String? Function(RepertoireHealthSong song) details;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: AppContentWidth.reading(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            itemCount: songs.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: AppSpacing.lg,
              endIndent: AppSpacing.lg,
              color: scheme.outlineVariant,
            ),
            itemBuilder: (_, index) => _HealthRow(
              song: songs[index],
              details: details(songs[index]),
            ),
          ),
        ),
      ),
    );
  }
}
