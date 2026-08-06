import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/core/theme/app_theme.dart';
import 'package:louvor_app/features/team/data/team_repository.dart';
import 'package:louvor_app/features/team/domain/team_models.dart';
import 'package:louvor_app/features/team/presentation/member_form_screen.dart';

void main() {
  testWidgets('grade de funcoes aparece no formulario de membro',
      (tester) async {
    final positions = [
      for (var i = 0; i < 6; i++)
        Position(
          id: 'p$i',
          name: 'Funcao $i',
          category: i == 0 ? 'VOCAL' : 'INSTRUMENT',
          sortOrder: i,
        ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          positionsProvider.overrideWith((ref, teamId) async => positions),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MemberFormScreen(teamId: 't1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Funções'), findsOneWidget);
    expect(find.text('Funcao 0'), findsOneWidget);
    expect(find.text('Funcao 5'), findsOneWidget);
  });
}
