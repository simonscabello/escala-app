import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/app_submit_button.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../songs/data/song_repository.dart';
import '../../songs/domain/song_models.dart';
import '../data/suggestion_repository.dart';

/// Abre a folha de sugerir e devolve `true` se alguma coisa foi enviada.
Future<bool> showSuggestSongSheet(
  BuildContext context, {
  required String teamId,
  Song? song,
  DateTime? targetDate,
}) async {
  final enviada = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SuggestSongSheet(
      teamId: teamId,
      song: song,
      targetDate: targetDate,
    ),
  );
  return enviada ?? false;
}

/// Sugerir uma música para a equipe.
///
/// Três decisões numa tela só: **qual música**, **quando** (opcional) e **por
/// quê** (obrigatório). A ordem importa — a pergunta do porquê muda conforme a
/// data, então ela vem por último.
class SuggestSongSheet extends ConsumerStatefulWidget {
  const SuggestSongSheet({
    super.key,
    required this.teamId,
    this.song,
    this.targetDate,
  });

  final String teamId;

  /// Já escolhida quando a folha abre de dentro do repertório: a pessoa tocou
  /// numa música e o passo de procurar não existe.
  final Song? song;

  /// Já preenchida quando a folha abre de uma data conhecida.
  final DateTime? targetDate;

  @override
  ConsumerState<SuggestSongSheet> createState() => _SuggestSongSheetState();
}

class _SuggestSongSheetState extends ConsumerState<SuggestSongSheet> {
  final _searchController = TextEditingController();
  final _reasonController = TextEditingController();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  Timer? _debounce;

  /// A escolha feita. Um dos três: música do repertório, resultado do Spotify,
  /// ou texto digitado à mão.
  Song? _song;
  ExternalCandidate? _external;
  bool _manual = false;

  List<Song> _results = [];
  List<ExternalCandidate> _externalResults = [];
  bool _searching = false;
  bool _searched = false;

  DateTime? _date;
  bool _sending = false;
  String? _error;

  /// Mínimo espelhado do servidor: obrigatório sem mínimo vira ".". Validar
  /// aqui poupa a ida de rede só para receber o mesmo "não".
  static const _minReason = 10;

