import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/core/theme/app_theme.dart';
import 'package:louvor_app/features/songs/data/song_repository.dart';
import 'package:louvor_app/features/songs/domain/song_models.dart';
import 'package:louvor_app/features/suggestions/data/suggestion_repository.dart';
import 'package:louvor_app/features/suggestions/domain/song_suggestion.dart';
import 'package:louvor_app/features/suggestions/presentation/suggest_song_sheet.dart';

/// Os links na folha de sugerir.
///
/// Duas coisas quebram caladas aqui: o Spotify deixar de ser preenchido
/// sozinho (e a sugestão virar um título sem nada para ouvir) e a cobrança do
/// link da letra sumir — o que faria toda sugestão sem cadastro voltar do
/// servidor com 400 depois de a pessoa ter escrito a justificativa inteira.
class _SongsFake extends SongRepository {
  _SongsFake({this.externas = const []}) : super(Dio());

  final List<ExternalCandidate> externas;

  /// Repertório vazio: o que estes testes verificam é o caminho do Spotify e o
  /// da música que já veio escolhida, e nenhum dos dois passa pela busca
  /// local.
  @override
  Future<List<Song>> list(
    String teamId, {
    String? search,
    bool includeArchived = false,
    Set<String> themes = const {},
  }) async =>
      const [];

  @override
  Future<List<ExternalCandidate>> searchExternal(
    String teamId,
    String search,
  ) async =>
      externas;
}

class _SuggestionsFake extends SuggestionRepository {
  _SuggestionsFake() : super(Dio());

  Map<String, String?>? enviado;

  @override
  Future<SongSuggestion> create(
    String teamId, {
    required String title,
    required String reason,
    String? songId,
    String? artist,
    String? lyricsUrl,
    String? spotifyUrl,
    String? youtubeUrl,
    DateTime? targetDate,
  }) async {
    enviado = {
      'title': title,
      'songId': songId,
      'lyricsUrl': lyricsUrl,
      'spotifyUrl': spotifyUrl,
      'youtubeUrl': youtubeUrl,
    };
    return SongSuggestion.fromJson({
      'id': 'sg1',
      'songId': songId,
      'title': title,
      'artist': artist,
      'lyricsUrl': lyricsUrl,
      'spotifyUrl': spotifyUrl,
      'youtubeUrl': youtubeUrl,
      'targetDate': null,
      'reason': reason,
      'status': 'PENDING',
      'declineReason': null,
      'inRepertoire': songId != null,
      'createdBy': {
        'membershipId': 'm1',
        'displayName': 'Maria',
        'avatarUrl': null,
      },
      'createdAt': '2026-09-03T12:00:00.000Z',
      'alsoSuggestedBy': const [],
    });
  }
}

Future<_SuggestionsFake> _montar(
  WidgetTester tester, {
  required _SongsFake songs,
  Song? song,
}) async {
  tester.view.physicalSize = const Size(375 * 3, 812 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final sugestoes = _SuggestionsFake();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        songRepositoryProvider.overrideWithValue(songs),
        suggestionRepositoryProvider.overrideWithValue(sugestoes),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SuggestSongSheet(teamId: 't1', song: song),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return sugestoes;
}

/// O campo de link, achado pelo rótulo — é o mesmo gesto de quem usa a tela.
Finder campo(String rotulo) => find.ancestor(
      of: find.text(rotulo),
      matching: find.byType(TextField),
    );

/// Rola até o botão e envia. A folha é uma lista: o botão fica abaixo da
/// dobra, como fica no celular de verdade.
Future<void> enviar(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Enviar sugestão'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Enviar sugestão'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a escolha do Spotify já grava a URL, sem ninguém colar nada',
      (tester) async {
    final sugestoes = await _montar(
      tester,
      songs: _SongsFake(
        externas: const [
          ExternalCandidate(
            title: 'Bondade de Deus',
            artist: 'Isaías Saad',
            spotifyUrl: 'https://open.spotify.com/track/abc',
          ),
        ],
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Bondade');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bondade de Deus').last);
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(campo('Spotify (opcional)')).controller?.text,
      'https://open.spotify.com/track/abc',
    );

    // A letra continua sendo cobrada: o Spotify não resolve "que música é
    // essa" para quem vai reger o culto.
    // O último campo é a justificativa: os três de link vêm antes dela.
    await tester.enterText(
      find.byType(TextField).last,
      'A igreja já canta essa nos cultos de oração.',
    );
    await tester.pumpAndSettle();
    await enviar(tester);

    expect(sugestoes.enviado, isNull);
    expect(
      find.textContaining('Mande o link da letra ou da cifra'),
      findsOneWidget,
    );

    // Com o link, vai — e vai com o Spotify junto.
    await tester.enterText(
      campo('Link da letra ou cifra'),
      'https://www.cifraclub.com.br/isaias-saad/bondade-de-deus/',
    );
    await tester.pumpAndSettle();
    await enviar(tester);

    expect(sugestoes.enviado?['spotifyUrl'], 'https://open.spotify.com/track/abc');
    expect(
      sugestoes.enviado?['lyricsUrl'],
      'https://www.cifraclub.com.br/isaias-saad/bondade-de-deus/',
    );
  });

  testWidgets('música do repertório chega com os links dela e sem cobrança',
      (tester) async {
    const song = Song(
      id: 's1',
      title: 'Deus é Deus',
      artist: 'Delino Marçal',
      chordsUrl: 'https://www.cifraclub.com.br/deus-e-deus/',
      youtubeUrl: 'https://www.youtube.com/watch?v=xyz',
    );

    final sugestoes = await _montar(tester, songs: _SongsFake(), song: song);

    // Preenchidos sozinhos: pedir de novo o que já está cadastrado é pedir o
    // que já se tem.
    expect(
      tester.widget<TextField>(campo('Link da letra ou cifra (opcional)'))
          .controller
          ?.text,
      'https://www.cifraclub.com.br/deus-e-deus/',
    );
    expect(
      tester.widget<TextField>(campo('YouTube (opcional)')).controller?.text,
      'https://www.youtube.com/watch?v=xyz',
    );

    // E o rótulo não cobra: a música já está no repertório.
    expect(
      find.textContaining('Obrigatório: essa música ainda não está'),
      findsNothing,
    );

    await tester.enterText(
      find.byType(TextField).last,
      'Faz tempo que a gente não canta essa.',
    );
    await tester.pumpAndSettle();
    await enviar(tester);

    expect(sugestoes.enviado?['songId'], 's1');
    expect(
      sugestoes.enviado?['lyricsUrl'],
      'https://www.cifraclub.com.br/deus-e-deus/',
    );
  });
}
