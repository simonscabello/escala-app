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

  testWidgets('com foto, a inicial continua como reserva do carregamento',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: AppAvatar(
            name: 'Samuel Silva',
            imageUrl: '/uploads/avatars/inexistente.png',
          ),
        ),
      ),
    );

    // O teste nao faz rede (o HttpClient do flutter_test devolve 400), e e
    // justamente esse o caso que precisa continuar legivel: foto que nao
    // carrega nao pode deixar um circulo vazio na lista.
    await tester.pump();
    expect(find.text('S'), findsOneWidget);
  });
}
