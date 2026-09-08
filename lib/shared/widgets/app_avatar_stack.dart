import 'package:flutter/material.dart';

import 'app_avatar.dart';

/// Quem está nisto, em pilha: alguns rostos sobrepostos e "+N" no fim.
///
/// **Não é enfeite: é a resposta a "a escala já está montada?"** antes de a
/// pessoa ler o número escrito ao lado. Três rostos e um "+3" dizem "tem
/// gente"; um quadro vazio diz o contrário, e os dois são lidos de relance.
///
/// **A listagem da agenda não devolve foto** — ela traz o nome de quem está
/// escalado, e nada mais. Por isso a pilha cai sempre na inicial do
/// [AppAvatar], que é justamente o caminho já previsto por ele para foto
/// ausente. Buscar as fotos aqui custaria uma requisição por escala para
/// enfeitar um canto de cartão; quando o dado aparecer na resposta, [people]
/// já aceita a URL e nada mais muda.
///
/// O anel em volta de cada rosto é da **cor do que está atrás da pilha**, e não
/// uma borda clara fixa: é ele que separa um avatar do vizinho sobreposto, e
/// sobre a manchete violeta uma borda branca acenderia a pilha inteira.
class AppAvatarStack extends StatelessWidget {
  const AppAvatarStack({
    super.key,
    required this.people,
    required this.ringColor,
    this.max = 4,
    this.radius = 15,
    this.background,
    this.foreground,
    this.semanticsLabel,
  });

  final List<({String name, String? imageUrl})> people;

  /// A cor da superfície embaixo da pilha.
  final Color ringColor;

  /// Quantos rostos antes do "+N".
  final int max;

  final double radius;

  /// A tinta dos círculos — dos rostos e do "+N".
  ///
  /// Vale para os dois de propósito: com o "+N" numa cor e as iniciais em
  /// outra, a pilha se lê como duas coisas diferentes encostadas.
  final Color? background;
  final Color? foreground;

  /// O que o leitor de tela anuncia. O padrão é calar: a contagem vem escrita
  /// ao lado da pilha, e ler os rostos repetiria a frase.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Com um a mais que o teto, mostrar "+1" gastaria a mesma largura de
    // mostrar o próprio rosto. O corte só compensa a partir de dois.
    final shown = people.length <= max + 1 ? people.length : max;
    final hidden = people.length - shown;

    final ring = radius * 0.14;
    final step = radius * 1.42;

    Widget wrap(Widget child) {
      return Container(
        padding: EdgeInsets.all(ring),
        decoration: BoxDecoration(color: ringColor, shape: BoxShape.circle),
        child: child,
      );
    }

    final tiles = <Widget>[
      for (var i = 0; i < shown; i++)
        Padding(
          padding: EdgeInsets.only(left: i * step),
          child: wrap(
            AppAvatar(
              name: people[i].name,
              imageUrl: people[i].imageUrl,
              radius: radius,
              backgroundColor: background,
              foregroundColor: foreground,
            ),
          ),
        ),
      if (hidden > 0)
        Padding(
          padding: EdgeInsets.only(left: shown * step),
          child: wrap(
            CircleAvatar(
              radius: radius,
              backgroundColor: background ?? scheme.primaryContainer,
              child: Text(
                '+$hidden',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: foreground ?? scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
    ];

    final slots = shown + (hidden > 0 ? 1 : 0);
    final width = (slots - 1) * step + (radius + ring) * 2;

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: (radius + ring) * 2,
        child: Stack(children: tiles),
      ),
    );
  }
}
