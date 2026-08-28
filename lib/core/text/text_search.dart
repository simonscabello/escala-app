/// Texto comparável: minúsculas, sem acento, sem espaço sobrando.
///
/// **Ninguém digita acento no celular.** Quem procura um tema escreve "acao de
/// gracas", quem procura uma música escreve "coracao" — e as duas coisas estão
/// gravadas com acento. Sem passar os dois lados por aqui, a busca não acha o
/// que está na tela logo abaixo do campo.
///
/// É a irmã da `normalizeSearch` do servidor (`song-search.ts`), que faz o
/// mesmo com a coluna `search_text`. Aqui ela serve ao que o app filtra
/// sozinho, sem ir à rede: a lista de temas e o nome das funções.
///
/// A tabela é explícita em vez de `unorm`/regex sobre NFD porque o Dart não
/// traz normalização Unicode na biblioteca padrão, e o alfabeto que interessa
/// (português, mais o "ñ" que aparece em nome de música em espanhol) cabe em
/// vinte e poucas linhas — menos que a dependência que resolveria isso.
String normalizeForSearch(String value) {
  final lower = value.toLowerCase().trim();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

const Map<String, String> _accents = {
  'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
  'é': 'e', 'ê': 'e', 'è': 'e', 'ë': 'e',
  'í': 'i', 'î': 'i', 'ì': 'i', 'ï': 'i',
  'ó': 'o', 'ô': 'o', 'õ': 'o', 'ò': 'o', 'ö': 'o',
  'ú': 'u', 'û': 'u', 'ù': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};
