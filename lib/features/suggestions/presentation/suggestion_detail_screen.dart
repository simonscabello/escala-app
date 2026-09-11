import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../songs/data/song_repository.dart';
import '../../songs/domain/song_models.dart';
import '../../songs/presentation/add_song_screen.dart';
import '../data/suggestion_repository.dart';
import '../domain/song_suggestion.dart';
import 'suggestions_screen.dart' show suggestionMaterialIcon;

/// Abre o detalhe de uma sugestão.
///
/// `Navigator.push` e não `context.push` do go_router, pelo mesmo motivo do
/// cadastro de música aberto de dentro da escala: a tela de trás — que pode
/// ser a montagem do repertório, com trabalho não salvo — continua viva
/// embaixo e volta intacta.
///
/// `suggestion` é o que a lista já tinha em mãos: a tela desenha na hora com
/// ele e troca pelo que o servidor responder. Sem isso, tocar num cartão daria
/// uma tela em branco a cada vez.
Future<void> openSuggestionDetail(
  BuildContext context, {
  required String teamId,
  required SongSuggestion suggestion,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => SuggestionDetailScreen(
        teamId: teamId,
        suggestionId: suggestion.id,
        initial: suggestion,
      ),
    ),
  );
}

/// A sugestão inteira, e as decisões sobre ela.
///
/// Mesmo formato da tela de uma música do repertório — título grande, artista
/// embaixo, os materiais como chips, e o corpo do texto num cartão — porque é
/// a mesma pergunta que se faz nas duas: "o que é essa música, e vale a pena?"
/// O que muda é o que a página tem a mais: o motivo assinado de quem pediu, e
/// as duas decisões no rodapé.
class SuggestionDetailScreen extends ConsumerStatefulWidget {
  const SuggestionDetailScreen({
    super.key,
    required this.teamId,
    required this.suggestionId,
    this.initial,
  });

  final String teamId;
  final String suggestionId;

  /// O que a lista já sabia, para a tela nascer desenhada.
  final SongSuggestion? initial;

  @override
  ConsumerState<SuggestionDetailScreen> createState() =>
      _SuggestionDetailScreenState();
}