  @override
  void initState() {
    super.initState();
    _song = widget.song;
    _date = widget.targetDate;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _reasonController.dispose();
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  bool get _escolhida => _song != null || _external != null || _manual;

  String get _titulo =>
      _song?.title ?? _external?.title ?? _titleController.text.trim();

  String? get _artista =>
      _song?.artist ?? _external?.artist ?? _artistController.text.trim();

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _externalResults = [];
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
      // As duas juntas: uma é local e a outra sai para o Spotify. A busca
      // externa é liberada para a equipe inteira -- é o que faz a maioria das
      // sugestões chegar já com artista, em vez de só um título digitado.
      final results = await Future.wait([
        repository.list(widget.teamId, search: term),
        repository.searchExternal(widget.teamId, term),
      ]);
      if (!mounted) return;
      setState(() {
        _results = results[0] as List<Song>;
        _externalResults = results[1] as List<ExternalCandidate>;
        _searched = true;
      });
    } on ApiException catch (error) {
      // Falhar a busca externa não pode esconder o repertório: a lista local
      // vem da mesma chamada, então avisamos e seguimos com o que houver.
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pickDate() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _date ?? _proximoDomingo(hoje),
      // Sem passado: o servidor recusa, e oferecer o que vai ser recusado é
      // caminho para erro.
      firstDate: DateTime(hoje.year, hoje.month, hoje.day),
      lastDate: DateTime(hoje.year + 1, hoje.month, hoje.day),
      helpText: 'Para qual domingo?',
    );
    if (escolhida != null && mounted) setState(() => _date = escolhida);
  }

  Future<void> _send() async {
    final reason = _reasonController.text.trim();
    if (_titulo.isEmpty) {
      setState(() => _error = 'Diga qual é a música.');
      return;
    }
    if (reason.length < _minReason) {
      setState(() {
        _error = 'Escreva um pouco mais sobre por que essa música valeria.';
      });
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await ref.read(suggestionRepositoryProvider).create(
            widget.teamId,
            title: _titulo,
            reason: reason,
            songId: _song?.id,
            artist: _artista,
            link: _external?.spotifyUrl,
            targetDate: _date,
          );

      // A lista e o selo da aba Equipe precisam enxergar a nova. A família
      // inteira: a lista de trás pode estar em qualquer um dos dois escopos.
      ref.invalidate(suggestionsProvider);
      ref.invalidate(openSuggestionCountProvider);
      ref.invalidate(eventSuggestionsProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);
      showAppSnackBar(
        context,
        'Sugestão enviada. O líder vai ver na hora de montar a escala.',
        tone: AppTone.success,
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          0,
          AppSpacing.screenPadding,
          AppSpacing.xxl,
        ),
        children: [
          Text('Sugerir uma música', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'A equipe inteira pode sugerir. Quem monta a escala vê a sua '
            'sugestão junto com o motivo.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (!_escolhida) ..._buscaDeMusica(theme) else _escolhaFeita(theme),

          if (_escolhida) ...[
            const SizedBox(height: AppSpacing.lg),
            _blocoData(theme),
            const SizedBox(height: AppSpacing.lg),
            _blocoJustificativa(theme),
          ],

          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],

          if (_escolhida) ...[
            const SizedBox(height: AppSpacing.xl),
            AppSubmitButton(
              label: 'Enviar sugestão',
              icon: Icons.send_rounded,
              loading: _sending,
              onPressed: _sending ? null : _send,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buscaDeMusica(ThemeData theme) {
    return [
      TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Qual música?',
          helperText: 'Buscamos no repertório da equipe e no Spotify',
          // Sem isto o texto de ajuda ganha uma linha só e termina em "e no…",
          // que é pior do que não ter ajuda nenhuma.
          helperMaxLines: 2,
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      if (_searching)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: AppLoading(),
        ),
      if (_results.isNotEmpty) ...[
        _rotulo(theme, 'No repertório da equipe'),
        ..._results.take(6).map(
              (song) => AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                onTap: () => setState(() => _song = song),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(song.title),
                  subtitle: Text(song.subtitle),
                  trailing: const Icon(Icons.add_rounded),
                ),
              ),
            ),
        const SizedBox(height: AppSpacing.md),
      ],
      if (_externalResults.isNotEmpty) ...[
        _rotulo(theme, 'No Spotify'),
        ..._externalResults.take(6).map(
              (candidate) => AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                onTap: () => setState(() => _external = candidate),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(candidate.title),
                  subtitle: Text(candidate.artist),
                  trailing: const Icon(Icons.add_rounded),
                ),
              ),
            ),
        const SizedBox(height: AppSpacing.md),
      ],
      // A porta de saída existe desde o começo, e não só depois de a busca
      // falhar: uma música do ensaio de ontem pode não estar em lugar nenhum,
      // e obrigar a procurar antes de poder digitar é fazer perder tempo.
      TextButton.icon(
        onPressed: () => setState(() {
          _manual = true;
          _titleController.text = _searchController.text.trim();
        }),
        icon: const Icon(Icons.edit_outlined),
        label: Text(
          _searched && _results.isEmpty && _externalResults.isEmpty
              ? 'Não achamos. Digitar o nome à mão'
              : 'Não está aqui? Digitar o nome à mão',
        ),
      ),
    ];
  }

  Widget _escolhaFeita(ThemeData theme) {
    if (_manual && _song == null && _external == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Nome da música'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _artistController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Artista (opcional)',
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _manual = false),
              child: const Text('Voltar para a busca'),
            ),
          ),
        ],
      );
    }

    final song = _song;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      surface: CardSurface.sunken,
      child: Row(
        children: [
          const Icon(Icons.music_note_rounded),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_titulo, style: theme.textTheme.titleSmall),
                if ((_artista ?? '').isNotEmpty)
                  Text(
                    _artista!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (song != null)
                  Text(
                    'Já está no repertório',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          // Só quando a escolha foi feita aqui dentro: aberta a partir de uma
          // música, trocar de música não é o que a pessoa quer.
          if (widget.song == null)
            TextButton(
              onPressed: () => setState(() {
                _song = null;
                _external = null;
                _manual = false;
              }),
              child: const Text('Trocar'),
            ),
        ],
      ),
    );
  }

  Widget _blocoData(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _date != null,
          // Desligado é o padrão: a maior parte das sugestões é "vamos
          // aprender essa", sem domingo marcado.
          onChanged: (ligado) {
            if (!ligado) {
              setState(() => _date = null);
              return;
            }
            _pickDate();
          },
          title: const Text('É para um domingo específico?'),
          subtitle: Text(
            _date == null
                ? 'Sem data, a sugestão é para o repertório'
                : _dataLonga(_date!),
          ),
        ),
        if (_date != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_rounded),
              label: const Text('Trocar a data'),
            ),
          ),
      ],
    );
  }

  Widget _blocoJustificativa(ThemeData theme) {
    // A pergunta muda com a data, e isso não é enfeite: se a música JÁ é do
    // repertório e alguém a pede para o domingo 14, "por que entrar no
    // repertório" não faz sentido -- ela já entrou.
    final label = _date == null
        ? 'Por que vale a pena a equipe aprender essa música?'
        : 'Por que essa música nesse domingo?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _reasonController,
          maxLines: 4,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'A igreja já canta essa nos cultos de oração...',
            // Obrigatório, e a tela diz por quê: é o que o líder lê para
            // decidir, e é o que faz uma recusa ser resposta a um argumento.
            helperText: 'Obrigatório — é o que o líder lê para decidir',
            helperMaxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _rotulo(ThemeData theme, String texto) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          texto,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
}

DateTime _proximoDomingo(DateTime from) {
  final faltam = (DateTime.sunday - from.weekday) % 7;
  return DateTime(from.year, from.month, from.day + (faltam == 0 ? 7 : faltam));
}

const _meses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

const _diasDaSemana = [
  'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo',
];

String _dataLonga(DateTime date) {
  final dia = _diasDaSemana[date.weekday - 1];
  return '$dia, ${date.day} de ${_meses[date.month - 1]}';
}
