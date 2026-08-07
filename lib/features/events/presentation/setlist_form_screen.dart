import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_states.dart';
import '../../songs/data/song_repository.dart';
import '../../songs/domain/song_models.dart';
import '../../songs/presentation/add_song_screen.dart';
import '../data/event_repository.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';

/// Monta o repertório da escala, **um repertório por culto**: escolhe do
/// repertório da equipe, arrasta para ordenar, e ajusta o tom quando aquele
/// culto pede diferente.
///
/// A ordem é o conteúdo, não enfeite: é a sequência que a equipe vai tocar, e é
/// assim que ela sai no texto do WhatsApp.
///
/// A mesma música pode entrar de manhã e à noite — são duas linhas, e à noite
/// pode ser outro tom e outro recado. Arrastar só reordena dentro do próprio
/// culto: mover entre cultos é tirar de um e pôr no outro, que é o que a
/// pessoa faz de qualquer forma quando muda de ideia.
class SetlistFormScreen extends ConsumerStatefulWidget {
  const SetlistFormScreen({
    super.key,
    required this.teamId,
    required this.eventId,
    this.event,
    this.isNewSchedule = false,
  });

  final String teamId;
  final String eventId;
  final Event? event;

  /// Último passo de uma escala recém-criada (criar → escalar → músicas).
  ///
  /// Salvar termina no detalhe da escala, e não voltando: os dois passos
  /// anteriores já saíram da pilha, e voltar cairia na agenda sem nunca mostrar
  /// a escala que a pessoa acabou de montar.
  final bool isNewSchedule;

  @override
  ConsumerState<SetlistFormScreen> createState() => _SetlistFormScreenState();
}

class _SetlistFormScreenState extends ConsumerState<SetlistFormScreen> {
  /// serviceId -> músicas daquele culto, na ordem.
  final Map<String, List<EventSong>> _porCulto = {};
  List<EventService> _cultos = const [];

  bool _populated = false;
  bool _saving = false;
  String? _error;

  void _populate(Event event) {
    _populated = true;
    _cultos = event.displayServices;
    for (final grupo in event.songsByService) {
      _porCulto[grupo.service.id] = [...grupo.songs];
    }
  }

  List<EventSong> _lista(String serviceId) =>
      _porCulto.putIfAbsent(serviceId, () => []);

  int get _total =>
      _porCulto.values.fold(0, (soma, musicas) => soma + musicas.length);

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Na ordem dos cultos: o servidor normaliza a posição dentro de cada um,
      // então o que precisa chegar certo é a sequência de cada lista.
      final todas = [
        for (final culto in _cultos) ..._lista(culto.id),
      ];
      await ref.read(eventRepositoryProvider).replaceSongs(
            widget.eventId,
            todas,
          );

      ref.invalidate(eventProvider(widget.eventId));
      if (!mounted) return;

      if (widget.isNewSchedule) {
        context.pushReplacement('/agenda/${widget.eventId}');
        return;
      }
      context.pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addSongs(EventService culto) async {
    final escolha = await showModalBottomSheet<_PickerResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SongPicker(
        teamId: widget.teamId,
        culto: culto,
        // Já escaladas **neste culto** não aparecem: repetir a mesma música no
        // mesmo culto é erro e o servidor recusaria. No outro culto ela
        // continua disponível, que é o caso comum de manhã e noite.
        jaEscolhidas: _lista(culto.id).map((s) => s.songId).toSet(),
        mostrarTodosOsCultos: _cultos.length > 1,
      ),
    );

    if (escolha == null || !mounted) return;

    if (escolha.cadastrarNova) {
      final nova = await _cadastrarMusica();
      if (nova != null && mounted) {
        setState(() => _lista(culto.id).add(_novoItem(culto, nova)));
      }
      // Volta ao seletor: quem abriu para escolher músicas raramente queria
      // cadastrar só uma e ir embora.
      if (mounted) await _addSongs(culto);
      return;
    }

