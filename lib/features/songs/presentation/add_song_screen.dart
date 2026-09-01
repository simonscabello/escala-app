import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/app_submit_button.dart';
import '../../../shared/widgets/form_scaffold.dart';
import '../data/song_repository.dart';
import '../domain/song_models.dart';
import '../domain/song_themes.dart';
import 'song_theme_picker.dart';

/// Adicionar música: uma caixa de busca, duas fontes.
///
/// Primeiro o que outras equipes já cadastraram — é instantâneo, não gasta
/// chamada externa e **vem com letra**, que é o que nenhuma API entrega.
/// Depois o Spotify, para o que ninguém tem ainda.
///
/// A pessoa escolhe: título sozinho é ambíguo ("Aleluia" existe em cinco
/// versões) e casar automaticamente erraria calado.
class AddSongScreen extends ConsumerStatefulWidget {
  const AddSongScreen({super.key, required this.teamId, this.onCreated});

  final String teamId;

  /// O que fazer com a música recém-criada.
  ///
  /// Nulo no caminho normal (`Equipe → Repertório → Nova`): abre a música
  /// criada, que é o que se quer ao cadastrar por cadastrar. Preenchido quando
  /// esta tela é aberta de dentro da montagem de uma escala, onde ir para o
  /// detalhe da música abandonaria a escala pela metade -- ali a música volta
  /// para quem pediu e entra direto no culto.
  final ValueChanged<Song>? onCreated;

  @override
  ConsumerState<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends ConsumerState<AddSongScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<CatalogCandidate> _catalog = [];
  List<ExternalCandidate> _external = [];
  bool _searching = false;
  bool _adding = false;
  bool _searched = false;
  String? _error;

  /// Se a equipe vai **aprender** esta música.
  ///
  /// Nasce ligado: quem abre esta tela quase sempre está atrás de uma canção
  /// que a equipe ainda não canta — é essa a razão de procurar. Quem está
  /// cadastrando o acervo antigo desliga uma vez e a escolha vale para as
  /// próximas desta sessão, que é como o cadastro em lote acontece.
  bool _isNew = true;

