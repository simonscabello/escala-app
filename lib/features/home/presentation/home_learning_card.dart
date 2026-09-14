import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_group.dart';
import '../../songs/data/song_repository.dart';
import '../domain/learning_songs.dart';

/// "Estamos aprendendo": as músicas marcadas como novas no repertório.
///
/// **Da equipe, e não de cada um.** Não há "pronto", "estudando" nem "não
/// conhece" por integrante, de propósito: o cartão lembra o que a equipe tem
/// para estudar, e acompanhar quem estudou seria vigiar quem canta.
///
/// Uma requisição própria, e magra: o servidor filtra (`?isNew=true`), e a
/// Home recebe as poucas linhas que mostra em vez do acervo inteiro. Carregando
/// ou com falha, o cartão **não existe** — como o "Próximo evento", ele não
/// pode esconder a manchete nem virar erro na porta de entrada do app.
class HomeLearningCard extends ConsumerWidget {
  const HomeLearningCard({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(learningSongsProvider(teamId)).valueOrNull;
    if (songs == null || songs.isEmpty) return const SizedBox.shrink();

    // O espaço de cima é do cartão, e não de quem o põe na tela: sem música
    // nova ele some inteiro, sem deixar um vão no fim da Home.
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: AppGroup(
        title: 'Estamos aprendendo',
        dividerIndent: AppGroup.textIndent,
        trailing: songs.length > homeLearningPreviewCount
            ? TextButton(
                // A aba "Novas" do repertório é a lista inteira, e é lá que a
                // marca se desliga quando a igreja já canta junto.
                onPressed: () => context.push('/equipe/musicas?aba=novas'),
                child: Text('Ver todas (${songs.length})'),
              )
            : null,
        children: [
          for (final song in songs.take(homeLearningPreviewCount))
            AppGroupRow(
              title: song.title,
              subtitle: learningSongDetails(song),
              onTap: () => context.push('/equipe/musicas/${song.id}'),
            ),
        ],
      ),
    );
  }
}
