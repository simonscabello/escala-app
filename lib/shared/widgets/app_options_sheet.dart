import 'package:flutter/material.dart';

import '../../core/responsive/adaptive_dialog.dart';
import '../../core/theme/app_spacing.dart';

/// Uma opção de [showAppOptionsSheet].
class AppOption<T> {
  const AppOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
}

/// "Escolha uma destas", quando as opções não cabem numa barra.
///
/// É o que o campo de seleção abre (gênero), o que o seletor de equipe abre e o
/// filtro de momento do culto. Folha no celular, diálogo no monitor
/// ([showAdaptiveSheet]); a escolhida vem marcada, e tocar numa opção fecha.
///
/// Devolve um registro, e não o valor solto: `null` como **opção** ("Não
/// informar", "Qualquer momento") precisa ser diferente de fechar a folha sem
/// escolher nada.
Future<({T value})?> showAppOptionsSheet<T>({
  required BuildContext context,
  required String title,
  required List<AppOption<T>> options,
  required T selected,
  String? subtitle,
}) {
  return showAdaptiveSheet<({T value})>(
    context: context,
    maxWidth: 420,
    builder: (sheetContext) => _OptionsSheet<T>(
      title: title,
      subtitle: subtitle,
      options: options,
      selected: selected,
    ),
  );
}

class _OptionsSheet<T> extends StatelessWidget {
  const _OptionsSheet({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
  });

  final String title;
  final String? subtitle;
  final List<AppOption<T>> options;
  final T selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            for (final option in options)
              _OptionRow(
                option: option,
                selected: option.value == selected,
                onTap: () => Navigator.of(context).pop((value: option.value)),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                if (option.icon != null) ...[
                  Icon(option.icon, size: 22, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: selected ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                      if (option.subtitle != null)
                        Text(
                          option.subtitle!,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: AppSpacing.md),
                  Icon(Icons.check_rounded, size: 20, color: scheme.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
