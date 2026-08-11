import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/app_submit_button.dart';
import '../../../shared/widgets/form_scaffold.dart';
import '../data/song_repository.dart';
import '../domain/song_models.dart';

/// Edição de uma música, em duas camadas.
///
/// Em cima, **o que a equipe decide** e nenhuma API responde: em que tom ELA
/// canta, se é hino ou cântico, se é calma ou agitada. É o trabalho de toda
/// semana e abre expandido.
///
/// Embaixo, recolhido, **o que veio de fora**: artista, compositor, os quatro
/// links, o tom da gravação e a letra. Vêm do import e do enriquecimento, que
/// acertam a maioria — deixá-los à vista faria a tela parecer um formulário de
/// doze campos por preencher, quando o normal é não tocar em nenhum. Mas quando
/// o enriquecimento erra ou não acha, este é o único caminho para corrigir sem
/// mexer no banco.
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
  final _artist = TextEditingController();
  final _composer = TextEditingController();
  final _originalKey = TextEditingController();
  final _lyrics = TextEditingController();
  final _lyricsUrl = TextEditingController();
  final _chordsUrl = TextEditingController();
  final _youtubeUrl = TextEditingController();
  final _spotifyUrl = TextEditingController();
  final _hymnNumber = TextEditingController();

  String? _kind;
  String? _pace;
  bool _isNew = false;
  bool _populated = false;
  bool _saving = false;
  String? _error;

  /// Só abre quando alguém pede. Ver o grupo fechado é a informação de que
  /// aquilo já está resolvido.
  bool _showExternal = false;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _key,
      _artist,
      _composer,
      _originalKey,
      _lyrics,
      _lyricsUrl,
      _chordsUrl,
      _youtubeUrl,
      _spotifyUrl,
      _hymnNumber,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _populate(Song song) {
    _populated = true;
    _title.text = song.title;
    _key.text = song.defaultKey ?? '';
    _kind = song.kind;
    _pace = song.pace;
    _isNew = song.isNew;
    _artist.text = song.artist ?? '';
    _composer.text = song.composer ?? '';
    _originalKey.text = song.originalKey ?? '';
    _lyrics.text = song.lyrics ?? '';
    _lyricsUrl.text = song.lyricsUrl ?? '';
    _chordsUrl.text = song.chordsUrl ?? '';
    _youtubeUrl.text = song.youtubeUrl ?? '';
    _spotifyUrl.text = song.spotifyUrl ?? '';
    _hymnNumber.text = song.hymnNumber?.toString() ?? '';
  }

  Future<void> _save(Song song) async {
    final title = _title.text.trim();
    if (title.length < 2) {
      setState(() => _error = 'Informe o nome da música.');
      return;
    }

    // Só validado quando o campo existe (hino). Fora da faixa o servidor
    // recusaria de qualquer jeito; avisar aqui evita a ida perdida à rede.
    final numeroTexto = _hymnNumber.text.trim();
    final numero = numeroTexto.isEmpty ? null : int.tryParse(numeroTexto);
    if (song.isHymn && (numero == null || numero < 1 || numero > 581)) {
      setState(() => _error = 'O número do hino vai de 1 a 581.');
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
          'isNew': _isNew,
          if (song.isHymn) 'hymnNumber': numero,
          'artist': _artist.text.trim(),
          'composer': _composer.text.trim(),
          'originalKey': _originalKey.text.trim(),
          'lyricsUrl': _lyricsUrl.text.trim(),
          'chordsUrl': _chordsUrl.text.trim(),
          'youtubeUrl': _youtubeUrl.text.trim(),
          'spotifyUrl': _spotifyUrl.text.trim(),
          // A letra só vai quando mudou. São até 20 mil caracteres, e
          // reenviá-los a cada ajuste de tom é peso puro na rede da igreja.
          if (_lyrics.text != (song.lyrics ?? '')) 'lyrics': _lyrics.text.trim(),
        },
      );

      ref.invalidate(
        songProvider((teamId: widget.teamId, songId: widget.songId)),
      );
      // O título, o artista e o tom aparecem na lista: sem isto ela mostraria
      // o valor antigo até alguém puxar para atualizar.
      ref.invalidate(songsProvider(SongQuery(teamId: widget.teamId)));
      if (mounted) {
        context.pop();
        showAppSnackBar(context, '"$title" foi salva.', tone: AppTone.success);
      }
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
        body: const AppLoading(),
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
        // Só em hino, e só para corrigir. Oferecer "número do hino" em todo
        // cântico seria um campo vazio a mais em centenas de telas, para uma
        // pergunta que quase nunca tem resposta — quem cadastra hino faz isso
        // pelo import, não um a um.
        if (song.isHymn) ...[
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _hymnNumber,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Número no Cantor Cristão',
              helperText: 'De 1 a 581',
            ),
          ),
        ],
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
        const SizedBox(height: AppSpacing.lg),
        // Onde a novidade termina.
        //
        // É este o interruptor que fecha o ciclo: liga no cadastro, desliga
        // aqui quando a equipe domina e a igreja já canta junto. Nenhuma conta
        // do app sabe esse momento — tocar uma vez não encerra nada, e o
        // cadastro só diz quando a MÚSICA entrou no app, não quando a EQUIPE a
        // aprendeu. Fica junto de tom, tipo e andamento porque é da mesma
        // natureza: o que a equipe sabe e nenhuma API responde.
        SwitchListTile(
          value: _isNew,
          onChanged: _saving ? null : (v) => setState(() => _isNew = v),
          contentPadding: EdgeInsets.zero,
          title: const Text('Música nova'),
        ),
        const SizedBox(height: AppSpacing.xl),
        _ExternalFields(
          expanded: _showExternal,
          enabled: !_saving,
          onToggle: () => setState(() => _showExternal = !_showExternal),
          artist: _artist,
          composer: _composer,
          originalKey: _originalKey,
          lyrics: _lyrics,
          lyricsUrl: _lyricsUrl,
          chordsUrl: _chordsUrl,
          youtubeUrl: _youtubeUrl,
          spotifyUrl: _spotifyUrl,
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (_error != null) FormErrorBanner(message: _error!),
        AppSubmitButton(
          label: 'Salvar',
          loading: _saving,
          onPressed: () => _save(song),
        ),
      ],
    );
  }
}

