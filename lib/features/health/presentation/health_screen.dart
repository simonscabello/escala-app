import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/health_repository.dart';

/// Diagnostico de conectividade. Acessivel mesmo deslogado, porque e
/// justamente quando a API esta fora que ela e util.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthCheckProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostico')),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(healthCheckProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            health.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _Card(
                icon: Icons.cloud_off,
                color: Theme.of(context).colorScheme.error,
                title: 'API indisponível',
                lines: [
                  '$error',
                  'URL: ${AppConfig.apiBaseUrl}',
                  '',
                  'Emulador Android usa 10.0.2.2; celular fisico usa o IP '
                      'da maquina na rede local.',
                ],
              ),
              data: (data) => _Card(
                icon: Icons.check_circle_rounded,
                color: Theme.of(context).colorScheme.primary,
                title: 'API ok',
                lines: [
                  'Versao: ${data.version}',
                  'Ambiente: ${data.environment}',
                  'Banco: ${data.database}',
                  'URL: ${AppConfig.apiBaseUrl}',
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                onPressed: () => ref.invalidate(healthCheckProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Testar novamente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.color,
    required this.title,
    required this.lines,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line, style: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
