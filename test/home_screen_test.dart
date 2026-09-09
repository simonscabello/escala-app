import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:louvor_app/core/storage/read_cache.dart';
import 'package:louvor_app/core/storage/shared_preferences_provider.dart';
import 'package:louvor_app/core/theme/app_theme.dart';
import 'package:louvor_app/features/auth/application/auth_controller.dart';
import 'package:louvor_app/features/auth/domain/auth_models.dart';
import 'package:louvor_app/features/events/data/event_repository.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';
import 'package:louvor_app/features/home/presentation/home_screen.dart';
import 'package:louvor_app/features/suggestions/data/suggestion_repository.dart';
import 'package:louvor_app/shared/widgets/app_hero_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// A Home é a porta de entrada, e o que ela promete é uma resposta pessoal:
/// **a sua** próxima escala, não a da equipe. Estes testes travam essa promessa
/// e os estados em que ela não pode parecer defeito.
void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('a manchete é a minha escala, não a próxima da equipe',
      (tester) async {
    await _pumpHome(
      tester,
      events: [
        // A próxima da equipe é esta, e eu não estou nela.
        _event(id: 'e1', startsAt: '2026-09-13T12:00:00.000Z'),
        _event(
          id: 'e2',
          startsAt: '2026-09-20T12:00:00.000Z',
          assignments: [
            ..._group('Vocal', ['Simon']),
            ..._group('Violão', ['Simon']),
          ],
          services: [
            _service(id: 's1', startsAt: '2026-09-20T12:00:00.000Z', songs: 5),
          ],
          rehearsalAt: '2026-09-19T22:30:00.000Z',
        ),
      ],
    );

    expect(find.text('MINHA PRÓXIMA ESCALA'), findsOneWidget);
    expect(find.text('Domingo,\n20 de setembro'), findsOneWidget);
    expect(find.text('Vocal · Violão'), findsOneWidget);
    expect(find.text('5 músicas'), findsOneWidget);
    expect(find.text('Ensaio sábado · 19:30'), findsOneWidget);
    expect(find.text('Ver escala'), findsOneWidget);
  });

  testWidgets('sem ensaio, nenhuma linha de ensaio — não se inventa ausência',
      (tester) async {
    await _pumpHome(
      tester,
      events: [
        _event(
          id: 'e1',
          startsAt: '2026-09-13T12:00:00.000Z',
          assignments: _group('Vocal', ['Simon']),
        ),
      ],
    );

    expect(find.text('Sem ensaio'), findsNothing);
    expect(find.textContaining('Ensaio'), findsNothing);
  });

  testWidgets('repertório vazio vira "Músicas a definir"', (tester) async {
    await _pumpHome(
      tester,
      events: [
        _event(
          id: 'e1',
          startsAt: '2026-09-13T12:00:00.000Z',
          assignments: _group('Vocal', ['Simon']),
          services: [
            _service(id: 's1', startsAt: '2026-09-13T12:00:00.000Z', songs: 0),
          ],
        ),
      ],
    );

    expect(find.text('Músicas a definir'), findsOneWidget);
  });

  testWidgets('sem participação minha, o estado é acolhedor e não erro',
      (tester) async {
    await _pumpHome(
      tester,
      events: [_event(id: 'e1', startsAt: '2026-09-13T12:00:00.000Z')],
    );

    // Continua sendo a manchete violeta: ficar de fora do próximo domingo é o
    // estado normal de metade da equipe, não uma falha da tela.
    expect(find.byType(AppHeroCard), findsOneWidget);
    expect(find.text('Você está livre por enquanto'), findsOneWidget);
    expect(
      find.text('Não encontramos nenhuma participação sua nas próximas escalas.'),
      findsOneWidget,
    );
    expect(find.text('Ver agenda da equipe'), findsOneWidget);
    expect(find.textContaining('erro'), findsNothing);
  });

  testWidgets('equipe sem escala nenhuma recebe outra frase', (tester) async {
    await _pumpHome(tester, events: const []);

    expect(find.text('Nada marcado por enquanto'), findsOneWidget);
    expect(find.text('Você está livre por enquanto'), findsNothing);
    // Quem gerencia recebe a saída, e ela é a de sempre.
    expect(find.text('Criar escala'), findsOneWidget);
    expect(find.text('Próximas escalas'), findsNothing);
  });

  testWidgets('a Home não repete a lista da agenda, e diz só "e depois"',
      (tester) async {
    await _pumpHome(
      tester,
      events: [
        _event(
          id: 'e1',
          startsAt: '2026-09-13T12:00:00.000Z',
          assignments: _group('Vocal', ['Simon']),
        ),
        // A equipe toca no dia 20 sem o Simon: essa data não é assunto da
        // Home, e mostrá-la aqui era a agenda em miniatura.
        _event(id: 'e2', startsAt: '2026-09-20T12:00:00.000Z'),
        _event(
          id: 'e3',
          startsAt: '2026-09-27T12:00:00.000Z',
          assignments: _group('Baixo', ['Simon']),
        ),
      ],
    );

    expect(find.text('Próximas escalas'), findsNothing);
    expect(find.text('Domingo, 20 de setembro'), findsNothing);
    // A seguinte EM QUE ELE ENTRA, numa linha dentro da manchete.
    expect(find.text('E depois: Domingo, 27 de setembro'), findsOneWidget);
  });

  testWidgets('sem segunda escala minha, a manchete não ganha linha nenhuma',
      (tester) async {
    await _pumpHome(
      tester,
      events: [
        _event(
          id: 'e1',
          startsAt: '2026-09-13T12:00:00.000Z',
          assignments: _group('Vocal', ['Simon']),
        ),
        _event(id: 'e2', startsAt: '2026-09-20T12:00:00.000Z'),
      ],
    );

    expect(find.textContaining('E depois:'), findsNothing);
  });

  testWidgets('os acessos rápidos levam ao que já existe', (tester) async {
    await _pumpHome(
      tester,
      events: const [],
      openSuggestions: 3,
    );

    expect(find.text('Acessos rápidos'), findsOneWidget);
    expect(find.text('Repertório'), findsOneWidget);
    expect(find.text('Cânticos e hinos'), findsOneWidget);
    expect(find.text('Sugestões'), findsOneWidget);
    // O selo é o mesmo da aba Equipe, com o mesmo provider por trás.
    expect(find.text('3'), findsOneWidget);

    // O terceiro atalho: no celular era o mais escondido dos três -- só se
    // chegava nele pelo Perfil -- e é o que tem prazo.
    expect(find.text('Minha disponibilidade'), findsOneWidget);
    expect(find.text('Avise quando não puder'), findsOneWidget);

    await tester.tap(find.text('Repertório'));
    await tester.pumpAndSettle();
    expect(find.text('tela do repertório'), findsOneWidget);
  });

  testWidgets('o atalho de disponibilidade abre a tela que já existe',
      (tester) async {
    await _pumpHome(tester, events: const [], role: 'MEMBER');

    await tester.tap(find.text('Minha disponibilidade'));
    await tester.pumpAndSettle();
    expect(find.text('minha disponibilidade'), findsOneWidget);
  });

  testWidgets('quem não gerencia não vê "Nova escala"', (tester) async {
    await _pumpHome(tester, events: const [], role: 'MEMBER');

    expect(find.text('Nova escala'), findsNothing);
    // Nem a saída de líder no estado vazio.
    expect(find.text('Criar escala'), findsNothing);
    expect(find.text('Ver agenda da equipe'), findsOneWidget);
    // Nem o selo de sugestões: a contagem é de quem pode respondê-las, e para
    // o integrante ela custaria uma requisição que não paga o próprio preço.
    expect(find.text('Peça uma música'), findsOneWidget);
  });

  testWidgets('quem gerencia recebe o botão de criar escala', (tester) async {
    await _pumpHome(
      tester,
      events: [
        _event(
          id: 'e1',
          startsAt: '2026-09-13T12:00:00.000Z',
          assignments: _group('Vocal', ['Simon']),
        ),
      ],
    );

    expect(find.text('Nova escala'), findsOneWidget);
  });

  testWidgets('a Home não estoura em nenhuma das larguras da lista',
      (tester) async {
    for (final width in [375.0, 600.0, 768.0, 1024.0, 1440.0]) {
      await _pumpHome(
        tester,
        size: Size(width, 1000),
        events: [
          _event(
            id: 'e1',
            startsAt: '2026-09-13T12:00:00.000Z',
            assignments: _group('Vocal', ['Simon']),
          ),
          _event(id: 'e2', startsAt: '2026-09-20T12:00:00.000Z'),
        ],
      );
      expect(tester.takeException(), isNull, reason: 'largura $width');
    }
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required List<Event> events,
  Size size = const Size(400, 1400),
  String role = 'OWNER',
  int openSuggestions = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: '/inicio',
    routes: [
      GoRoute(path: '/inicio', builder: (_, __) => const HomeScreen()),
      for (final route in const {
        '/agenda': 'tela da agenda',
        '/agenda/novo': 'nova escala',
        '/equipe/musicas': 'tela do repertório',
        '/equipe/sugestoes': 'tela das sugestões',
        '/disponibilidade': 'minha disponibilidade',
      }.entries)
        GoRoute(
          path: route.key,
          builder: (_, __) => Scaffold(body: Text(route.value)),
        ),
      GoRoute(
        path: '/agenda/:eventId',
        builder: (_, __) => const Scaffold(body: Text('detalhe da escala')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        eventsProvider.overrideWith(
          (ref, query) async => CachedValue(data: events, fromCache: false),
        ),
        openSuggestionCountProvider.overrideWith(
          (ref, teamId) async => openSuggestions,
        ),
        authControllerProvider.overrideWith(
          (ref) => _FakeAuthController(
            ref,
            AuthState.signedIn(
              const AuthUser(
                id: '1',
                name: 'Simon',
                email: 'simon@teste.com',
                mustChangePassword: false,
              ),
              [
                TeamSummary(
                  membershipId: 'm-Simon',
                  teamId: 't1',
                  name: 'Louvor SIBB',
                  role: role,
                  displayName: 'Simon',
                ),
              ],
            ),
          ),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Event _event({
  required String id,
  required String startsAt,
  String status = 'PUBLISHED',
  String? rehearsalAt,
  List<Map<String, dynamic>> assignments = const [],
  List<Map<String, dynamic>> services = const [],
}) =>
    Event.fromJson({
      'id': id,
      'teamId': 't1',
      'title': null,
      'startsAt': startsAt,
      'rehearsalAt': rehearsalAt,
      'location': null,
      'notes': null,
      'colorPalette': null,
      'status': status,
      'timezone': 'America/Sao_Paulo',
      'assignments': assignments,
      'services': services,
      'songs': const [],
    });

Map<String, dynamic> _service({
  required String id,
  required String startsAt,
  String label = 'Culto',
  int? songs,
}) =>
    {
      'id': id,
      'label': label,
      'startsAt': startsAt,
      if (songs != null) 'songCount': songs,
    };

List<Map<String, dynamic>> _group(String name, List<String> people) => [
      {
        'positionId': 'p-$name',
        'positionName': name,
        'sortOrder': 0,
        'members': [
          for (final p in people)
            {
              'id': 'a-$name-$p',
              'membershipId': 'm-$p',
              'displayName': p,
              'note': null,
              'isRegisteredForPosition': true,
            },
        ],
      },
    ];

class _FakeAuthController extends AuthController {
  _FakeAuthController(super.ref, this._initial);

  final AuthState _initial;

  @override
  Future<void> bootstrap() async {
    state = _initial;
  }
}
