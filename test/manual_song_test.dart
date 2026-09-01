import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/core/theme/app_theme.dart';
import 'package:louvor_app/features/songs/data/song_repository.dart';
import 'package:louvor_app/features/songs/domain/song_models.dart';
import 'package:louvor_app/features/songs/presentation/add_song_screen.dart';

class _RepositorioFake extends SongRepository {
  _RepositorioFake() : super(Dio());

  Map<String, dynamic>? ultimoCadastro;

  @override
  Future<List<CatalogCandidate>> catalog(String teamId, String search) async =>
      [];

  @override
  Future<List<ExternalCandidate>> searchExternal(
    String teamId,
    String search,
  ) async =>
      [];

  @override
  Future<Song> create(String teamId, Map<String, dynamic> body) async {
    ultimoCadastro = body;
    return Song(
      id: 'm1',
      title: body['title'] as String,
      artist: body['artist'] as String?,
      isNew: body['isNew'] as bool? ?? false,
    );
  }
}

void main() {
  testWidgets('cadastra manualmente quando nenhuma busca encontra a música', (
    tester,
  ) async {
    final repositorio = _RepositorioFake();
    Song? criada;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          songRepositoryProvider.overrideWithValue(repositorio),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: AddSongScreen(
            teamId: 't1',
            onCreated: (song) => criada = song,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Canção da igreja');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Nada encontrado'), findsOneWidget);
    await tester.tap(find.text('Cadastrar manualmente'));
    await tester.pumpAndSettle();

    final campos = find.byType(TextFormField);
    expect(campos, findsNWidgets(2));
    expect(
      tester.widget<TextFormField>(campos.first).controller?.text,
      'Canção da igreja',
    );
    await tester.enterText(campos.at(1), 'Ministério local');
    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();

    expect(
      repositorio.ultimoCadastro,
      {
        'title': 'Canção da igreja',
        'artist': 'Ministério local',
        'isNew': true,
      },
    );
    expect(criada?.title, 'Canção da igreja');
  });
}
