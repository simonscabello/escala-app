import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Row(
            children: [
              AppAvatar(name: user.name, radius: 36),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: theme.textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      user.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('Equipe', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _TeamDetails(teams: auth.teams),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            onTap: () => context.push('/disponibilidade'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(Icons.event_busy_outlined, color: scheme.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Minha disponibilidade',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        'Avise os dias em que você não pode ser escalado',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('Aparência', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const _ThemeModeCard(),
          const SizedBox(height: AppSpacing.xxl),
          // Contornado e em vermelho: como botão tonal claro, "Sair" parecia
          // desabilitado.
          OutlinedButton.icon(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Sair da conta'),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => context.push('/diagnostico'),
            child: const Text('Diagnóstico de conexão'),
          ),
        ],
        ),
      ),
    );
  }
}

/// Escolha do tema.
///
/// "Sistema" e o padrao e vem primeiro: quem ja deixou o Android no escuro nao
/// precisa configurar nada aqui. As outras duas existem para quem quer o app
/// diferente do resto do aparelho.
class _ThemeModeCard extends ConsumerWidget {
  const _ThemeModeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mode = ref.watch(themeModeProvider);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tema', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Vale só neste aparelho.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              segments: [
                for (final option in ThemeMode.values)
                  ButtonSegment(
                    value: option,
                    icon: Icon(_iconFor(option), size: 18),
                    label: Text(themeModeLabel(option)),
                  ),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => ref
                  .read(themeModeProvider.notifier)
                  .select(selection.first),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(ThemeMode mode) => switch (mode) {
        ThemeMode.system => Icons.brightness_auto_rounded,
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
      };
}

class _TeamDetails extends StatelessWidget {
  const _TeamDetails({required this.teams});

  final List<TeamSummary> teams;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (teams.isEmpty) {
      return Text(
        'Sem equipe',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    final team = teams.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(team.name, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          roleLabel(team.role),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

String roleLabel(String role) => switch (role) {
  'OWNER' => 'Dono',
  'LEADER' => 'Lider',
  _ => 'Membro',
};
