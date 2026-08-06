import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/core/theme/app_theme.dart';
import 'package:louvor_app/shared/widgets/app_avatar.dart';

void main() {
  testWidgets('mostra a inicial do nome', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: AppAvatar(name: 'Samuel Silva')),
      ),
    );

    expect(find.text('S'), findsOneWidget);
  });
}
