import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/health_repository.dart';

/// Diagnóstico de conectividade. Acessível mesmo deslogado, porque é
/// justamente quando a API está fora que ele é útil.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthCheckProvider);
    final status = AppStatusColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico')),
      body: SafeArea(
        top: false,
        child: AppContentWidth(
          child: RefreshIndicator(
            onRefresh: () async => ref.refresh(healthCheckProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                const SizedBox(height: AppSpacing.xl),
                health.when(
                  // O mesmo indicador do resto do app, e não mais um
                  // `CircularProgressIndicator` montado à mão: eram três
                  // desenhos diferentes de "espere" em três telas.
                  loading: () => const AppLoading(),
                  error: (error, _) => _StatusCard(
                    icon: Icons.cloud_off_rounded,
                    palette: status.danger,
                    title: 'API indisponível',
                    lines: [
                      '$error',
                      'URL: ${AppConfig.apiBaseUrl}',
                      '',
                      'Emulador Android usa 10.0.2.2; celular físico usa o IP '
                          'da máquina na rede local.',
                    ],
                  ),
                  // Verde, e não o azul da marca: aqui a pergunta é literalmente
                  // "está funcionando?", e essa é a única tela do app onde um
                  // estado positivo é a informação principal.
                  data: (data) => _StatusCard(
                    icon: Icons.check_circle_rounded,
                    palette: status.success,
                    title: 'API ok',
                    lines: [
                      'Versão: ${data.version}',
                      'Ambiente: ${data.environment}',
                      'Banco: ${data.database}',
                      'URL: ${AppConfig.apiBaseUrl}',
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: TextButton.icon(
                    onPressed: () => ref.invalidate(healthCheckProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Testar novamente'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.palette,
    required this.title,
    required this.lines,
  });

  final IconData icon;
  final StatusPalette palette;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.container,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(icon, size: 22, color: palette.onContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(title, style: theme.textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: SelectableText(
                line,
                // Endereço e mensagem de erro existem para serem copiados e
                // mandados a quem cuida do servidor. Antes eram texto morto.
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
