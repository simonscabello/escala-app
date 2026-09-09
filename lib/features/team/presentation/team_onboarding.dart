import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/app_breakpoints.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/greeting_header.dart';
import '../../auth/application/auth_controller.dart';

/// A tela de quem ainda não faz parte de equipe nenhuma.
///
/// **Era privada da agenda até a Home existir.** As duas são portas de entrada
/// — a Home passou a ser a primeira —, e as duas caem aqui quando não há equipe
/// para mostrar. Uma cópia em cada uma daria dois textos de boas-vindas
/// diferentes para a mesma situação.
///
/// Nenhuma decisão nova mora aqui: é o mesmo conteúdo que a agenda mostrava,
/// com as mesmas duas saídas.
class TeamOnboarding extends ConsumerWidget {
  const TeamOnboarding({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AppContentWidth.reading(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(authControllerProvider.notifier).reloadTeams(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              children: [
                Text(
                  '${greetingForHour(DateTime.now().hour)}, '
                  '${user?.firstName ?? ''}',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Você ainda não faz parte de uma equipe. Escolha por onde '
                  'começar.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                // Lado a lado onde cabe: são duas escolhas do mesmo peso, e
                // empilhadas num monitor a segunda cai abaixo da dobra.
                _OnboardingChoices(
                  cards: [
                    _OnboardingCard(
                      icon: Icons.groups_rounded,
                      title: 'Sou o líder da equipe',
                      message: 'Crie a equipe e cadastre os integrantes. '
                          'Ninguém precisa ter conta ainda.',
                      actionLabel: 'Criar equipe',
                      filled: true,
                      onAction: () => context.push('/equipe/nova'),
                    ),
                    _OnboardingCard(
                      icon: Icons.link_rounded,
                      title: 'Recebi um convite',
                      message: 'Cole o código que o líder da equipe enviou.',
                      actionLabel: 'Entrar com código',
                      filled: false,
                      onAction: () => context.push('/convite'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empilhadas no celular, lado a lado onde couber.
class _OnboardingChoices extends StatelessWidget {
  const _OnboardingChoices({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.tablet) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.lg),
                cards[i],
              ],
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.lg),
                Expanded(child: cards[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.filled,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final bool filled;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color:
                  filled ? scheme.primaryContainer : scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Icon(
              icon,
              color: filled
                  ? scheme.onPrimaryContainer
                  : scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (filled)
            FilledButton(onPressed: onAction, child: Text(actionLabel))
          else
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
