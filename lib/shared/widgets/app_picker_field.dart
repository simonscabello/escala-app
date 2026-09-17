import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Um campo de formulário que abre um seletor: data, hora, tom, gênero.
///
/// **Era escrito de três jeitos.** Um botão contornado na data da escala e no
/// horário do culto; um campo com o toque por fora na data de nascimento; e um
/// campo em que só o **texto** respondia ao toque, no evento da equipe — tocar
/// na borda ou no ícone não abria nada. Três aparências no mesmo formulário
/// fazem a pessoa procurar onde toca, e o terceiro errava o alvo.
///
/// O modelo é o campo de tom: parece um campo de texto (mesma altura, mesma
/// borda, rótulo flutuante), o campo **inteiro** é o alvo, e a seta de abrir
/// fica à direita. Quando o vazio é uma resposta legítima ([onClear]), a seta
/// vira um "x" para limpar.
class AppPickerField extends StatelessWidget {
  const AppPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder,
    this.icon,
    this.helperText,
    this.onClear,
    this.clearTooltip = 'Limpar',
    this.enabled = true,
  });

  final String label;

  /// O que está escolhido. Nulo mostra [placeholder] (ou só o rótulo).
  final String? value;

  final VoidCallback onTap;

  /// O texto do vazio, quando ele diz alguma coisa ("Sem hora definida").
  final String? placeholder;

  final IconData? icon;
  final String? helperText;

  /// Limpa o valor. Só aparece com valor escolhido.
  final VoidCallback? onClear;
  final String clearTooltip;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasValue = value != null && value!.isNotEmpty;
    final text = hasValue ? value! : (placeholder ?? '');

    return Semantics(
      button: enabled,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InputDecorator(
          isEmpty: !hasValue && placeholder == null,
          decoration: InputDecoration(
            labelText: label,
            enabled: enabled,
            helperText: helperText,
            helperMaxLines: 2,
            prefixIcon: icon == null ? null : Icon(icon, size: 20),
            suffixIcon: hasValue && onClear != null
                ? IconButton(
                    tooltip: clearTooltip,
                    onPressed: enabled ? onClear : null,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  )
                : const Icon(Icons.unfold_more_rounded),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: hasValue ? null : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
