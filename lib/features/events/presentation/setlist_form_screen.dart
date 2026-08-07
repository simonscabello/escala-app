import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_states.dart';
import '../../songs/data/song_repository.dart';
import '../../songs/domain/song_models.dart';
import '../data/event_repository.dart';
import '../domain/event_models.dart';

/// Monta o repertório da escala: escolhe do repertório da equipe, arrasta
/// para ordenar, e ajusta o tom quando esta escala pede diferente.
///
/// A ordem é o conteúdo, não enfeite: é a sequência que a equipe vai tocar, e
/// é assim que ela sai no texto do WhatsApp.
class SetlistFormScreen extends ConsumerStatefulWidget {
  const SetlistFormScreen({
    super.key,
    required this.teamId,
    required this.eventId,
    this.event,
  });

  final String teamId;
  final String eventId;
  final Event? event;

  @override
  ConsumerState<SetlistFormScreen> createState() => _SetlistFormScreenState();
}

class _SetlistFormScreenState extends ConsumerState<SetlistFormScreen> {
  final List<EventSong> _songs = [];
  bool _populated = false;
  bool _saving = false;
  String? _error;

  void _populate(Event event) {
    _populated = true;
    _songs.addAll(event.songs);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(eventRepositoryProvider)
          .replaceSongs(widget.eventId, _songs);

      ref.invalidate(eventProvider(widget.eventId));
      if (mounted) context.pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addSongs() async {
    final escolhidas = await showModalBottomSheet<List<Song>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SongPicker(
        teamId: widget.teamId,
        // Já escaladas não aparecem: a mesma música duas vezes na mesma
        // escala é erro, e o servidor recusaria.
        jaEscolhidas: _songs.map((s) => s.songId).toSet(),
      ),
    );

    if (escolhidas == null || escolhidas.isEmpty) return;

    setState(() {
      for (final song in escolhidas) {
        _songs.add(
          EventSong(
            songId: song.id,
            title: song.title,
            artist: song.artist,
            key: song.defaultKey,
            defaultKey: song.defaultKey,
            chordsUrl: song.chordsUrl,
            lyricsUrl: song.lyricsUrl,
          ),
        );
      }
    });
  }

  Future<void> _editItem(int index) async {
    final song = _songs[index];
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
                labelText: 'Tom nesta escala',
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
      _songs[index] = EventSong(
        songId: song.songId,
        title: song.title,
        artist: song.artist,
        key: novoTom.isEmpty ? song.defaultKey : novoTom,
        keyOverride: novoTom.isEmpty ? null : novoTom,
        defaultKey: song.defaultKey,
        note: novoRecado.isEmpty ? null : novoRecado,
        chordsUrl: song.chordsUrl,
        lyricsUrl: song.lyricsUrl,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _addSongs,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Músicas'),
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
              child: _songs.isEmpty
                  ? AppEmptyState(
                      icon: Icons.queue_music_rounded,
                      title: 'Sem músicas ainda',
                      message: 'Escolha do repertório da equipe. A ordem aqui '
                          'é a ordem que vocês vão tocar.',
                      actionLabel: 'Escolher músicas',
                      onAction: _addSongs,
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPadding,
                        AppSpacing.md,
                        AppSpacing.screenPadding,
                        AppSpacing.xxl * 2,
                      ),
                      itemCount: _songs.length,
                      // `onReorderItem` e não `onReorder`: ele já entrega o
                      // índice de destino corrigido para o item removido, e
                      // compensar à mão aqui erraria por um ao arrastar para
                      // baixo.
                      onReorderItem: (oldIndex, newIndex) => setState(() {
                        _songs.insert(newIndex, _songs.removeAt(oldIndex));
                      }),
                      itemBuilder: (context, index) => Padding(
                        key: ValueKey(_songs[index].songId),
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _SetlistTile(
                          song: _songs[index],
                          position: index + 1,
                          onEdit: () => _editItem(index),
                          onRemove: () =>
                              setState(() => _songs.removeAt(index)),
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

class _SetlistTile extends StatelessWidget {
  const _SetlistTile({
    required this.song,
    required this.position,
    required this.onEdit,
    required this.onRemove,
  });

  final EventSong song;
  final int position;
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
            tooltip: 'Tirar da escala',
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: onRemove,
          ),
          Icon(Icons.drag_handle_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// Escolha múltipla do repertório da equipe.
class _SongPicker extends ConsumerStatefulWidget {
  const _SongPicker({required this.teamId, required this.jaEscolhidas});

  final String teamId;
  final Set<String> jaEscolhidas;

  @override
  ConsumerState<_SongPicker> createState() => _SongPickerState();
}

class _SongPickerState extends ConsumerState<_SongPicker> {
  final _selecionadas = <Song>[];
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final songs = ref.watch(
      songsProvider(SongQuery(teamId: widget.teamId, search: _search)),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (_, controller) => Column(
        children: [
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
                  return const AppEmptyState(
                    icon: Icons.library_music_outlined,
                    title: 'Nada para adicionar',
                    message: 'Ou o repertório está vazio, ou todas as músicas '
                        'já estão nesta escala.',
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
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selecionadas.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selecionadas),
                child: Text(
                  _selecionadas.isEmpty
                      ? 'Escolha as músicas'
                      : 'Adicionar ${_selecionadas.length}',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
