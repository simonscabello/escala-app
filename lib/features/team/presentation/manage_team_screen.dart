import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../data/team_repository.dart';

/// Tudo o que só o dono e os líderes fazem, num lugar só.
///
/// Antes eram dois ícones na barra da tela de Equipe — um de corrente e um de
/// igreja. Ninguém adivinha que "corrente" é convite, e a barra ia crescer a
/// cada configuração nova. Aqui cada item tem nome e uma linha dizendo o que
/// faz, e acrescentar o próximo não custa mais espaço.
class ManageTeamScreen extends ConsumerWidget {
  const ManageTeamScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final team = ref.watch(teamProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar equipe')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              team.valueOrNull?.name ?? 'Equipe',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Configurações que valem para a equipe inteira.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _ManageTile(
              icon: Icons.link_rounded,
              title: 'Convites',
              subtitle: 'Códigos para as pessoas entrarem na equipe',
              onTap: () => context.push('/equipe/convites'),
            ),
            const SizedBox(height: AppSpacing.md),
            _ManageTile(
              icon: Icons.church_outlined,
              title: 'Cultos da igreja',
              subtitle: 'Os horários que se repetem toda semana',
              onTap: () => context.push('/equipe/cultos'),
            ),
            const SizedBox(height: AppSpacing.md),
            _ManageTile(
              icon: Icons.music_note_outlined,
              title: 'Funções',
              subtitle: 'Vocal, instrumentos, multimídia e som',
              onTap: () => context.push('/equipe/funcoes'),
            ),
            const SizedBox(height: AppSpacing.md),
            _ManageTile(
              icon: Icons.tune_rounded,
              title: 'Dados da equipe',
              subtitle: 'Nome da equipe',
              onTap: () => context.push('/equipe/dados'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageTile extends StatelessWidget {
  const _ManageTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