class _SuggestionDetailScreenState
    extends ConsumerState<SuggestionDetailScreen> {
  bool _busy = false;

  SuggestionRef get _args => (teamId: widget.teamId, id: widget.suggestionId);

  void _refresh() {
    ref.invalidate(suggestionProvider(_args));
    ref.invalidate(suggestionsProvider);
    ref.invalidate(openSuggestionCountProvider);
    ref.invalidate(eventSuggestionsProvider);
  }

  /// Roda a ação, avisa e volta para a lista.
  ///
  /// Fechar a tela faz parte da decisão: respondida, a sugestão mudou de aba,
  /// e deixar a pessoa olhando para uma tela que já não corresponde à lista de
  /// trás seria pedir que ela mesma descobrisse isso.
  Future<void> _run(
    Future<void> Function() action,
    String ok, {
    bool close = true,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
      if (!mounted) return;
      if (close) Navigator.of(context).pop();
      showAppSnackBar(context, ok, tone: AppTone.success);
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, tone: AppTone.danger);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Aceitar.
  ///
  /// Com a música no repertório, é um toque só. Sem ela, cadastrar **é** a
  /// resposta afirmativa — e o cadastro abre com o que a sugestão já trouxe:
  /// título, artista e os links. Redigitar o que quem sugeriu digitou é o tipo
  /// de trabalho que faz o líder deixar a sugestão para depois.
  ///
  /// O `isNew` continua sendo decidido lá, à mão, onde já nasce marcado:
  /// ligá-lo aqui seria deduzir "a equipe está aprendendo" de "alguém
  /// sugeriu".
  Future<void> _accept(SongSuggestion s) async {
    var songId = s.songId;

    if (songId == null) {
      final cadastrar = await showConfirmDialog(
        context,
        title: 'Adicionar ao repertório?',
        message: '"${s.title}" ainda não está no repertório da equipe. '
            'O cadastro abre com o que a sugestão trouxe — só falta conferir.',
        confirmLabel: 'Adicionar ao repertório',
      );
      if (!cadastrar || !mounted) return;

      final criada = await Navigator.of(context).push<Song>(
        MaterialPageRoute(
          builder: (rota) => AddSongScreen(
            teamId: widget.teamId,
            initialSearch: s.title,
            initialArtist: s.artist,
            initialLyricsUrl: s.lyricsUrl,
            initialYoutubeUrl: s.youtubeUrl,
            initialSpotifyUrl: s.spotifyUrl,
            onCreated: (song) => Navigator.of(rota).pop(song),
          ),
        ),
      );
      if (criada == null || !mounted) return;
      songId = criada.id;
      ref.invalidate(songsProvider);
    }

    await _run(
      () => ref
          .read(suggestionRepositoryProvider)
          .accept(widget.teamId, s.id, songId: songId)
          .then((_) {}),
      'Sugestão aceita.',
    );
  }

  /// Recusar. O motivo é opcional e a tela **não** empurra ninguém a escrever:
  /// às vezes o motivo certo (teologia, por exemplo) é uma conversa pessoal, e
  /// o app não é o canal. O rótulo avisa que quem sugeriu vai ler — sem isso,
  /// um líder escreve achando que é nota interna e o app entrega na cara da
  /// pessoa.
  Future<void> _decline(SongSuggestion s) async {
    final controller = TextEditingController();
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Recusar sugestão'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${s.title}" vai para as encerradas.'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                helperText: 'Quem sugeriu vai ler. Pode deixar em branco e '
                    'conversar pessoalmente.',
                helperMaxLines: 3,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    final motivo = controller.text.trim();
    controller.dispose();
    if (confirmou != true) return;

    await _run(
      () => ref
          .read(suggestionRepositoryProvider)
          .decline(widget.teamId, s.id, reason: motivo)
          .then((_) {}),
      'Respondido.',
    );
  }

  /// Desfaz a resolução, para o toque errado não virar beco sem saída. Aqui a
  /// tela **fica aberta**: reabrir não é uma resposta, é voltar ao começo.
  Future<void> _reopen(SongSuggestion s) => _run(
        () => ref
            .read(suggestionRepositoryProvider)
            .reopen(widget.teamId, s.id)
            .then((_) {}),
        'Sugestão reaberta.',
        close: false,
      );

  Future<void> _remove(SongSuggestion s) async {
    final confirmou = await showConfirmDialog(
      context,
      title: 'Excluir sugestão?',
      message: '"${s.title}" some da lista para todo mundo.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!confirmou) return;

    await _run(
      () => ref.read(suggestionRepositoryProvider).remove(widget.teamId, s.id),
      'Sugestão excluída.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pedida = ref.watch(suggestionProvider(_args));
    // O que o servidor respondeu manda; enquanto ele não responde, vale o que
    // a lista trouxe. Sem o segundo, tocar num cartão daria uma tela vazia.
    final s = pedida.valueOrNull ?? widget.initial;

    final team = ref
        .watch(authControllerProvider)
        .teams
        .where((t) => t.teamId == widget.teamId)
        .firstOrNull;
    final canManage = team?.canManage ?? false;
    final isMine = s?.createdBy.membershipId == team?.membershipId;

    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sugestão')),
        body: pedida.hasError
            ? AppErrorState(
                message: pedida.error is ApiException
                    ? (pedida.error as ApiException).message
                    : 'Não foi possível carregar a sugestão.',
                onRetry: () => ref.invalidate(suggestionProvider(_args)),
              )
            : const AppLoading(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sugestão'),
        actions: [
          if (isMine || canManage)
            IconButton(
              tooltip: 'Excluir',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _busy ? null : () => _remove(s),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AppContentWidth.reading(
          child: _Body(
            suggestion: s,
            isMine: isMine,
            canManage: canManage,
            busy: _busy,
            onAccept: () => _accept(s),
            onDecline: () => _decline(s),
            onReopen: () => _reopen(s),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.suggestion,
    required this.isMine,
    required this.canManage,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onReopen,
  });

  final SongSuggestion suggestion;
  final bool isMine;
  final bool canManage;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = suggestion;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        // `Wrap` e não `Row`, como na tela da música: título longo ocupa duas
        // linhas e a etiqueta desce inteira em vez de espremer o nome.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Text(s.title, style: theme.textTheme.headlineSmall),
            if (s.status == SuggestionStatus.accepted)
              const AppBadge(
                label: 'Acolhida',
                tone: AppTone.success,
                icon: Icons.check_circle_outline_rounded,
              ),
            if (s.status == SuggestionStatus.declined)
              const AppBadge(label: 'Recusada', tone: AppTone.neutral),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          (s.artist ?? '').isEmpty ? 'Sem artista' : s.artist!,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Para quando, e se já existe cadastro. Os dois mudam o que o líder
        // faz a seguir: só programar, ou cadastrar antes.
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            AppBadge(
              label: s.isForRepertoire
                  ? 'Para o repertório'
                  : 'Para ${_dataLonga(s.targetDate!)}',
              icon: s.isForRepertoire
                  ? Icons.library_music_outlined
                  : Icons.event_rounded,
              tone: s.isForRepertoire ? AppTone.neutral : AppTone.primary,
            ),
            if (s.inRepertoire)
              const AppBadge(
                label: 'Já está no repertório',
                icon: Icons.check_rounded,
                tone: AppTone.neutral,
              ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),
        _Materials(materials: s.materials),

        const SizedBox(height: AppSpacing.xl),
        const SectionHeader(
          title: 'Por que essa música',
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
        ),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Inteiro, e sem cortar: é o conteúdo da sugestão, e é o que
              // torna a recusa uma resposta a um argumento em vez de resposta
              // ao gosto de alguém.
              Text(
                s.reason,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  AppAvatar(
                    name: s.createdBy.displayName,
                    imageUrl: s.createdBy.avatarUrl,
                    radius: 12,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _assinatura(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // O motivo da recusa, quando existe. Em branco não vira rótulo
        // pendurado no vazio — campo vazio é uso legítimo, não esquecimento.
        if ((s.declineReason ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(
            title: 'Resposta',
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            surface: CardSurface.sunken,
            child: Text(s.declineReason!, style: theme.textTheme.bodyMedium),
          ),
        ],

        const SizedBox(height: AppSpacing.xxl),
        ..._acoes(context),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  /// As decisões, no fim da página e não no topo: elas vêm depois de ler o
  /// motivo, que é a ordem em que a decisão acontece de verdade.
  List<Widget> _acoes(BuildContext context) {
    if (!canManage) return const [];

    if (busy) {
      return const [
        Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ];
    }

    if (suggestion.status.isResolved) {
      return [
        OutlinedButton.icon(
          onPressed: onReopen,
          icon: const Icon(Icons.undo_rounded),
          label: const Text('Reabrir'),
        ),
      ];
    }

    return [
      // Empilhados, e não lado a lado: "Aceitar sugestão" não cabe ao lado de
      // "Recusar" num celular estreito, e meio botão cortado num par de
      // decisões opostas é como se toca na errada.
      FilledButton.icon(
        onPressed: onAccept,
        icon: const Icon(Icons.check_rounded),
        label: const Text('Aceitar sugestão'),
      ),
      const SizedBox(height: AppSpacing.sm),
      TextButton(onPressed: onDecline, child: const Text('Recusar')),
    ];
  }

  String _assinatura() {
    final quem = isMine ? 'Você' : suggestion.createdBy.displayName;
    final outros = suggestion.alsoSuggestedBy;
    if (outros.isEmpty) return 'Sugerida por $quem';

    // Repetida é sinal, não erro: dizer quem mais quer a mesma música é metade
    // do que o líder precisa para priorizar. Aqui cabem os nomes.
    final lista = outros.length == 1
        ? outros.first
        : '${outros.take(outros.length - 1).join(', ')} e ${outros.last}';
    final verbo = outros.length == 1 ? 'também sugeriu' : 'também sugeriram';
    return 'Sugerida por $quem · $lista $verbo';
  }
}

/// Os materiais, como chips que abrem fora do app.
///
/// **Só o que existe.** Botão apagado para um link que ninguém mandou seria
/// uma promessa falsa, e a seção inteira some quando não há nada — o que só
/// acontece em sugestão antiga, já que hoje o servidor exige a letra ou a
/// cifra de toda música que ainda não está no repertório.
class _Materials extends StatelessWidget {
  const _Materials({required this.materials});

  final List<SuggestionMaterial> materials;

  Future<void> _open(BuildContext context, String url) async {
    // `Uri.tryParse` e não `parse`: o link vem digitado por alguém, e uma
    // exceção aqui derrubaria a tela inteira por causa de um espaço a mais.
    final uri = Uri.tryParse(url.trim());
    final ok = uri == null
        ? false
        : await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showAppSnackBar(
        context,
        'Não foi possível abrir o link.',
        tone: AppTone.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final material in materials)
          ActionChip(
            avatar: Icon(suggestionMaterialIcon(material.kind), size: 18),
            label: Text(material.label),
            onPressed: () => _open(context, material.url),
          ),
      ],
    );
  }
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
