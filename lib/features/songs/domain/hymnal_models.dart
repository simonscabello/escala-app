/// Um hinário do banco: o livro de hinos que a igreja canta.
///
/// **Vem do servidor, e não de uma lista escrita aqui**, ao contrário de
/// `songThemes` e `kindLabel`. A diferença é o que cada um é: tema é
/// vocabulário fechado do app, e hinário é cadastro — a promessa desta
/// estrutura é que o quarto hinário entre por uma linha no banco, sem release
/// do APK. Uma cópia em Dart devolveria exatamente o acoplamento que o
/// `hymnNumber` do Cantor Cristão tinha.
class Hymnal {
  const Hymnal({
    required this.id,
    required this.slug,
    required this.name,
    required this.abbreviation,
    this.maxNumber,
  });

  factory Hymnal.fromJson(Map<String, dynamic> json) {
    return Hymnal(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      abbreviation: json['abbreviation'] as String,
      maxNumber: json['maxNumber'] as int?,
    );
  }

  final String id;

  /// Chave estável ("cantor-cristao"). Não aparece na tela.
  final String slug;

  /// "Cantor Cristão" — o nome por extenso, no seletor.
  final String name;

  /// "CC" — o que sai ao lado do número na escala e no WhatsApp.
  final String abbreviation;

  /// O último hino do livro, quando alguém conferiu. Nulo é "ninguém contou as
  /// páginas", e não "sem limite": o formulário só cobra faixa quando há uma.
  final int? maxNumber;
}

/// "Esta música é o 314 do Cantor Cristão."
///
/// A sigla e o nome vêm junto do servidor, e não buscados por id: são dois
/// campos curtos, e a alternativa seria toda tela que mostra uma música ter de
/// esperar a lista de hinários carregar antes de desenhar "314 CC".
class HymnalRef {
  const HymnalRef({
    required this.hymnalId,
    required this.name,
    required this.abbreviation,
    required this.number,
    this.slug = '',
    this.isPrimary = false,
  });

  factory HymnalRef.fromJson(Map<String, dynamic> json) {
    return HymnalRef(
      hymnalId: json['hymnalId'] as String,
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      abbreviation: json['abbreviation'] as String? ?? '',
      number: json['number'] as int,
      isPrimary: json['isPrimary'] as bool? ?? false,
    );
  }

  final String hymnalId;
  final String slug;
  final String name;
  final String abbreviation;
  final int number;

  /// Qual referência representa a música onde só cabe uma — a linha da escala
  /// e o texto do WhatsApp. O servidor garante exatamente uma por música e a
  /// devolve na frente da lista.
  final bool isPrimary;

  /// "314 CC" — número antes da sigla, que é como a igreja fala.
  String get label => '$number $abbreviation';

  Map<String, dynamic> toJson() => {
        'hymnalId': hymnalId,
        'number': number,
        'isPrimary': isPrimary,
      };
}

/// A referência que representa a música, ou nulo quando ela não está em
/// hinário nenhum — que é a maioria.
///
/// A primeira da lista: o servidor devolve a principal na frente. Percorrer
/// atrás de `isPrimary` daria o mesmo resultado e deixaria a tela decidir uma
/// coisa que já foi decidida.
HymnalRef? primaryHymnalRef(List<HymnalRef> refs) =>
    refs.isEmpty ? null : refs.first;
