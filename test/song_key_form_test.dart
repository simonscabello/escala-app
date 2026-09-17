import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:louvor_app/core/theme/app_theme.dart';
import 'package:louvor_app/features/songs/data/hymnal_repository.dart';
import 'package:louvor_app/features/songs/data/song_repository.dart';
import 'package:louvor_app/features/songs/domain/song_models.dart';
import 'package:louvor_app/features/songs/presentation/musical_key_picker.dart';
import 'package:louvor_app/features/songs/presentation/song_form_screen.dart';

/// O tom na edição da música.
///
/// O que estes testes protegem: o tom se escolhe numa lista e não se digita,
/// o escolhido é o que vai para o servidor, e a anotação feita antes da lista
/// ("G (capo 2)") sobrevive a quem abriu a música só para mudar outra coisa.
class _RepositorioFake extends SongRepository {
  _RepositorioFake() : super(Dio());

  Map<String, dynamic>? enviado;

  @override
  Future<Song> update(
    String teamId,
    String songId,
    Map<String, dynamic> body,
  ) async {
    enviado = body;
    return Song.fromJson({'id': songId, 'title': body['title'] as String});
  }
}

Future<_RepositorioFake> _abrir(
  WidgetTester tester, {
  String? defaultKey,
  String? originalKey,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repositorio = _RepositorioFake();
  final song = Song.fromJson({
    'id': 's1',
    'title': 'Cristo Venceu',
    'artist': 'Novo Canto',
    'defaultKey': defaultKey,
    'originalKey': originalKey,
  });

  final router = GoRouter(
    initialLocation: '/musica/editar',
    routes: [
      GoRoute(
        path: '/musica',
        builder: (_, __) => const Scaffold(body: Text('detalhe')),
        routes: [
          GoRoute(
            path: 'editar',
            builder: (_, __) =>
                SongFormScreen(teamId: 't1', songId: 's1', song: song),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        songRepositoryProvider.overrideWithValue(repositorio),
        hymnalsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return repositorio;
}

Future<void> _salvar(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Salvar'));
  await tester.tap(find.text('Salvar'));
  await tester.pumpAndSettle();
}

Finder _campo(String label) =>
    find.widgetWithText(MusicalKeyField, label);

void main() {
  testWidgets('o tom não tem teclado', (tester) async {
    await _abrir(tester, defaultKey: 'G');

    expect(
      find.descendant(
        of: find.byType(MusicalKeyField),
        matching: find.byType(EditableText),
      ),
      findsNothing,
    );
  });

  testWidgets('escolher um tom menor na folha e salvar', (tester) async {
    final repositorio = await _abrir(tester, defaultKey: 'G');

    await tester.tap(_campo('Nosso tom'));
    await tester.pumpAndSettle();

    // O tom atual abre marcado, na barra do modo dele.
    expect(
      tester.getSemantics(find.bySemanticsLabel('G maior')),
      matchesSemantics(isButton: true, isSelected: true, hasSelectedState: true),
    );

    await tester.tap(find.text('Menor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('F#m'));
    await tester.pumpAndSettle();

    // Tocar no tom fecha a folha: a escolha já está feita.
    expect(find.text('Menor'), findsNothing);
    expect(
      find.descendant(of: _campo('Nosso tom'), matching: find.text('F#m')),
      findsOneWidget,
    );

    await _salvar(tester);
    expect(repositorio.enviado!['defaultKey'], 'F#m');
  });

  testWidgets('anotação antiga aparece e volta intacta ao servidor',
      (tester) async {
    final repositorio = await _abrir(tester, defaultKey: 'G (capo 2)');

    expect(find.text('G (capo 2)'), findsOneWidget);
    expect(find.textContaining('Tom salvo antes da lista'), findsOneWidget);

    await _salvar(tester);
    expect(repositorio.enviado!['defaultKey'], 'G (capo 2)');
  });

  testWidgets('anotação antiga: abrir a folha e fechar sem escolher não apaga',
      (tester) async {
    final repositorio = await _abrir(tester, defaultKey: 'G (capo 2)');

    await tester.tap(_campo('Nosso tom'));
    await tester.pumpAndSettle();
    // Nada na grade corresponde à anotação.
    expect(find.bySemanticsLabel('G maior'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('G maior')),
      matchesSemantics(isButton: true, hasSelectedState: true),
    );

    await tester.tapAt(const Offset(180, 20));
    await tester.pumpAndSettle();

    await _salvar(tester);
    expect(repositorio.enviado!['defaultKey'], 'G (capo 2)');
  });

  testWidgets('tirar o tom manda vazio, que o servidor grava como nulo',
      (tester) async {
    final repositorio = await _abrir(tester, defaultKey: 'A');

    await tester.tap(_campo('Nosso tom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar'));
    await tester.pumpAndSettle();

    await _salvar(tester);
    expect(repositorio.enviado!['defaultKey'], '');
  });

  testWidgets('"Usar F#" copia o tom da gravação', (tester) async {
    final repositorio = await _abrir(tester, originalKey: 'F#');

    await tester.tap(find.text('Usar F#'));
    await tester.pumpAndSettle();
    expect(find.text('Usar F#'), findsNothing);

    await _salvar(tester);
    expect(repositorio.enviado!['defaultKey'], 'F#');
    expect(repositorio.enviado!['originalKey'], 'F#');
  });

  testWidgets('tom digitado em minúscula é salvo na grafia da lista',
      (tester) async {
    final repositorio = await _abrir(tester, defaultKey: 'bm');

    expect(find.textContaining('Tom salvo antes da lista'), findsNothing);

    await _salvar(tester);
    expect(repositorio.enviado!['defaultKey'], 'Bm');
  });
}
