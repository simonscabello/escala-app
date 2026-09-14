import '../../songs/domain/song_models.dart';
import '../../songs/domain/song_themes.dart';

/// Quantas músicas em aprendizado o cartão da Home mostra antes do "Ver
/// todas". Quatro cabem sem empurrar os avisos para fora da tela, e uma equipe
/// que aprende mais do que isso ao mesmo tempo já tem a lista no repertório.
const homeLearningPreviewCount = 4;

/// A linha de apoio de uma música no cartão "Estamos aprendendo":
/// `Artista · Tom G · Calma · Gratidão`.
///
/// Só o que ajuda a **estudar**: quem canta, em que tom a equipe faz, se é
/// calma ou agitada e sobre o que fala. Cada pedaço some quando não existe —
/// nenhum "—" de campo vazio —, e um tema só, porque a linha é uma.
String? learningSongDetails(Song song) {
  final parts = [
    if (song.artist != null && song.artist!.trim().isNotEmpty) song.artist!,
    if (song.defaultKey != null && song.defaultKey!.isNotEmpty)
      'Tom ${song.defaultKey}',
    if (song.pace != null) paceLabel(song.pace),
    if (song.themes.isNotEmpty) songThemeLabel(song.themes.first),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
