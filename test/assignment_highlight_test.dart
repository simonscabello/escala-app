import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';
import 'package:louvor_app/features/events/presentation/event_detail_screen.dart';

void main() {
  test('youAssignmentLabel monta o destaque quando ha funções', () {
    expect(youAssignmentLabel(['Guitarra']), 'VOCÊ: Guitarra');
    expect(
      youAssignmentLabel(['Guitarra', 'Vocalista']),
      'VOCÊ: Guitarra, Vocalista',
    );
  });

  test('youAssignmentLabel e null quando o usuario não está escalado', () {
    expect(youAssignmentLabel(const []), isNull);
  });

  test('positionsForMembership encontra as funções do membership', () {
    final event = Event.fromJson({
      'id': 'e1',
      'teamId': 't1',
      'title': 'Culto',
      'startsAt': '2026-08-09T12:00:00.000Z',
      'rehearsalAt': null,
      'location': null,
      'notes': null,
      'colorPalette': null,
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'assignments': [
        {
          'positionId': 'p1',
          'positionName': 'Guitarra',
          'sortOrder': 1,
          'members': [
            {
              'id': 'a1',
              'membershipId': 'm-me',
              'displayName': 'Samuel',
              'note': null,
              'isRegisteredForPosition': true,
            },
          ],
        },
        {
          'positionId': 'p2',
          'positionName': 'Vocalista',
          'sortOrder': 0,
          'members': [
            {
              'id': 'a2',
              'membershipId': 'm-other',
              'displayName': 'Ana',
              'note': null,
              'isRegisteredForPosition': true,
            },
          ],
        },
      ],
      'songs': [],
    });

    expect(event.positionsForMembership('m-me'), ['Guitarra']);
    expect(event.positionsForMembership('m-missing'), isEmpty);
  });

  testWidgets('banner VOCÊ aparece só quando o usuário está escalado',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: YouAssignmentBanner(positionNames: ['Guitarra']),
        ),
      ),
    );

    // "VOCÊ" so no sobretitulo; o valor traz apenas a funcao. Antes o banner
    // recebia o texto pronto e a palavra aparecia nas duas linhas.
    expect(find.text('VOCÊ'), findsOneWidget);
    expect(find.text('Guitarra'), findsOneWidget);
    expect(find.text('VOCÊ: Guitarra'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox.shrink()),
      ),
    );

    expect(find.textContaining('VOCÊ'), findsNothing);
  });
}
