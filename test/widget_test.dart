import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/health/data/health_repository.dart';
import 'package:louvor_app/features/health/domain/health_status.dart';
import 'package:louvor_app/features/health/presentation/health_screen.dart';

void main() {
  Widget tela(Future<HealthStatus> Function() check) {
    return ProviderScope(
      overrides: [
        healthCheckProvider.overrideWith((ref) => check()),
        installedAppVersionProvider.overrideWith((ref) async => '0.15.0 (18)'),
      ],
      child: const MaterialApp(home: HealthScreen()),
    );
  }

  testWidgets('conectado: frase amigável e os números para repassar',
      (tester) async {
    await tester.pumpWidget(
      tela(
        () async => const HealthStatus(
          status: 'ok',
          version: '0.15.0',
          commit: 'a1b2c3d',
          environment: 'production',
          database: 'up',
          responseTime: Duration(milliseconds: 180),
        ),
      ),
    );

    // Primeiro frame: ainda verificando.
    expect(find.text('Verificando a conexão…'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Tudo funcionando'), findsOneWidget);
    expect(find.text('Operando normalmente'), findsOneWidget);
    expect(find.text('0.15.0 · a1b2c3d'), findsOneWidget);
    expect(find.text('Produção'), findsOneWidget);
    expect(find.text('Rápida (180 ms)'), findsOneWidget);
    expect(find.text('0.15.0 (18)'), findsOneWidget);
  });

  testWidgets('banco fora: conexão instável, sem jargão', (tester) async {
    await tester.pumpWidget(
      tela(
        () async => const HealthStatus(
          status: 'degraded',
          version: '0.15.0',
          environment: 'production',
          database: 'down',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conexão instável'), findsOneWidget);
    expect(find.text('Indisponível'), findsOneWidget);
  });

  testWidgets('sem resposta: orienta, e deixa o erro técnico recolhido',
      (tester) async {
    await tester.pumpWidget(tela(() async => throw Exception('sem conexão')));
    await tester.pumpAndSettle();

    expect(find.text('Não conseguimos conectar'), findsOneWidget);
    expect(find.text('Detalhes técnicos'), findsOneWidget);
    expect(find.text('Exception: sem conexão'), findsNothing);

    await tester.tap(find.text('Detalhes técnicos'));
    await tester.pumpAndSettle();
    expect(find.text('Exception: sem conexão'), findsOneWidget);
  });
}
