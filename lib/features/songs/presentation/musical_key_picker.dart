import 'package:flutter/material.dart';

import '../../../core/responsive/adaptive_dialog.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_choice_bar.dart';
import '../domain/musical_keys.dart';

/// O que o seletor devolveu. Nulo é "fechou sem escolher"; `(key: null)` é
/// "tirou o tom" — sem o registro, as duas coisas chegariam iguais.
typedef MusicalKeyChoice = ({String? key});

/// Escolher um tom: uma folha curta, e não uma lista de 34 linhas.
///
/// **Uma grade de três linhas por sete colunas.** Cada coluna é uma letra; a
/// linha do meio é a nota natural, a de cima o sustenido e a de baixo o bemol —
/// o acidente que sobe fica em cima, o que desce fica embaixo. Quem procura
/// "Bb" acha o B e desce um. Os buracos são E#, B#, Fb e Cb, que não entram.
///
/// Maior e menor numa barra acima da grade, em vez de duas grades: dobraria a
/// altura da folha para mostrar a mesma letra com um `m` do lado.
///
/// Tocar num tom **escolhe e fecha**. Um botão "Confirmar" seria um segundo
/// toque para uma escolha que já está feita.
Future<MusicalKeyChoice?> showMusicalKeyPicker(
  BuildContext context, {
  required String title,
  String? selected,
}) {
  return showAdaptiveSheet<MusicalKeyChoice>(
    context: context,
    maxWidth: 420,
    useRootNavigator: true,
    builder: (_) => _MusicalKeyPicker(
      title: title,
      selected: normalizeMusicalKey(selected),
      canClear: (selected ?? '').trim().isNotEmpty,
    ),
  );
}

class _MusicalKeyPicker extends StatefulWidget {
  const _MusicalKeyPicker({
    required this.title,
    required this.selected,
    required this.canClear,
  });

  final String title;

  /// Já na grafia da lista. Nulo também quando o valor atual é anotação
  /// antiga — nada na grade fica marcado, mas "Tirar tom" continua valendo.
  final String? selected;
  final bool canClear;

  @override
  State<_MusicalKeyPicker> createState() => _MusicalKeyPickerState();
}

class _MusicalKeyPickerState extends State<_MusicalKeyPicker> {
  late bool _minor = widget.selected != null && isMinorKey(widget.selected!);

  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.title, style: theme.textTheme.titleLarge),
                ),
                if (widget.canClear)
                  TextButton(
                    onPressed: () => Navigator.pop<MusicalKeyChoice>(
                      context,
                      (key: null),
                    ),
                    child: const Text('Tirar tom'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppChoiceBar<bool>(
              expanded: true,
              value: _minor,
              onChanged: (minor) => setState(() => _minor = minor),
              options: const [
                AppChoice(value: false, label: 'Maior'),
                AppChoice(value: true, label: 'Menor'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final accidental in KeyAccidental.values) ...[
              if (accidental != KeyAccidental.sharp)
                const SizedBox(height: _gap),
              Row(
                children: [
                  for (final (i, letter) in musicalKeyLetters.indexed) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    Expanded(
                      child: switch (musicalKeyRoot(letter, accidental)) {
                        null => const SizedBox.shrink(),
                        final root => _KeyCell(
                            musicalKey: _minor ? '${root}m' : root,
                            selected: widget.selected ==
                                (_minor ? '${root}m' : root),
                          ),
                      },
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KeyCell extends StatelessWidget {
  const _KeyCell({required this.musicalKey, required this.selected});

  final String musicalKey;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(AppSpacing.radiusSm);

    return Semantics(
      button: true,
      selected: selected,
      label: musicalKeySpokenLabel(musicalKey),
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerHigh,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => Navigator.pop<MusicalKeyChoice>(
            context,
            (key: musicalKey),
          ),
          child: SizedBox(
            height: 44,
            child: Center(
              // "C#m" a 320px de tela e com fonte grande: encolhe em vez de
              // cortar o `m`, que é justamente o que diferencia os dois tons.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    musicalKey,
                    maxLines: 1,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// O campo de tom num formulário: parece um campo, abre o seletor.
///
/// Não há teclado — é justamente o que deixa de existir. O valor anotado antes
/// da lista ("G (capo 2)") aparece como está e é salvo como está: a pessoa que
/// abriu a música para mudar o andamento não pode perder o tom no caminho.
class MusicalKeyField extends StatelessWidget {
  const MusicalKeyField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helperText,
    this.enabled = true,
  });

  final String label;

  /// Nulo é "sem tom".
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? helperText;
  final bool enabled;

  Future<void> _open(BuildContext context) async {
    final choice = await showMusicalKeyPicker(
      context,
      title: label,
      selected: value,
    );
    if (choice != null) onChanged(choice.key);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = (value ?? '').trim();
    final legacy = current.isNotEmpty && normalizeMusicalKey(current) == null;

    return Semantics(
      button: enabled,
      child: InkWell(
        onTap: enabled ? () => _open(context) : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InputDecorator(
          isEmpty: current.isEmpty,
          decoration: InputDecoration(
            labelText: label,
            enabled: enabled,
            helperText: legacy
                ? 'Anotado antes da lista de tons. Fica assim até você '
                    'escolher outro.'
                : helperText,
            helperMaxLines: 2,
            suffixIcon: const Icon(Icons.unfold_more_rounded),
          ),
          child: Text(
            current,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
