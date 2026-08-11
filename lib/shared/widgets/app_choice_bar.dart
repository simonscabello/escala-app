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
  });

  final List<AppChoice<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        // Rótulo comprido com a fonte do sistema aumentada estourava a linha.
        // Rolar é melhor que cortar o texto de uma opção.
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options)
                _Segment(
                  option: option,
                  selected: option.value == value,
                  onTap: () => onChanged(option.value),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppChoice<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.onSurfaceVariant;

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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (option.icon != null) ...[
                    Icon(option.icon, size: 16, color: foreground),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    option.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
