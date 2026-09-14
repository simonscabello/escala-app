import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_group.dart';
import '../data/health_repository.dart';
import '../domain/connection_target.dart';
import '../domain/health_status.dart';

/// Diagnóstico de conexão. Acessível mesmo deslogado, porque é justamente
/// quando a API está fora que ele é útil.
///
/// **Para quem usa, e não para quem desenvolve.** Quem abre esta tela é a
/// pessoa da equipe que não consegue entrar no domingo de manhã: ela precisa
/// de uma frase que diga o que está acontecendo e o que fazer, e de números
/// que possa repassar a quem cuida do sistema. O endereço de produção não
/// aparece (ver [describeServer]); o do servidor local, sim.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthCheckProvider);
    final appVersion = ref.watch(installedAppVersionProvider).valueOrNull;
    final server = describeServer(AppConfig.apiBaseUrl);

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico de conexão')),
      body: SafeArea(
        top: false,
        child: AppContentWidth(
          child: RefreshIndicator(
            onRefresh: () async => ref.refresh(healthCheckProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                ...health.when(
                  loading: () => [const _CheckingCard()],
                  error: (error, _) => [
                    const _SummaryCard(
                      tone: AppTone.danger,
                      icon: Icons.cloud_off_rounded,
                      title: 'Não conseguimos conectar',
                      message: 'Confira sua conexão com a internet e tente '
                          'novamente. Se o problema continuar, avise a '
                          'liderança da sua equipe.',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _DetailsGroup(server: server, appVersion: appVersion),
                    const SizedBox(height: AppSpacing.lg),
                    _TechnicalDetails(
                      message: redactServerAddress(
                        '$error',
                        AppConfig.apiBaseUrl,
                      ),
                      showEmulatorHint: server.isLocal,
                    ),
                  ],
                  data: (status) => [
                    status.isHealthy
                        // Verde, e não o azul da marca: aqui a pergunta é
                        // literalmente "está funcionando?", e esta é a única
                        // tela do app onde um estado positivo é a informação
                        // principal.
                        ? const _SummaryCard(
                            tone: AppTone.success,
                            icon: Icons.check_circle_rounded,
                            title: 'Tudo funcionando',
                            message: 'O app está conectado ao servidor e pronto '
                                'para uso.',
                          )
                        : const _SummaryCard(
                            tone: AppTone.warning,
                            icon: Icons.warning_amber_rounded,
                            title: 'Conexão instável',
                            message: 'O servidor respondeu, mas parte do '
                                'sistema está indisponível agora. Tente de '
                                'novo em alguns minutos.',
                          ),
                    const SizedBox(height: AppSpacing.xl),
                    _DetailsGroup(
                      server: server,
                      appVersion: appVersion,
                      status: status,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: health.isLoading
                        ? null
                        : () => ref.invalidate(healthCheckProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Testar novamente'),
                  ),
                ),
                if (health.valueOrNull?.checkedAt case final quando?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: Text(
                      'Última verificação às '
                      '${DateFormat('HH:mm').format(quando)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckingCard extends StatelessWidget {
  const _CheckingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              'Verificando a conexão…',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// A resposta em uma frase: o que está acontecendo e o que fazer.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.tone,
    required this.icon,
    required this.title,
    required this.message,
  });

  final AppTone tone;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        AppStatusColors.of(context).resolve(tone, theme.colorScheme);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.container,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, size: 24, color: palette.onContainer),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(message, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Os números para repassar a quem cuida do sistema, um por linha.
class _DetailsGroup extends StatelessWidget {
  const _DetailsGroup({
    required this.server,
    required this.appVersion,
    this.status,
  });

  final ServerTarget server;
  final String? appVersion;
  final HealthStatus? status;

  @override
  Widget build(BuildContext context) {
    final status = this.status;

    return AppGroup(
      title: 'Detalhes',
      children: [
        _row(
          context,
          icon: server.isSecure ? Icons.lock_outline_rounded : Icons.dns_outlined,
          label: server.label,
          value: server.detail,
        ),
        if (status != null) ...[
          _row(
            context,
            icon: Icons.storage_rounded,
            label: 'Banco de dados',
            value: status.databaseUp ? 'Operando normalmente' : 'Indisponível',
          ),
          if (status.responseTime case final tempo?)
            _row(
              context,
              icon: Icons.speed_rounded,
              label: 'Tempo de resposta',
              value: responseTimeLabel(tempo),
            ),
          _row(
            context,
            icon: Icons.cloud_outlined,
            label: 'Versão do servidor',
            value: status.versionLabel,
          ),
          _row(
            context,
            icon: Icons.public_rounded,
            label: 'Ambiente',
            value: environmentLabel(status.environment),
          ),
        ],
        if (appVersion != null)
          _row(
            context,
            icon: Icons.phone_android_rounded,
            label: 'Versão do app',
            value: appVersion,
          ),
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? value,
  }) {
    return AppGroupRow(
      icon: icon,
      title: label,
      showChevron: false,
      trailing: value == null
          ? null
          : Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
    );
  }
}

/// A mensagem crua fica recolhida: ajuda quem cuida do sistema, e na frente
/// só assustaria quem usa. O endereço de produção já saiu dela.
class _TechnicalDetails extends StatelessWidget {
  const _TechnicalDetails({
    required this.message,
    required this.showEmulatorHint,
  });

  final String message;
  final bool showEmulatorHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      // Material próprio e transparente: o `ExpansionTile` desenha o toque no
      // Material mais próximo, e o fundo do cartão escondia esse retorno.
      child: Material(
        type: MaterialType.transparency,
        child: Theme(
          // Sem os fios que o `ExpansionTile` desenha por padrão: dentro do
          // cartão eles viravam duas linhas soltas.
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text('Detalhes técnicos', style: theme.textTheme.titleSmall),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(message, style: theme.textTheme.bodyMedium),
              if (showEmulatorHint) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Servidor local: o emulador Android usa 10.0.2.2, e o '
                  'celular físico usa o IP da máquina na rede.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
