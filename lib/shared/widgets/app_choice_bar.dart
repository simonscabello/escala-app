import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';

class AppChoice<T> {
  const AppChoice({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// "Escolha uma destas" — **o** controle, para todo o app.
///
/// Antes existiam três respostas para a mesma pergunta: pílulas à mão na
/// agenda, `ChoiceChip` no repertório e `SegmentedButton` no perfil. Três
/// alturas, três raios, três jeitos de mostrar o que está escolhido — e a
/// pessoa reaprendendo o controle a cada tela.
///
/// A escolhida fica **preenchida no azul da marca**, e não só com uma borda:
/// borda sozinha é o tipo de sinal que se perde num celular ao sol, e que
/// desaparece de vez para quem enxerga pouco contraste. O `Semantics` marca a
/// opção como selecionada, então o leitor de tela anuncia o estado em vez de
/// ler dois botões iguais.
class AppChoiceBar<T> extends StatelessWidget {
  const AppChoiceBar({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.expanded = false,
  });

  final List<AppChoice<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Ocupa a largura recebida, dividida igualmente entre as opções.
  ///
  /// O padrão (`false`) é a barra do tamanho do conteúdo, rolando na horizontal
  /// quando não couber — é o que a agenda quer, com duas opções de comprimentos
  /// bem diferentes encostadas num canto.
  ///
  /// `true` é para quando a barra **é** o bloco, e não um filtro no canto: aí
  /// um segmento que rolou para fora da tela esconde uma opção que a pessoa
  /// precisa encontrar. É o caso do seletor de tema no Perfil, onde as três
  /// alternativas têm o mesmo peso. Dividida em partes iguais, cada segmento
  /// ganha um alvo de toque previsível — e quando o rótulo não cabe ao lado do
  /// ícone, **todos** passam a mostrar o ícone em cima, de uma vez.
  final bool expanded;

  /// A folga entre a borda da barra e os segmentos.
  static const double _barPadding = 3;

  @override
  Widget build(BuildContext context) {
    if (!expanded) return _bar(context, stacked: false);

    // A decisão de empilhar é de quem vê a barra inteira, e não de cada
    // segmento: medida um a um, "Claro" caberia deitado enquanto "Sistema"
    // subiria o ícone — três opções iguais desenhadas de dois jeitos na mesma
    // linha.
    return LayoutBuilder(
      builder: (context, constraints) => _bar(
        context,
        stacked: _needsStacking(context, constraints.maxWidth),
      ),
    );
  }

  Widget _bar(BuildContext context, {required bool stacked}) {
    final scheme = Theme.of(context).colorScheme;

    final bar = Container(
      padding: const EdgeInsets.all(_barPadding),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final option in options)
            if (expanded)
              Expanded(
                child: _Segment(
                  option: option,
                  selected: option.value == value,
                  expanded: true,
                  stacked: stacked,
                  onTap: () => onChanged(option.value),
                ),
              )
            else
              _Segment(
                option: option,
                selected: option.value == value,
                onTap: () => onChanged(option.value),
              ),
        ],
      ),
    );

    if (expanded) return bar;

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        // Rótulo comprido com a fonte do sistema aumentada estourava a linha.
        // Rolar é melhor que cortar o texto de uma opção.
        scrollDirection: Axis.horizontal,
        child: bar,
      ),
    );
  }

  /// Cabe ícone e rótulo lado a lado em **todos** os segmentos?
  ///
  /// Mede o texto com a fonte e a escala que a pessoa escolheu no aparelho:
  /// "texto grande" ligado no Android é comum entre quem usa este app, e é
  /// exatamente o caso em que uma conta feita com números fixos erra.
  bool _needsStacking(BuildContext context, double maxWidth) {
    if (!maxWidth.isFinite || options.isEmpty) return false;

    final theme = Theme.of(context);
    final style = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final segment = (maxWidth - _barPadding * 2) / options.length;

    for (final option in options) {
      final painter = TextPainter(
        text: TextSpan(text: option.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      final needed = painter.width +
          (option.icon == null ? 0 : _iconSize + _iconGap) +
          AppSpacing.sm * 2;
      painter.dispose();
      if (needed > segment) return true;
    }
    return false;
  }
}

const double _iconSize = 16;
const double _iconGap = 6;

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.option,
    required this.selected,
    required this.onTap,
    this.expanded = false,
    this.stacked = false,
  });

  final AppChoice<T> option;
  final bool selected;
  final VoidCallback onTap;

  /// O segmento recebe uma fatia fixa da largura, em vez de pedir a sua.
  final bool expanded;

  /// Ícone em cima do rótulo, para quando não cabem lado a lado.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.onSurfaceVariant;

    final icon = option.icon == null
        ? null
        : Icon(option.icon, size: _iconSize, color: foreground);
    final label = Text(
      option.label,
      textAlign: TextAlign.center,
      maxLines: 1,
      // Em partes iguais o segmento tem largura fixa: sem isto, o rótulo que
      // não coubesse estouraria a barra em vez de encurtar.
      overflow: expanded ? TextOverflow.ellipsis : TextOverflow.clip,
      style: theme.textTheme.labelLarge?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w600,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: EdgeInsets.symmetric(
                // Dividido em partes iguais, o segmento não gasta 16px de folga
                // de cada lado: a folga vem da divisão.
                horizontal: expanded ? AppSpacing.sm : AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              alignment: Alignment.center,
              child: stacked
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          icon,
                          const SizedBox(height: 2),
                        ],
                        label,
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          icon,
                          const SizedBox(width: _iconGap),
                        ],
                        if (expanded) Flexible(child: label) else label,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
