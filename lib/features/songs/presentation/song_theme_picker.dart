import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../domain/song_themes.dart';

/// Escolher temas — **o** controle, para as três telas que precisam disso: o
/// filtro do repertório, a edição de uma música e o cadastro.
///
/// São 82 temas. Um `DropdownButton` com 82 linhas é o que se faz quando não se
/// olha para o problema: no celular ele abre uma lista que cobre a tela, rola
/// sem referência nenhuma e só deixa escolher **um**. Aqui o desenho parte de
/// três fatos:
///
/// 1. **Quem procura sabe o nome.** "Ceia", "Natal", "Redenção" — o campo de
///    busca no topo resolve em duas letras, sem acento (`gracas` acha "Ações de
///    Graças").
/// 2. **Quem não sabe precisa ver o vocabulário.** Por isso a lista aparece
///    inteira antes de qualquer busca, e o teclado **não** abre sozinho: com
///    ele aberto sobraria meia dúzia de temas visíveis, e a pessoa teria de
///    adivinhar o que existe para poder digitar.
/// 3. **A escolha é múltipla e precisa estar à vista.** O que já foi marcado
///    sobe para o topo, em etiquetas com "x": conferir e desfazer sem rolar
///    atrás do que se marcou há dez segundos.
///
/// Etiquetas (`FilterChip`) e não linhas com caixa de seleção: cabem três por
/// linha em vez de uma, o que transforma 82 linhas de rolagem em ~25 — e é a
/// forma que a informação já tem no resto do app.
Future<Set<String>?> showSongThemePicker(
  BuildContext context, {
  required Set<String> selected,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SongThemePicker(initial: selected),
  );
}

class _SongThemePicker extends StatefulWidget {
  const _SongThemePicker({required this.initial});

  final Set<String> initial;

  @override
  State<_SongThemePicker> createState() => _SongThemePickerState();
}

class _SongThemePickerState extends State<_SongThemePicker> {
  late final Set<String> _draft = {...widget.initial};
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(String theme) {
    setState(() {
      if (!_draft.remove(theme)) _draft.add(theme);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final resultados = searchSongThemes(_search);
    final buscando = _search.trim().isNotEmpty;

    // Marcados sobem para o topo e saem da lista de baixo: repetidos nos dois
    // lugares, a mesma etiqueta apareceria duas vezes com estados iguais e o
    // topo deixaria de ser "o que você escolheu" para virar decoração.
    final disponiveis = resultados.where((t) => !_draft.contains(t)).toList();

    return PopScope(
      // Arrastar a folha para baixo é o gesto natural de "terminei", não de
      // "desisti": não há nada destrutivo aqui, e perder cinco toques por um
      // gesto que o Android inteiro usa para fechar seria o tipo de castigo
      // que ninguém entende. Fechar por qualquer caminho aplica o rascunho.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _draft);
      },
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: ListenableBuilder(
                listenable: _searchController,
                builder: (context, _) => TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar tema',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar busca',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                          ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.lg,
                  AppSpacing.screenPadding,
                  AppSpacing.lg,
                ),
                children: [
                  if (_draft.isNotEmpty) ...[
                    _Legenda(
                      'Escolhidos',
                      // O botão só existe quando há o que limpar.
                      onClear: () => setState(_draft.clear),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        // Na ordem do catálogo, e não na de escolha: a lista
                        // não pode se remexer entre um toque e o seguinte.
                        for (final tema in songThemeValues)
                          if (_draft.contains(tema))
                            InputChip(
                              label: Text(songThemeLabel(tema)),
                              selected: true,
                              showCheckmark: false,
                              onDeleted: () => _toggle(tema),
                              deleteIcon: const Icon(
                                Icons.close_rounded,
                                size: 16,
                              ),
                              deleteButtonTooltipMessage:
                                  'Tirar ${songThemeLabel(tema)}',
                              onSelected: (_) => _toggle(tema),
                            ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  if (disponiveis.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xl),
                      child: Text(
                        buscando
                            ? 'Nenhum tema com esse nome.'
                            : 'Todos os temas já estão escolhidos.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else ...[
                    if (_draft.isNotEmpty || buscando)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _Legenda(
                          buscando ? 'Resultados' : 'Outros temas',
                        ),
                      ),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final tema in disponiveis)
                          FilterChip(
                            label: Text(songThemeLabel(tema)),
                            selected: false,
                            onSelected: (_) => _toggle(tema),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // `SafeArea` no rodapé: a folha vai até embaixo e o botão ficaria
            // por baixo da barra de navegação do Android sem isso.
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.sm,
                  AppSpacing.screenPadding,
                  AppSpacing.lg,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _draft),
                    child: Text(
                      _draft.isEmpty
                          ? 'Pronto'
                          : 'Pronto · ${_draft.length} '
                              '${_draft.length == 1 ? 'tema' : 'temas'}',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda(this.text, {this.onClear});

  final String text;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (onClear != null)
          TextButton(onPressed: onClear, child: const Text('Limpar')),
      ],
    );
  }
}

/// Os temas de uma música, em etiquetas.
///
/// Um componente só para a lista de leitura porque ela aparece no detalhe da
/// música e no formulário, e as duas precisam dizer a mesma coisa do mesmo
/// jeito. Vazio, some — um rótulo "Temas" seguido de nada é pior que nada.
class SongThemeChips extends StatelessWidget {
  const SongThemeChips({super.key, required this.themes, this.onTap});

  final List<String> themes;

  /// Quando informado, cada etiqueta vira botão (abre o seletor).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (themes.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final tema in themes)
          onTap == null
              ? Chip(
                  label: Text(songThemeLabel(tema)),
                  // A etiqueta é informação, não alvo de toque: sem o recuo
                  // extra do Material ela deixa de parecer um botão desligado.
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                )
              : ActionChip(
                  label: Text(songThemeLabel(tema)),
                  onPressed: onTap,
                ),
      ],
    );
  }
}