  /// Os temas que vão junto com a música escolhida.
  ///
  /// Como o `_isNew`: valem para a próxima que for adicionada e continuam
  /// valendo para as seguintes desta sessão. Quem está cadastrando o repertório
  /// de Natal adiciona seis músicas seguidas com o mesmo tema, e remarcar a
  /// cada uma seria trabalho repetido sem razão.
  ///
  /// Numa música vinda do catálogo eles **se somam** aos que a outra equipe já
  /// tinha classificado; numa vinda do Spotify são os únicos que existem, já
  /// que nenhum serviço externo lê letra.
  Set<String> _themes = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _catalog = [];
        _external = [];
        _searched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String term) async {
    setState(() {
      _searching = true;
      _error = null;
    });

    final repository = ref.read(songRepositoryProvider);

    try {
      // As duas juntas: uma é local e a outra sai para o Spotify, e esperar
      // em fila dobraria o tempo à toa.
      final results = await Future.wait([
        repository.catalog(widget.teamId, term),
        repository.searchExternal(widget.teamId, term),
      ]);

      if (!mounted) return;
      setState(() {
        _catalog = results[0] as List<CatalogCandidate>;
        _external = results[1] as List<ExternalCandidate>;
        _searched = true;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add(Future<Song> Function() create) async {
    setState(() {
      _adding = true;
      _error = null;
    });

    try {
      final song = await create();
      if (!mounted) return;

      // A lista do repertório precisa enxergar a música nova: quem volta para
      // ela (ou para o seletor da escala) procuraria por algo que a resposta
      // em cache não tem. A família inteira, porque a lista de trás está com
      // os filtros que a pessoa deixou ligados.
      ref.invalidate(songsProvider);

      showAppSnackBar(
        context,
        '"${song.title}" entrou no repertório.',
        tone: AppTone.success,
      );

      final onCreated = widget.onCreated;
      if (onCreated != null) {
        onCreated(song);
        return;
      }
      context.pushReplacement('/equipe/musicas/${song.id}');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  /// Porta de saída quando a música não existe nem no catálogo nem no
  /// Spotify. O backend sempre aceitou cadastro manual, mas a interface só
  /// expunha as duas buscas — numa equipe nova, sem catálogo e sem credenciais
  /// do Spotify, era impossível cadastrar a primeira música.
  Future<void> _addManual() async {
    final draft = await showModalBottomSheet<_ManualSongDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ManualSongSheet(
        initialTitle: _controller.text.trim(),
      ),
    );
    if (draft == null || !mounted) return;

    final repository = ref.read(songRepositoryProvider);
    await _add(
      () => repository.create(
        widget.teamId,
        {
          'title': draft.title,
          if (draft.artist != null) 'artist': draft.artist,
          'isNew': _isNew,
          if (_themes.isNotEmpty) 'themes': _themes.toList(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.read(songRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar música')),
      body: SafeArea(
        top: false,
        child: AppContentWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: TextField(
                  controller: _controller,
                  onChanged: _onChanged,
                  autofocus: true,
                  enabled: !_adding,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Nome da música e artista',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: FormErrorBanner(message: _error!),
                ),
              // Só quando há o que escolher: antes da busca não existe música a
              // que a marca possa se aplicar, e um controle solto na tela vazia
              // seria uma pergunta sem assunto. Aqui ela fica logo acima dos
              // cartões, no caminho do olho de quem vai tocar em um deles.
              if (!_adding && (_catalog.isNotEmpty || _external.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.screenPadding,
                    right: AppSpacing.screenPadding,
                    bottom: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                        value: _isNew,
                        onChanged: (v) => setState(() => _isNew = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        title: const Text('Música nova'),
                      ),
                      _ThemePicker(
                        themes: _themes,
                        onChanged: (themes) => setState(() => _themes = themes),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _adding
                    ? const AppLoading(
                        message: 'Procurando a cifra, a letra e o tom.\n'
                            'Pode levar alguns segundos.',
                      )
                    : _Results(
                        catalog: _catalog,
                        external: _external,
                        searched: _searched,
                        onManual: _addManual,
                        onPickCatalog: (c) => _add(
                          () => repository.copyFromCatalog(
                            widget.teamId,
                            c.sourceSongId,
                            isNew: _isNew,
                            themes: _themes,
                          ),
                        ),
                        onPickExternal: (c) => _add(
                          () => repository.createFromExternal(
                            widget.teamId,
                            c,
                            isNew: _isNew,
                            themes: _themes,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.catalog,
    required this.external,
    required this.searched,
    required this.onManual,
    required this.onPickCatalog,
    required this.onPickExternal,
  });

  final List<CatalogCandidate> catalog;
  final List<ExternalCandidate> external;
  final bool searched;
  final VoidCallback onManual;
  final ValueChanged<CatalogCandidate> onPickCatalog;
  final ValueChanged<ExternalCandidate> onPickExternal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!searched) {
      return const AppEmptyState(
        icon: Icons.search_rounded,
        title: 'Procure a música',
        message: 'Digite o nome e, se souber, o artista. Buscamos no que '
            'outras equipes já cadastraram e no Spotify.',
      );
    }

    if (catalog.isEmpty && external.isEmpty) {
      return AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nada encontrado',
        message: 'Tente escrever o artista junto ou cadastre esta versão '
            'manualmente.',
        actionLabel: 'Cadastrar manualmente',
        onAction: onManual,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        0,
        AppSpacing.screenPadding,
        AppSpacing.xxl,
      ),
      children: [
        if (catalog.isNotEmpty) ...[
          const _SectionTitle(
            title: 'Já cadastrada por outra equipe',
            subtitle: 'Vem completa, inclusive a letra',
          ),
          for (final item in catalog)
            _CatalogTile(item: item, onTap: () => onPickCatalog(item)),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (external.isNotEmpty) ...[
          const _SectionTitle(
            title: 'Spotify',
            subtitle: 'Buscamos a cifra e o tom ao adicionar',
          ),
          for (final item in external)
            _ExternalTile(item: item, onTap: () => onPickExternal(item)),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          'A letra não vem do Spotify. Se ninguém tiver essa música ainda, '
          'você pode colar a letra depois, na edição.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: onManual,
          icon: const Icon(Icons.edit_note_rounded, size: 18),
          label: const Text('Cadastrar outra versão manualmente'),
        ),
      ],
    );
  }
}

class _ManualSongDraft {
  const _ManualSongDraft({required this.title, this.artist});

  final String title;
  final String? artist;
}

/// Cadastro mínimo. O restante continua na edição em duas camadas: aqui só se
/// pede o que identifica a música, para não transformar a saída de emergência
/// da busca num formulário de doze campos.
class _ManualSongSheet extends StatefulWidget {
  const _ManualSongSheet({required this.initialTitle});

  final String initialTitle;

  @override
  State<_ManualSongSheet> createState() => _ManualSongSheetState();
}

class _ManualSongSheetState extends State<_ManualSongSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title =
      TextEditingController(text: widget.initialTitle);
  final _artist = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final artist = _artist.text.trim();
    Navigator.of(context).pop(
      _ManualSongDraft(
        title: _title.text.trim(),
        artist: artist.isEmpty ? null : artist,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cadastrar manualmente',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Informe só o que identifica a música. Tom, letra e links '
                'podem ser completados depois.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nome da música'),
                validator: (value) => value == null || value.trim().length < 2
                    ? 'Informe o nome da música.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _artist,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Artista (opcional)',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSubmitButton(
                label: 'Cadastrar',
                loading: false,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({required this.item, required this.onTap});

  final CatalogCandidate item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final traz = [
      if (item.hasLyrics) 'letra',
      if (item.hasChords) 'cifra',
      if (item.originalKey != null) 'tom ${item.originalKey}',
      if (item.hasYoutube) 'YouTube',
      if (item.hasSpotify) 'Spotify',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.library_add_check_outlined, color: scheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: theme.textTheme.titleSmall),
                  Text(
                    item.artist ?? 'Sem artista',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (traz.isNotEmpty)
                    Text(
                      'Traz ${traz.join(', ')}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.add_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ExternalTile extends StatelessWidget {
  const _ExternalTile({required this.item, required this.onTap});

  final ExternalCandidate item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.headphones_rounded, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    [item.artist, if (item.year != null) item.year!]
                        .where((e) => e.isNotEmpty)
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Os temas a aplicar na música que for escolhida abaixo.
///
/// Uma tira de etiquetas e não o seletor inteiro: esta tela é uma busca, e
/// oitenta e dois chips entre o campo e os resultados afastariam do olho
/// justamente o que se veio fazer aqui. Fechado, ocupa uma linha; aberto, o
/// seletor é o mesmo da edição e do filtro.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.themes, required this.onChanged});

  final Set<String> themes;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final tema in themes)
          InputChip(
            label: Text(songThemeLabel(tema)),
            selected: true,
            showCheckmark: false,
            onDeleted: () => onChanged({...themes}..remove(tema)),
            deleteIcon: const Icon(Icons.close_rounded, size: 16),
            deleteButtonTooltipMessage: 'Tirar ${songThemeLabel(tema)}',
          ),
        ActionChip(
          avatar: const Icon(Icons.sell_outlined, size: 18),
          label: Text(themes.isEmpty ? 'Temas' : 'Mais temas'),
          onPressed: () async {
            final escolha = await showSongThemePicker(
              context,
              selected: themes,
            );
            if (escolha != null) onChanged(escolha);
          },
        ),
      ],
    );
  }
}
