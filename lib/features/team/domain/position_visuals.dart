import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Icone e emoji de cada funcao da equipe.
///
/// A escolha e pelo **nome**, nao pela categoria: "Guitarra" e "Bateria" sao
/// ambas `INSTRUMENT`, e um icone unico para as duas nao ajudaria em nada a
/// bater o olho e reconhecer -- que e a razao de existir o icone. A categoria
/// entra so como rede de seguranca, para funcoes que a equipe criou por conta
/// propria ("Sax", "Cello").
///
/// O nome precisa resolver sozinho na maioria dos casos porque o detalhe da
/// escala nao recebe a categoria: `AssignmentGroup` so traz `positionName`.
///
/// **Violao, Guitarra e Baixo compartilham o mesmo icone.** Nenhum conjunto de
/// icones (nem os emojis do Unicode) distingue os tres; o nome aparece sempre
/// ao lado, entao o icone e ancora visual, nao identificacao.
///
/// Retorna [FaIconData] (nao [IconData]): no Font Awesome 11 / Flutter 3.44,
/// `FaIconData` deixou de implementar `IconData`, e [FaIcon] so aceita o
/// wrapper. Por isso teclado usa `keyboard` do FA e nao `Icons.piano`.
class PositionVisuals {
  const PositionVisuals._();

  /// Icone para a interface. Use com [FaIcon] -- varios glifos do Font Awesome
  /// sao mais largos que altos e estourariam a caixa quadrada do [Icon].
  static FaIconData icon(String name, {String? category}) {
    return switch (_key(name)) {
      'vocal' => FontAwesomeIcons.microphoneLines,
      'cordas' => FontAwesomeIcons.guitar,
      'teclado' => FontAwesomeIcons.keyboard,
      'bateria' => FontAwesomeIcons.drum,
      'percussao' => FontAwesomeIcons.drumSteelpan,
      'multimidia' => FontAwesomeIcons.video,
      'som' => FontAwesomeIcons.sliders,
      'direcao' => FontAwesomeIcons.personChalkboard,
      _ => _iconForCategory(category),
    };
  }

  /// Emoji para o texto compartilhado no WhatsApp, onde nao ha como renderizar
  /// um icone do app.
  static String emoji(String name, {String? category}) {
    return switch (_key(name)) {
      'vocal' => '🎤',
      'cordas' => '🎸',
      'teclado' => '🎹',
      'bateria' || 'percussao' => '🥁',
      'multimidia' => '🎥',
      'som' => '🎚️',
      'direcao' => '🎯',
      _ => _emojiForCategory(category),
    };
  }

  static FaIconData _iconForCategory(String? category) => switch (category) {
        'VOCAL' => FontAwesomeIcons.microphoneLines,
        'TECH' => FontAwesomeIcons.sliders,
        _ => FontAwesomeIcons.music,
      };

  static String _emojiForCategory(String? category) => switch (category) {
        'VOCAL' => '🎤',
        'TECH' => '🎚️',
        _ => '🎵',
      };

  /// Reduz o nome cadastrado a um dos grupos que tem icone proprio.
  ///
  /// Compara sem acento e em minusculas porque o nome e digitavel: a equipe
  /// pode ter cadastrado "Multimidia", "multimídia" ou "MULTIMÍDIA".
  static String _key(String name) {
    final n = _normalize(name);

    if (n.contains('vocal') || n.contains('voz') || n.contains('cantor')) {
      return 'vocal';
    }
    if (n.contains('violao') ||
        n.contains('guitarra') ||
        n.contains('baixo') ||
        n.contains('viola')) {
      return 'cordas';
    }
    if (n.contains('teclado') || n.contains('piano') || n.contains('org')) {
      return 'teclado';
    }
    if (n.contains('bateria') || n.contains('cajon')) {
      return 'bateria';
    }
    if (n.contains('percuss')) {
      return 'percussao';
    }
    // Antes de "som": "direção do culto" nao contem "som", mas manter a ordem
    // explicita evita surpresa se alguem cadastrar "direcao de som".
    if (n.contains('direc') || n.contains('dirigente')) {
      return 'direcao';
    }
    if (n.contains('multimidia') ||
        n.contains('midia') ||
        n.contains('projec') ||
        n.contains('datashow') ||
        n.contains('slide') ||
        n.contains('transmiss')) {
      return 'multimidia';
    }
    if (n.contains('som') || n.contains('audio') || n.contains('sonoplast')) {
      return 'som';
    }

    return '';
  }

  static const _accents = {
    'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
    'é': 'e', 'ê': 'e', 'è': 'e', 'ë': 'e',
    'í': 'i', 'î': 'i', 'ì': 'i', 'ï': 'i',
    'ó': 'o', 'ô': 'o', 'õ': 'o', 'ò': 'o', 'ö': 'o',
    'ú': 'u', 'û': 'u', 'ù': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };

  static String _normalize(String value) {
    final lower = value.toLowerCase().trim();
    final buffer = StringBuffer();
    for (final char in lower.split('')) {
      buffer.write(_accents[char] ?? char);
    }
    return buffer.toString();
  }
}
