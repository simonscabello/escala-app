import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';
import 'package:louvor_app/features/events/presentation/setlist_form_screen.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// A etiqueta "Nova" na tela de montar o repertório.
///
/// Ela é **só leitura aqui**: a marca pertence à música no repertório, e é lá
/// que se liga e se desliga. Uma escala não pode discordar das outras sobre se a
/// equipe está aprendendo uma canção — é o mesmo fato em todas.
void main() {
  setUpAll(() async {
    tzdata.initializeTimeZones();
    await initializeDateFormatting('pt_BR');
  });

  Widget repertorio() {
    final event = Event.fromJson({
      'id': 'e1',
      'teamId': 't1',
      'startsAt': '2026-08-16T12:00:00.000Z',
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'services': [
        {'id': 'sv1', 'label': 'Culto', 'startsAt': '2026-08-16T12:00:00.000Z'},
      ],
      'assignments': [],
      'songs': [
        // Em aprendizado: a marca vem da música, e o servidor a repassa.
        {
          'songId': 's1',
          'serviceId': 'sv1',
          'title': 'Bondade de Deus',
          'artist': 'Isaias Saad',
          'key': 'G',
          'isNew': true,
        },
        {
          'songId': 's2',
          'serviceId': 'sv1',
          'title': 'Aclame ao Senhor',
          'artist': 'Diante do Trono',
          'key': 'A',
          'isNew': false,
        },
      ],
    });

    return ProviderScope(
      child: MaterialApp(
        home: SetlistFormScreen(teamId: 't1', eventId: 'e1', event: event),
      ),
    );
  }

  testWidgets('a etiqueta aparece só na música marcada', (tester) async {
    await tester.pumpWidget(repertorio());

    // Quem monta precisa ver quanta novidade está pedindo para um domingo só.
    expect(find.text('Nova'), findsOneWidget);
  });

  testWidgets('não há como marcar nem desmarcar pela escala', (tester) async {
    await tester.pumpWidget(repertorio());

    // Tocar na etiqueta não faz nada: ela não é um controle. Marcar por escala
    // deixava a mesma música ser novidade num domingo e não no outro.
    await tester.tap(find.text('Nova'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Nova'), findsOneWidget);

    // E o diálogo da linha cuida de tom e recado, e só disso. O toque é do
    // card inteiro; o título é só onde a gente mira.
    await tester.tap(find.text('Aclame ao Senhor'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Tom neste culto'), findsOneWidget);
    expect(find.text('Recado'), findsOneWidget);
    expect(find.textContaining('Música nova'), findsNothing);
  });
}