/// O grupo recolhido: o que o import e o enriquecimento preencheram.
///
/// Fechado, resume o que já está lá ("cifra, letra, YouTube") em vez de só
/// dizer "mais campos": quem abre a tela para conferir um link descobre a
/// resposta sem precisar abrir nada.
class _ExternalFields extends StatelessWidget {
  const _ExternalFields({
    required this.expanded,
    required this.enabled,
    required this.onToggle,
    required this.artist,
    required this.composer,
    required this.originalKey,
    required this.lyrics,
    required this.lyricsUrl,
    required this.chordsUrl,
    required this.youtubeUrl,
    required this.spotifyUrl,
  });

  final bool expanded;
  final bool enabled;
  final VoidCallback onToggle;
  final TextEditingController artist;
  final TextEditingController composer;
  final TextEditingController originalKey;
  final TextEditingController lyrics;
  final TextEditingController lyricsUrl;
  final TextEditingController chordsUrl;
  final TextEditingController youtubeUrl;
  final TextEditingController spotifyUrl;

  String get _resumo {
    final tem = [
      if (chordsUrl.text.trim().isNotEmpty) 'cifra',
      if (lyricsUrl.text.trim().isNotEmpty || lyrics.text.trim().isNotEmpty)
        'letra',
      if (youtubeUrl.text.trim().isNotEmpty) 'YouTube',
      if (spotifyUrl.text.trim().isNotEmpty) 'Spotify',
    ];
    if (tem.isEmpty) return 'Nada preenchido ainda';
    return 'Tem ${tem.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: scheme.outlineVariant, height: 1),
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dados da música',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        expanded
                            ? 'Preenchidos automaticamente. Corrija se algo '
                                'veio errado.'
                            : _resumo,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: artist,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Artista'),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: composer,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Compositor'),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: originalKey,
            enabled: enabled,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Tom da gravação',
              helperText: 'Sugestão para "Nosso tom" — não é o que a equipe '
                  'canta',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _LinkField(
            controller: chordsUrl,
            enabled: enabled,
            label: 'Link da cifra',
            icon: Icons.music_note_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
          _LinkField(
            controller: lyricsUrl,
            enabled: enabled,
            label: 'Link da letra',
            icon: Icons.article_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
          _LinkField(
            controller: youtubeUrl,
            enabled: enabled,
            label: 'Link do YouTube',
            icon: Icons.play_circle_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
          _LinkField(
            controller: spotifyUrl,
            enabled: enabled,
            label: 'Link do Spotify',
            icon: Icons.headphones_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: lyrics,
            enabled: enabled,
            maxLines: 12,
            minLines: 4,
            decoration: const InputDecoration(
              labelText: 'Letra',
              alignLabelWithHint: true,
              helperText: 'Guardada aqui, e não só o link: site de letra sai '
                  'do ar e não abre no meio do culto.',
            ),
          ),
        ],
      ],
    );
  }
}

/// Campo de link. Teclado de URL e sem autocorreção — o corretor do celular
/// transformava "cifraclub" em outra palavra ao colar endereço.
class _LinkField extends StatelessWidget {
  const _LinkField({
    required this.controller,
    required this.enabled,
    required this.label,
    required this.icon,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.url,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        hintText: 'https://',
      ),
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
                    : (selected) => onChanged!(selected ? entry.key : null),
              ),
          ],
        ),
      ],
    );
  }
}
