import 'package:flutter/material.dart';

import '../../../core/responsive/adaptive_dialog.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/song_themes.dart';

/// Escolher temas — **o** controle, para as quatro telas que precisam disso: o
/// filtro do repertório, o seletor da escala, a edição de uma música e o
/// cadastro.
///
/// São 82 temas. O desenho parte de três fatos:
///
/// 1. **Quem procura sabe o nome.** "Ceia", "Natal", "Redenção" — o campo de
///    busca no topo resolve em duas letras, sem acento (`gracas` acha "Ações de
///    Graças").
/// 2. **Quem não sabe precisa ver o vocabulário.** Por isso a lista aparece
///    inteira antes de qualquer busca, e o teclado **não** abre sozinho.
/// 3. **A escolha é múltipla e precisa estar à vista.** O que já foi marcado
///    sobe para o topo, em etiquetas com "x": conferir e desfazer sem rolar
///    atrás do que se marcou há dez segundos.
///
/// A lista de baixo usa `CheckboxListTile` agrupada por letra — mesma referência
/// visual do repertório e alvos de toque de 48dp.
Future<Set<String>?> showSongThemePicker(
  BuildContext context, {
  required Set<String> selected,
}) {
  return showAdaptiveSheet<Set<String>>(
    context: context,
    maxWidth: 480,
    useRootNavigator: true,
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

    final disponiveis = resultados.where((t) => !_draft.contains(t)).toList();
    final grupos = buscando ? const <(String, List<String>)>[] : groupSongThemesByLetter(disponiveis);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _draft);
      },
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.lg,
                  AppSpacing.screenPadding,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  if (_draft.isNotEmpty) ...[
                    _Legenda(
                      'Escolhidos',
                      onClear: () => setState(_draft.clear),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
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
                    if (buscando)
                      for (final tema in disponiveis)
                        CheckboxListTile(
                          value: false,
                          onChanged: (_) => _toggle(tema),
                          title: Text(songThemeLabel(tema)),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          minTileHeight: AppSpacing.touchTarget,
                        )
                    else ...[
                      for (var i = 0; i < grupos.length; i++)
                        ..._letterSection(
                          group: grupos[i],
                          first: i == 0,
                        ),
                    ],
                  ],
                  ],
                ),
              ),
            ),
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

  List<Widget> _letterSection({
    required (String letter, List<String> themes) group,
    required bool first,
  }) {
    return [
      _ThemeSectionMarker(label: group.$1, first: first),
      for (final tema in group.$2)
        CheckboxListTile(
          value: false,
          onChanged: (_) => _toggle(tema),
          title: Text(songThemeLabel(tema)),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          minTileHeight: AppSpacing.touchTarget,
        ),
    ];
  }
}

class _ThemeSectionMarker extends StatelessWidget {
  const _ThemeSectionMarker({required this.label, required this.first});

  final String label;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        first ? AppSpacing.sm : AppSpacing.lg,
        0,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Divider(height: 1, color: scheme.outlineVariant),
          ),
        ],
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

/// A linha de filtro por tema, logo abaixo das abas.
///
/// **Uma tira que rola, e não um painel.** O que precisa estar visível o tempo
/// todo é *quais* temas estão filtrando — sem isso, uma lista curta parece
/// acervo pequeno em vez de filtro ligado. Cada tema marcado vira uma etiqueta
/// com "x", que é o caminho mais curto para desfazer: um toque, sem reabrir o
/// seletor.
///
/// O botão de abrir vem **primeiro** e não some quando há escolha: a mesma
/// posição sempre, esteja o filtro ligado ou não.
class SongThemeFilterBar extends StatelessWidget {
  const SongThemeFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  Future<void> _open(BuildContext context) async {
    final escolha = await showSongThemePicker(context, selected: selected);
    if (escolha != null) onChanged(escolha);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
      ),
      child: Row(
        children: [
          ActionChip(
            avatar: const Icon(Icons.sell_outlined, size: 18),
            label: Text(
              selected.isEmpty ? 'Temas' : 'Temas (${selected.length})',
            ),
            tooltip: 'Filtrar por tema',
            onPressed: () => _open(context),
          ),
          for (final tema in songThemeValues)
            if (selected.contains(tema))
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: InputChip(
                  label: Text(songThemeLabel(tema)),
                  selected: true,
                  showCheckmark: false,
                  onDeleted: () => onChanged({...selected}..remove(tema)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  deleteButtonTooltipMessage: 'Tirar ${songThemeLabel(tema)}',
                  onSelected: (_) => _open(context),
                ),
              ),
        ],
      ),
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
