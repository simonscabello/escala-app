import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';

/// Home da Etapa 2: onboarding para quem ainda não tem equipe, e atalho para a
/// equipe de quem ja tem. A agenda de cultos entra aqui na Etapa 4.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escalas de Louvor'),
        actions: [
          IconButton(
            tooltip: 'Diagnostico',
            icon: const Icon(Icons.wifi_tethering),
            onPressed: () => context.push('/diagnostico'),
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(authControllerProvider.notifier).reloadTeams(),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Olá, ${user?.firstName ?? ''}',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            if (auth.teams.isEmpty)
              const _Onboarding()
            else
              ...auth.teams.map((team) => _TeamCard(team: team)),
          ],
        ),
      ),
    );
  }
}

class _Onboarding extends StatelessWidget {
  const _Onboarding();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.groups_outlined, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  'Sou o líder da equipe',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Crie a equipe e cadastre os integrantes. Ninguém precisa ter '
                  'conta ainda.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.push('/equipe/nova'),
                  child: const Text('Criar equipe'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.link, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('Recebi um convite', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Cole o código que o líder da equipe enviou para você.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => context.push('/convite'),
                  child: const Text('Entrar com código'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team});

  final TeamSummary team;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const Icon(Icons.groups),
        title: Text(team.name),
        subtitle: Text('${team.displayName} - ${_roleLabel(team.role)}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/equipe'),
      ),
    );
  }

  static String _roleLabel(String role) => switch (role) {
        'OWNER' => 'Dono',
        'LEADER' => 'Líder',
        _ => 'Membro',
      };
}