    setState(() {
      for (final song in escolha.songs) {
        _lista(culto.id).add(_novoItem(culto, song));
      }
    });
  }

  /// Cadastro completo (catálogo de outras equipes + Spotify) sem sair da
  /// escala em montagem.
  ///
  /// `Navigator.push` sobre esta tela, e não `context.push` do go_router: a
  /// escala continua viva embaixo, com o que já foi escolhido, e volta intacta
  /// quando a música é criada ou o cadastro é abandonado.
  Future<Song?> _cadastrarMusica() {
    return Navigator.of(context).push<Song>(
      MaterialPageRoute(
        builder: (rota) => AddSongScreen(
          teamId: widget.teamId,
          onCreated: (song) => Navigator.of(rota).pop(song),
        ),
      ),
    );
  }

  EventSong _novoItem(EventService culto, Song song) => EventSong(
        songId: song.id,
        serviceId: culto.id,
        title: song.title,
        artist: song.artist,
        key: song.defaultKey,
        defaultKey: song.defaultKey,
        chordsUrl: song.chordsUrl,
        lyricsUrl: song.lyricsUrl,
        youtubeUrl: song.youtubeUrl,
        spotifyUrl: song.spotifyUrl,
      );

  Future<void> _editItem(String serviceId, int index) async {
    final song = _lista(serviceId)[index];
    final keyController = TextEditingController(text: song.keyOverride ?? '');
    final noteController = TextEditingController(text: song.note ?? '');

    final salvou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(song.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Tom neste culto',
                helperText: song.defaultKey != null
                    ? 'A equipe canta em ${song.defaultKey}'
                    : 'Deixe vazio para usar o tom da equipe',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Recado',
                hintText: 'Ex.: entra só o teclado',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );

    final novoTom = keyController.text.trim();
    final novoRecado = noteController.text.trim();
    keyController.dispose();
    noteController.dispose();

    if (salvou != true) return;

    setState(() {
      _lista(serviceId)[index] = EventSong(
        songId: song.songId,
        serviceId: song.serviceId,
        title: song.title,
        artist: song.artist,
        key: novoTom.isEmpty ? song.defaultKey : novoTom,
        keyOverride: novoTom.isEmpty ? null : novoTom,
        defaultKey: song.defaultKey,
        note: novoRecado.isEmpty ? null : novoRecado,
        chordsUrl: song.chordsUrl,
        lyricsUrl: song.lyricsUrl,
        youtubeUrl: song.youtubeUrl,
        spotifyUrl: song.spotifyUrl,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // O provider devolve o invólucro de cache; aqui só interessa a escala.
    final event = widget.event ??
        ref.watch(eventProvider(widget.eventId)).valueOrNull?.data;

    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Repertório')),
        body: const AppLoading(),
      );
    }

    if (!_populated) _populate(event);

    final timezone =
        event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repertório da escala'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  AppSpacing.xxl,
                ),
                children: [
                  if (_total == 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: Text(
                        _cultos.length > 1
                            ? 'Cada culto tem o próprio repertório. A ordem aqui '
                                'é a ordem que vocês vão tocar.'
                            : 'Escolha do repertório da equipe. A ordem aqui é a '
                                'ordem que vocês vão tocar.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  for (final culto in _cultos)
                    _ServiceSetlist(
                      culto: culto,
                      timezone: timezone,
                      songs: _lista(culto.id),
                      saving: _saving,
                      onAdd: () => _addSongs(culto),
                      onEdit: (index) => _editItem(culto.id, index),
                      onRemove: (index) =>
                          setState(() => _lista(culto.id).removeAt(index)),
                      onReorder: (oldIndex, newIndex) => setState(() {
                        final lista = _lista(culto.id);
                        lista.insert(newIndex, lista.removeAt(oldIndex));
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O repertório de um culto: cabeçalho, lista arrastável e o botão de
/// acrescentar.
///
/// O cabeçalho aparece mesmo quando a escala tem um culto só. Some a dúvida de
/// "para qual culto estou escolhendo" antes de ela existir, e o botão de
/// acrescentar já nasce dizendo a que culto pertence.
class _ServiceSetlist extends StatelessWidget {
  const _ServiceSetlist({
    required this.culto,
    required this.timezone,
    required this.songs,
    required this.saving,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
    required this.onReorder,
  });

  final EventService culto;
  final String timezone;
  final List<EventSong> songs;
  final bool saving;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.church_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${culto.label} ${formatEventTime(culto.startsAt, timezone)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
              if (songs.isNotEmpty)
                Text(
                  songs.length == 1 ? '1 música' : '${songs.length} músicas',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (songs.isEmpty)
            AppCard(
              color: scheme.surfaceContainerLow,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Nenhuma música neste culto ainda.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              // A rolagem é da tela: cada culto é um pedaço dela, e não um
              // painel que rola por dentro.
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: songs.length,
              // `onReorderItem` e não `onReorder`: ele já entrega o índice de
              // destino corrigido para o item removido, e compensar à mão aqui
              // erraria por um ao arrastar para baixo.
              onReorderItem: onReorder,
              itemBuilder: (context, index) => Padding(
                // A chave precisa distinguir a linha, e não só a música: a
                // mesma canção pode estar nos dois cultos.
                key: ValueKey('${culto.id}:${songs[index].songId}'),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _SetlistTile(
                  song: songs[index],
                  position: index + 1,
                  index: index,
                  onEdit: () => onEdit(index),
                  onRemove: () => onRemove(index),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: saving ? null : onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                songs.isEmpty
                    ? 'Escolher músicas'
                    : 'Acrescentar em ${culto.label}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetlistTile extends StatelessWidget {
  const _SetlistTile({
    required this.song,
    required this.position,
    required this.index,
    required this.onEdit,
    required this.onRemove,
  });

  final EventSong song;
  final int position;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      onTap: onEdit,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Text(
            '$position',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  [
                    if (song.artist != null && song.artist!.isNotEmpty)
                      song.artist!,
                    if (song.key != null && song.key!.isNotEmpty)
                      'Tom ${song.key}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: song.hasCustomKey
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
                if (song.note != null && song.note!.isNotEmpty)
                  Text(
                    song.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tirar do culto',
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: onRemove,
          ),
          // A alça é explícita porque `buildDefaultDragHandles` está desligado:
          // com a lista dentro da rolagem da tela, a alça automática disputava
          // o gesto de rolar.
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle_rounded, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// O que o seletor devolve: as músicas marcadas, ou o pedido de cadastrar uma
/// que ainda não existe no repertório.
class _PickerResult {
  const _PickerResult.songs(this.songs) : cadastrarNova = false;
  const _PickerResult.cadastrar()
      : songs = const [],
        cadastrarNova = true;

  final List<Song> songs;
  final bool cadastrarNova;
}

/// Escolha múltipla do repertório da equipe, para um culto.
class _SongPicker extends ConsumerStatefulWidget {
  const _SongPicker({
    required this.teamId,
    required this.culto,
    required this.jaEscolhidas,
    required this.mostrarTodosOsCultos,
  });

  final String teamId;
  final EventService culto;
  final Set<String> jaEscolhidas;

  /// Com mais de um culto, o seletor diz para qual deles está escolhendo.
  final bool mostrarTodosOsCultos;

  @override
  ConsumerState<_SongPicker> createState() => _SongPickerState();
}

class _SongPickerState extends ConsumerState<_SongPicker> {
  final _selecionadas = <Song>[];
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songs = ref.watch(
      songsProvider(SongQuery(teamId: widget.teamId, search: _search)),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (_, controller) => Column(
        children: [
          if (widget.mostrarTodosOsCultos)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'Escolhendo para ${widget.culto.label}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Buscar no repertório',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: songs.when(
              loading: () => const AppLoading(),
              error: (error, _) => AppErrorState(
                message: error is ApiException
                    ? error.message
                    : 'Não foi possível carregar o repertório.',
              ),
              data: (list) {
                final disponiveis = list
                    .where((s) => !widget.jaEscolhidas.contains(s.id))
                    .toList();

                if (disponiveis.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.library_music_outlined,
                    title: _search.trim().isEmpty
                        ? 'Nada para adicionar'
                        : 'Nenhuma música com esse nome',
                    message: _search.trim().isEmpty
                        ? 'Ou o repertório está vazio, ou todas as músicas já '
                            'estão neste culto.'
                        : 'Ela pode ainda não estar no repertório da equipe. '
                            'Dá para cadastrar agora, sem perder o que você já '
                            'montou aqui.',
                    actionLabel: 'Cadastrar música',
                    onAction: () => Navigator.pop(
                      context,
                      const _PickerResult.cadastrar(),
                    ),
                  );
                }

                return ListView.builder(
                  controller: controller,
                  itemCount: disponiveis.length,
                  itemBuilder: (_, index) {
                    final song = disponiveis[index];
                    final marcada = _selecionadas.contains(song);

                    return CheckboxListTile(
                      value: marcada,
                      title: Text(song.title),
                      subtitle: Text(
                        [
                          song.subtitle,
                          if (song.defaultKey != null) 'Tom ${song.defaultKey}',
                        ].join(' · '),
                      ),
                      onChanged: (_) => setState(() {
                        marcada
                            ? _selecionadas.remove(song)
                            : _selecionadas.add(song);
                      }),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Row(
              children: [
                // Sem `Expanded`: o botão fica com a largura do próprio texto.
                // Dividir a linha em frações espremia "Cadastrar" em um terço
                // da tela e quebrava a palavra no meio ("Cadast / rar").
                //
                // Sempre visível, e não só na lista vazia: quem já sabe que a
                // música não está cadastrada não deveria ter de procurar por
                // ela primeiro para descobrir o caminho.
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    const _PickerResult.cadastrar(),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Cadastrar', softWrap: false),
                ),
                const SizedBox(width: AppSpacing.sm),
                // O que sobra vai para a ação principal.
                Expanded(
                  child: FilledButton(
                    onPressed: _selecionadas.isEmpty
                        ? null
                        : () => Navigator.pop(
                              context,
                              _PickerResult.songs(_selecionadas),
                            ),
                    child: Text(
                      _selecionadas.isEmpty
                          ? 'Escolha as músicas'
                          : 'Adicionar ${_selecionadas.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
