import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/health/data/health_repository.dart';
import 'package:louvor_app/features/health/domain/health_status.dart';
import 'package:louvor_app/features/health/presentation/health_screen.dart';

void main() {
  testWidgets('mostra "API ok" quando o backend responde', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthCheckProvider.overrideWith(
            (ref) async => const HealthStatus(
              status: 'ok',
              version: '0.1.0',
              environment: 'test',
              database: 'up',
            ),
          ),
        ],
        child: const MaterialApp(home: HealthScreen()),
      ),
    );

    // Primeiro frame: ainda carregando.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Resolve o future do provider.
    await tester.pump();

    expect(find.text('API ok'), findsOneWidget);
    expect(find.text('Banco: up'), findsOneWidget);
  });

  testWidgets('mostra o erro quando a API não responde', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthCheckProvider.overrideWith(
            (ref) async => throw Exception('sem conexão'),
          ),
        ],
        child: const MaterialApp(home: HealthScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('API indisponível'), findsOneWidget);
  });
}
