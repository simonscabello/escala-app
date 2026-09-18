import 'package:louvor_app/shared/widgets/app_facts_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('no celular, os dois cultos aparecem inteiros', (tester) async {
    tester.view.physicalSize = const Size(340, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppFactsStrip(
            facts: [
              AppFact(
                icon: Icons.church_rounded,
                label: 'Cultos',
                value: 'Manhã 08:30\nNoite 19:00',
              ),
              AppFact(label: 'Ensaio', value: '10:30'),
              AppFact(label: 'Sua função', value: 'Guitarra', highlight: true),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Manhã 08:30'), findsOneWidget);
    expect(find.text('Noite 19:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
