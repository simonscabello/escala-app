/// Os tons que se escolhem para uma música — **lista fechada**, 17 maiores e
/// os mesmos 17 em menor.
///
/// O formato é o que o sistema já gravava: letra, acidente opcional e `m` para
/// menor (`G`, `F#`, `Bbm`). É o mesmo que o backend aceita do CifraClub
/// (`KEY_FORMAT`, `^[A-G][#b]?m?$`), então o tom da gravação lido de lá cai
/// sempre dentro da lista, e o "Usar F#" continua sendo um toque.
///
/// Sustenido **e** bemol para as cinco teclas pretas: a equipe que escreve
/// `G#` e a que escreve `Ab` estão as duas certas, e forçar uma grafia
/// reescreveria a cifra de metade das igrejas. Ficam de fora E#, B#, Fb e Cb —
/// são outro nome para uma tecla branca, e ninguém anota o tom assim.
///
/// **O servidor continua guardando texto.** A lista vale para a escolha, não
/// para a leitura: o "G (capo 2)" anotado antes dela continua aparecendo e
/// sendo salvo como está, até alguém escolher outro tom. Trancar o campo no
/// servidor faria a edição dessas músicas falhar — e o APK antigo, que manda
/// texto livre, também.
final List<String> musicalKeys = List.unmodifiable([
  for (final minor in [false, true])
    for (final letter in musicalKeyLetters)
      for (final accidental in KeyAccidental.values)
        if (musicalKeyRoot(letter, accidental) case final root?)
          minor ? '${root}m' : root,
]);

/// As colunas do seletor, na ordem em que os músicos contam as notas.
const musicalKeyLetters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

enum KeyAccidental { sharp, natural, flat }

/// `C#`, `Db`, `E`... ou nulo quando a combinação não entra na lista
/// (E#, B#, Fb, Cb).
String? musicalKeyRoot(String letter, KeyAccidental accidental) {
  return switch (accidental) {
    KeyAccidental.natural => letter,
    KeyAccidental.sharp => letter == 'E' || letter == 'B' ? null : '$letter#',
    KeyAccidental.flat => letter == 'F' || letter == 'C' ? null : '${letter}b',
  };
}

bool isMinorKey(String key) => key.endsWith('m');

final _keyFormat = RegExp(r'^([A-Ga-g])([#b]?)(m?)$');

/// O tom na grafia da lista, ou nulo quando o texto não é um tom dela.
///
/// Só conserta a caixa da letra (`g` → `G`, `f#m` → `F#m`), que é o erro de
/// digitação do campo livre antigo. Não adivinha nada além disso: `G (capo 2)`
/// e `Sol` voltam nulos, e quem chama decide mostrá-los como estão.
String? normalizeMusicalKey(String? raw) {
  final match = _keyFormat.firstMatch(raw?.trim() ?? '');
  if (match == null) return null;

  final key = '${match[1]!.toUpperCase()}${match[2]}${match[3]}';
  return musicalKeys.contains(key) ? key : null;
}

/// Como o leitor de tela diz o tom: "C#m" lido símbolo por símbolo vira
/// "C cerquilha m".
String musicalKeySpokenLabel(String key) {
  final minor = isMinorKey(key);
  final root = minor ? key.substring(0, key.length - 1) : key;
  final accidental = switch (root.length > 1 ? root[1] : '') {
    '#' => ' sustenido',
    'b' => ' bemol',
    _ => '',
  };
  return '${root[0]}$accidental ${minor ? 'menor' : 'maior'}';
}
