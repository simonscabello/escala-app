import '../../../core/text/text_search.dart';
import '../data/song_repository.dart';
import 'song_models.dart';

/// Uma linha da lista do seletor: ou um marcador de seção, ou uma música.
sealed class SongSectionEntry {
  const SongSectionEntry();
}

/// "A", "M", "300 – 399". O que separa um trecho da lista do seguinte.
final class SongSectionHeader extends SongSectionEntry {
  const SongSectionHeader(this.label);

  final String label;
}

final class SongSectionItem extends SongSectionEntry {
  const SongSectionItem(this.song);

  final Song song;
}

/// Quebra a lista em seções — **só quando isso ajuda**.
///
/// O acervo desta igreja tem 861 músicas. Rolar isso atrás de um cântico sem
/// nenhum ponto de referência é o que faz a lista parecer não ter fim: o olho
/// não tem como saber se já passou do "M" ou se ainda está no "C".
///
/// Três regras decidem se a seção aparece, e todas existem para o marcador não
/// virar enfeite:
///
/// 1. **Buscando, não agrupa.** O resultado de "oferta" são quatro linhas
///    ordenadas por relevância; um cabeçalho "O" acima delas não orienta nada e
///    ainda quebra a ordem que o servidor escolheu.
/// 2. **Lista curta, não agrupa.** Abaixo de [_minimoParaAgrupar] a lista cabe
///    quase toda na tela, e marcador ali é ruído puro.
/// 3. **Hino se agrupa por número, não por letra.** O hinário é percorrido pelo
///    número — é assim que a igreja chama o hino ("142", não "Pão da Vida") e é
///    a ordem em que o provider já devolve. Agrupar hino por letra do título
///    embaralharia justamente a ordem que serve.
List<SongSectionEntry> buildSongSections(
  List<Song> songs, {
  required SongFilter filter,
  required bool searching,
}) {
  if (songs.isEmpty) return const [];

  if (searching || songs.length < _minimoParaAgrupar) {
    return [for (final song in songs) SongSectionItem(song)];
  }

  return filter == SongFilter.hinos
      ? _porFaixaDeNumero(songs)
      : _porLetra(songs);
}

/// Abaixo disto a lista cabe quase toda na tela e o marcador só atrapalha.
const int _minimoParaAgrupar = 15;

/// Ordena por título sem acento e marca a troca de letra inicial.
///
/// A ordenação é refeita aqui em vez de confiar na que veio do servidor: se
/// vierem duas faixas da mesma letra separadas por outra, o mesmo cabeçalho
/// apareceria duas vezes — e uma lista com dois "M" parece defeito, não seção.
List<SongSectionEntry> _porLetra(List<Song> songs) {
  final ordenadas = [...songs]
    ..sort((a, b) => _chaveDeOrdem(a.title).compareTo(_chaveDeOrdem(b.title)));

  final entries = <SongSectionEntry>[];
  String? letraAtual;

  for (final song in ordenadas) {
    final letra = _letraInicial(song.title);
    if (letra != letraAtual) {
      letraAtual = letra;
      entries.add(SongSectionHeader(letra));
    }
    entries.add(SongSectionItem(song));
  }
  return entries;
}

/// Marca a virada de centena: "1 – 99", "100 – 199", "500 – 599".
///
/// Centena, e não dezena: o marcador serve para saber onde se está enquanto a
/// lista corre depressa, e um cabeçalho a cada dez linhas viraria listra. Quem
/// sabe o número exato digita na busca, que compara o número do hino.
List<SongSectionEntry> _porFaixaDeNumero(List<Song> songs) {
  final entries = <SongSectionEntry>[];
  int? faixaAtual;

  for (final song in songs) {
    final numero = song.hymnNumber;
    if (numero == null) {
      entries.add(SongSectionItem(song));
      continue;
    }

    final faixa = numero ~/ 100;
    if (faixa != faixaAtual) {
      faixaAtual = faixa;
      final inicio = faixa * 100;
      entries.add(
        SongSectionHeader('${inicio == 0 ? 1 : inicio} – ${inicio + 99}'),
      );
    }
    entries.add(SongSectionItem(song));
  }
  return entries;
}

/// A inicial em maiúscula e sem acento: "Água" e "Amor" caem no mesmo "A".
///
/// O que não começa com letra — número, aspas, parênteses — vai para "#", no
/// fim. São poucos títulos e espalhá-los entre as letras é pior que juntá-los.
String _letraInicial(String title) {
  final chave = _chaveDeOrdem(title);
  if (chave.isEmpty) return '#';
  final primeira = chave[0];
  return RegExp('[a-z]').hasMatch(primeira) ? primeira.toUpperCase() : '#';
}

/// Minúscula, sem acento e sem os sinais que abrem alguns títulos.
///
/// Sem tirar o acento, "Água" vem depois de "Zelo" na ordem de caractere — o
/// código de "á" é maior que o de qualquer letra sem acento.
String _chaveDeOrdem(String title) {
  // "#" no fim: o caractere que abre o título não deve decidir a posição dele
  // antes do "a".
  final chave =
      normalizeForSearch(title).replaceAll(RegExp(r'^[^a-z0-9]+'), '');
  return chave.isEmpty ? '￿' : chave;
}
