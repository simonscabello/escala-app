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
import 'package:louvor_app/features/events/presentation/agenda_screen.dart';
import 'package:louvor_app/features/team/data/team_repository.dart';
import 'package:louvor_app/features/team/domain/service_template.dart';
import 'package:louvor_app/features/team/domain/team_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// A agenda mostra as escalas em três degraus — a próxima, a seguinte, e o
/// resto agrupado por mês —, e a regra que sustenta isso é uma só: **nenhuma
/// escala aparece duas vezes**.
///
/// É o tipo de erro que passa despercebido numa revisão visual (duas linhas
/// iguais em pontos distantes da rolagem) e que faz a pessoa achar que tem
/// escala em dobro. Daí os testes contarem ocorrências, e não só presença.
void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting('pt_BR');
  });

  group('agrupamento por mês', () {
    test('separa os meses e preserva a ordem em que as escalas vieram', () {
      final grupos = groupEventsByMonth([
        _event(id: 'a', startsAt: '2026-09-13T12:00:00.000Z'),
        _event(id: 'b', startsAt: '2026-09-20T12:00:00.000Z'),
        _event(id: 'c', startsAt: '2026-10-04T12:00:00.000Z'),
      ]);

      expect(grupos.map((g) => g.label), ['Setembro 2026', 'Outubro 2026']);
      expect(grupos.first.events.map((e) => e.id), ['a', 'b']);
      expect(grupos.last.events.map((e) => e.id), ['c']);
    });

    test('setembro de dois anos diferentes não vira um grupo só', () {
      // O rótulo é o mesmo nos dois; a chave é que os separa.
      final grupos = groupEventsByMonth([
        _event(id: 'a', startsAt: '2026-09-13T12:00:00.000Z'),
        _event(id: 'b', startsAt: '2027-09-12T12:00:00.000Z'),
      ]);

      expect(grupos, hasLength(2));
      expect(grupos.map((g) => g.key), ['2026-09', '2027-09']);
    });

    test('agrupa pelo dia civil da equipe, não pelo UTC', () {
      // 1º de setembro às 00:30 em São Paulo é 03:30 UTC do mesmo dia; mas
      // 31 de agosto às 22:00 local é 1º de setembro em UTC. Agrupar pelo UTC
      // jogaria a escala de agosto para dentro de setembro.
      final grupos = groupEventsByMonth([
        _event(id: 'agosto', startsAt: '2026-09-01T01:00:00.000Z'),
      ]);

      expect(grupos.single.label, 'Agosto 2026');
    });
  });

  testWidgets('a próxima é manchete, a seguinte tem bloco, o resto vai por mês',
      (tester) async {
    await _pumpAgenda(tester, const Size(400, 1400));

    expect(find.text('PRÓXIMA ESCALA'), findsOneWidget);
    expect(find.text('Depois dessa'), findsOneWidget);
    expect(find.text('Setembro 2026'), findsOneWidget);

    // A manchete e o bloco "Depois dessa" saem do agrupamento: das cinco
    // escalas, três sobram para o mês.
    expect(find.text('3 escalas'), findsOneWidget);
  });

  testWidgets('nenhuma escala aparece duas vezes', (tester) async {
    await _pumpAgenda(tester, const Size(400, 1400));

    // A data da manchete (dia 10) e a da seguinte (dia 13) não podem
    // reaparecer na lista dos meses.
    expect(find.text('Quinta-feira, 10 de setembro'), findsNothing);
    expect(
      find.text('Quinta-feira,\n10 de setembro'),
      findsOneWidget,
      reason: 'a manchete quebra a data depois da vírgula',
    );
    expect(find.text('Domingo, 13 de setembro'), findsOneWidget);
    expect(find.text('Quinta-feira, 17 de setembro'), findsOneWidget);
  });

  testWidgets('com uma escala só, a agenda é só a manchete', (tester) async {
    await _pumpAgenda(tester, const Size(400, 1400), take: 1);

    expect(find.text('PRÓXIMA ESCALA'), findsOneWidget);
    expect(find.text('Depois dessa'), findsNothing);
    expect(find.text('Setembro 2026'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('com duas escalas, "Ver todas" não aparece — não há para onde ir',
      (tester) async {
    await _pumpAgenda(tester, const Size(400, 1400), take: 2);

    expect(find.text('Depois dessa'), findsOneWidget);
    expect(find.text('Ver todas'), findsNothing);
  });

  testWidgets('"Ver todas" aparece quando há lista abaixo', (tester) async {
    await _pumpAgenda(tester, const Size(400, 1400));

    expect(find.text('Ver todas'), findsOneWidget);
  });

  testWidgets('nas passadas não há manchete: tudo vai por mês',
      (tester) async {
    await _pumpAgenda(tester, const Size(400, 1400));
    await tester.tap(find.text('Passadas'));
    await tester.pumpAndSettle();

    expect(find.text('PRÓXIMA ESCALA'), findsNothing);
    expect(find.text('Depois dessa'), findsNothing);
    // As cinco entram no agrupamento, nenhuma é promovida.
    expect(find.text('5 escalas'), findsOneWidget);
  });

  testWidgets('a contagem de pessoas sai da escalação, sem chamada nova',
      (tester) async {
    await _pumpAgenda(tester, const Size(400, 1400));

    // Três funções, quatro pessoas — Simon aparece em duas e conta uma vez.
    expect(find.text('4 pessoas na escala'), findsOneWidget);
  });

  testWidgets('escala sem ninguém escalado diz isso na manchete',
      (tester) async {
    await _pumpAgenda(tester, const Size(400, 1400), semEquipe: true);

    expect(find.text('Ninguém escalado ainda'), findsOneWidget);
  });
}

Map<String, dynamic> _eventJson({
  required String id,
  required String startsAt,
  String status = 'PUBLISHED',
  List<Map<String, dynamic>> assignments = const [],
}) =>
    {
      'id': id,
      'teamId': 't1',
      'title': null,
      'startsAt': startsAt,
      'rehearsalAt': null,
      'location': null,
      'notes': null,
      'colorPalette': null,
      'status': status,
      'timezone': 'America/Sao_Paulo',
      'assignments': assignments,
      'songs': const [],
    };

Event _event({required String id, required String startsAt}) =>
    Event.fromJson(_eventJson(id: id, startsAt: startsAt));

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

Future<void> _pumpAgenda(
  WidgetTester tester,
  Size size, {
  int take = 5,
  bool semEquipe = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();

  final events = <Event>[
    Event.fromJson(
      _eventJson(
        id: 'e1',
        startsAt: '2026-09-10T22:30:00.000Z',
        assignments: semEquipe
            ? const []
            : [
                ..._group('Vocal', ['Simon', 'Maria']),
                ..._group('Baixo', ['Simon']),
                ..._group('Guitarra', ['Joao', 'Ana']),
              ],
      ),
    ),
    Event.fromJson(_eventJson(id: 'e2', startsAt: '2026-09-13T11:30:00.000Z')),
    Event.fromJson(_eventJson(id: 'e3', startsAt: '2026-09-17T22:30:00.000Z')),
    Event.fromJson(_eventJson(id: 'e4', startsAt: '2026-09-20T11:30:00.000Z')),
    Event.fromJson(_eventJson(id: 'e5', startsAt: '2026-09-24T22:30:00.000Z')),
  ].take(take).toList();

  final router = GoRouter(
    initialLocation: '/agenda',
    routes: [
      GoRoute(path: '/agenda', builder: (_, __) => const AgendaScreen()),
      GoRoute(
        path: '/agenda/novo',
        builder: (_, __) => const Scaffold(body: Text('novo')),
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
        // Grade vazia: estes testes são sobre a arrumação da lista, e as datas
        // em aberto mudam conforme o dia em que o teste roda.
        serviceTemplatesProvider.overrideWith(
          (ref, teamId) async => const <ServiceTemplate>[],
        ),
        teamProvider.overrideWith(
          (ref, teamId) async => const Team(
            id: 't1',
            name: 'Louvor SIBB',
            timezone: 'America/Sao_Paulo',
          ),
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
              const [
                TeamSummary(
                  membershipId: 'm-Simon',
                  teamId: 't1',
                  name: 'Louvor SIBB',
                  role: 'OWNER',
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

class _FakeAuthController extends AuthController {
  _FakeAuthController(super.ref, this._initial);

  final AuthState _initial;

  @override
  Future<void> bootstrap() async {
    state = _initial;
  }
}
