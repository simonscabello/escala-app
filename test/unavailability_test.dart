import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:louvor_app/core/theme/app_theme.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';
import 'package:louvor_app/features/unavailability/data/unavailability_repository.dart';
import 'package:louvor_app/features/unavailability/domain/unavailability_models.dart';
import 'package:louvor_app/features/unavailability/presentation/my_unavailability_screen.dart';

/// O repositório da tela, sem rede. Guarda o que foi mandado corrigir: é isso
/// que separa "a tela abriu a caixa" de "a correção chegou ao servidor".
class _UnavailabilityFake extends UnavailabilityRepository {
  _UnavailabilityFake(this.items) : super(Dio());

  final List<Unavailability> items;
  ({String id, String? reason})? corrigido;

  @override
  Future<List<Unavailability>> listMine(String teamId) async => items;

  @override
  Future<Unavailability> updateReason(
    String teamId,
    String id, {
    required String? reason,
  }) async {
    corrigido = (id: id, reason: reason);
    final index = items.indexWhere((item) => item.id == id);
    items[index] = Unavailability(
      id: id,
      membershipId: items[index].membershipId,
      date: items[index].date,
      reason: reason,
    );
    return items[index];
  }
}

/// Um domingo que ainda não chegou: a tela só lista os dias daqui para a
/// frente, e uma data fixa no código faria o teste passar a falhar sozinho.
DateTime _proximoDomingo() {
  final hoje = DateTime.now();
  final dia = DateTime(hoje.year, hoje.month, hoje.day);
  return dia.add(Duration(days: (DateTime.sunday - dia.weekday) % 7 + 7));
}

Future<_UnavailabilityFake> _montarTela(
  WidgetTester tester, {
  String? reason,
}) async {
  tester.view.physicalSize = const Size(375 * 3, 812 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final repositorio = _UnavailabilityFake([
    Unavailability(
      id: 'u1',
      membershipId: 'm1',
      date: _proximoDomingo(),
      reason: reason,
    ),
  ]);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        unavailabilityRepositoryProvider.overrideWithValue(repositorio),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const MyUnavailabilityScreen(teamId: 't1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repositorio;
}

Map<String, dynamic> eventJson({
  List<Map<String, dynamic>> unavailable = const [],
  List<Map<String, dynamic>> unavailableAssigned = const [],
}) {
  return {
    'id': 'e1',
    'teamId': 't1',
    'title': 'Domingo de manhã',
    'startsAt': '2026-08-16T12:00:00.000Z',
    'rehearsalAt': null,
    'location': null,
    'notes': null,
    'colorPalette': null,
    'status': 'PUBLISHED',
    'timezone': 'America/Sao_Paulo',
    'assignments': const [],
    'songs': const [],
    'unavailable': unavailable,
    'warnings': {'unavailableAssigned': unavailableAssigned},
  };
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  group('Unavailability', () {
    test('data vem como dia civil, sem hora nem fuso', () {
      final item = Unavailability.fromJson({
        'id': 'u1',
        'membershipId': 'm1',
        'date': '2026-08-16',
        'reason': 'Viagem',
      });

      expect(item.date.year, 2026);
      expect(item.date.month, 8);
      expect(item.date.day, 16);
      // Sem conversão de fuso: um `DateTime.utc` aqui poderia voltar para 15.
      expect(item.date.isUtc, isFalse);
      expect(item.reason, 'Viagem');
    });

    test('motivo é opcional', () {
      final item = Unavailability.fromJson({
        'id': 'u1',
        'membershipId': 'm1',
        'date': '2026-08-16',
        'reason': null,
      });

      expect(item.reason, isNull);
    });
  });

  group('Escala com indisponibilidade', () {
    test('lê quem avisou que não pode no dia', () {
      final event = Event.fromJson(
        eventJson(
          unavailable: [
            {
              'membershipId': 'm1',
              'displayName': 'Joao',
              'reason': 'Viagem',
            },
          ],
        ),
      );

      expect(event.unavailable, hasLength(1));
      expect(event.unavailable.first.displayName, 'Joao');
      expect(event.unavailable.first.reason, 'Viagem');
    });

    test('sem indisponibilidade a lista vem vazia, nunca nula', () {
      final event = Event.fromJson(eventJson());
      expect(event.unavailable, isEmpty);
      expect(event.warnings.unavailableAssigned, isEmpty);
    });

    test('avisa quando alguém escalado tinha marcado ausência', () {
      final event = Event.fromJson(
        eventJson(
          unavailableAssigned: [
            {'membershipId': 'm1', 'displayName': 'Joao', 'reason': null},
          ],
        ),
      );

      expect(event.warnings.unavailableAssigned, hasLength(1));
      expect(event.warnings.unavailableAssigned.first.displayName, 'Joao');
    });
  });

  /// Corrigir o motivo de um dia.
  ///
  /// O motivo nasce por lote -- uma viagem cobre cinco domingos -- e depois um
  /// deles vira outra coisa. Sem isto a saída era desmarcar e marcar de novo,
  /// que chega para quem lidera como uma ausência nova.
  group('Motivo por dia', () {
    testWidgets('o cartão abre a caixa já preenchida e manda a correção',
        (tester) async {
      final repositorio = await _montarTela(tester, reason: 'Viagem');

      await tester.tap(find.text('Viagem'));
      await tester.pumpAndSettle();

      expect(find.text('Motivo desse dia'), findsOneWidget);
      // Já preenchida: corrigir "viagem" não pode começar por redigitá-la.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Viagem',
      );

      await tester.enterText(find.byType(TextField), 'Casamento');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(repositorio.corrigido?.id, 'u1');
      expect(repositorio.corrigido?.reason, 'Casamento');
      expect(find.text('Casamento'), findsWidgets);
    });

    testWidgets('desistir deixa o motivo como estava', (tester) async {
      final repositorio = await _montarTela(tester, reason: 'Viagem');

      await tester.tap(find.text('Viagem'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Outra coisa');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // "Cancelar" não é "sem motivo": nada foi para o servidor.
      expect(repositorio.corrigido, isNull);
      expect(find.text('Viagem'), findsOneWidget);
    });

    testWidgets('campo vazio apaga o motivo sem desmarcar o dia',
        (tester) async {
      final repositorio = await _montarTela(tester, reason: 'Viagem');

      await tester.tap(find.text('Viagem'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(repositorio.corrigido?.reason, '');
      // O dia continua na lista: apagar o motivo não é voltar a ficar
      // disponível.
      expect(repositorio.items, hasLength(1));
      expect(find.text('Toque para dizer o motivo'), findsOneWidget);
    });

    testWidgets('dia sem motivo convida em vez de ficar mudo', (tester) async {
      await _montarTela(tester);

      // É a única coisa na linha dizendo que o cartão abre alguma coisa.
      expect(find.text('Toque para dizer o motivo'), findsOneWidget);

      await tester.tap(find.text('Toque para dizer o motivo'));
      await tester.pumpAndSettle();

      expect(find.text('Motivo desse dia'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '',
      );
    });
  });
}
