import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/form_scaffold.dart';
import '../data/song_repository.dart';
import '../domain/song_models.dart';

/// Edição de uma música. É aqui que a equipe responde o que nenhuma API
/// responde: em que tom ELA canta, se é hino ou cântico, se é calma ou
/// agitada.
///
/// Os campos vindos de fora (artista, links, tom da gravação) não aparecem
/// para edição: quem os corrige é o enriquecimento, e deixá-los aqui daria a
/// impressão de que precisam de atenção.
class SongFormScreen extends ConsumerStatefulWidget {
  const SongFormScreen({
    super.key,
    required this.teamId,
    required this.songId,
    this.song,
  });

  final String teamId;
  final String songId;

  /// Vem por `extra` quando a navegação parte do detalhe -- evita uma segunda
  /// ida ao servidor para preencher o formulário.
  final Song? song;

  @override
  ConsumerState<SongFormScreen> createState() => _SongFormScreenState();
}

class _SongFormScreenState extends ConsumerState<SongFormScreen> {
  final _title = TextEditingController();
  final _key = TextEditingController();

  String? _kind;
  String? _pace;
  bool _populated = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _key.dispose();
    super.dispose();
  }

  void _populate(Song song) {
    _populated = true;
    _title.text = song.title;
    _key.text = song.defaultKey ?? '';
    _kind = song.kind;
    _pace = song.pace;
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.length < 2) {
      setState(() => _error = 'Informe o nome da música.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(songRepositoryProvider).update(
        widget.teamId,
        widget.songId,
        {
          'title': title,
          // String vazia vira null no backend: o campo volta a "não decidido".
          'defaultKey': _key.text.trim(),
          'kind': _kind,
          'pace': _pace,
        },
      );

      ref.invalidate(
        songProvider((teamId: widget.teamId, songId: widget.songId)),
      );
      if (mounted) context.pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song ??
        ref
            .watch(
              songProvider((teamId: widget.teamId, songId: widget.songId)),
            )
            .valueOrNull;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar música')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_populated) _populate(song);

    return FormScaffold(
      appBar: AppBar(title: const Text('Editar música')),
      title: song.title,
      subtitle: 'Tom, tipo e andamento são decisão da equipe — nenhum '
          'serviço de música responde por vocês.',
      children: [
        TextField(
          controller: _title,
          enabled: !_saving,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome da música'),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _key,
          enabled: !_saving,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Nosso tom',
            helperText: song.originalKey != null
                ? 'A gravação está em ${song.originalKey}'
                : 'Ex.: G, Bm, Eb — cabe também "G (capo 2)"',
          ),
        ),
        if (song.originalKey != null && _key.text.trim().isEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: const Icon(Icons.content_copy_rounded, size: 16),
              label: Text('Usar ${song.originalKey}'),
              onPressed: _saving
                  ? null
                  : () => setState(() => _key.text = song.originalKey!),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        _ChipField(
          label: 'Tipo',
          value: _kind,
          options: const {'HYMN': 'Hino', 'SONG': 'Cântico'},
          onChanged: _saving ? null : (v) => setState(() => _kind = v),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ChipField(
          label: 'Andamento',
          value: _pace,
          options: const {
            'CALM': 'Calma',
            'MODERATE': 'Moderada',
            'UPBEAT': 'Agitada',
          },
          hint: song.bpm != null ? 'A gravação tem ${song.bpm} bpm' : null,
          onChanged: _saving ? null : (v) => setState(() => _pace = v),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (_error != null) FormErrorBanner(message: _error!),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Escolha única em chips, com opção de desmarcar. Tocar no que já está
/// selecionado limpa: é como se volta atrás sem um botão "nenhum".
class _ChipField extends StatelessWidget {
  const _ChipField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final String? value;
  final Map<String, String> options;
  final String? hint;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        if (hint != null)
          Text(
            hint!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final entry in options.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: value == entry.key,
                onSelected: onChanged == null
                    ? null
                    : (selected) =>
                        onChanged!(selected ? entry.key : null),
              ),
          ],
        ),
      ],
    );
  }
}
