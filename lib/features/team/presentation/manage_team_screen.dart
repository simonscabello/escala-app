import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_group.dart';
import '../data/team_repository.dart';

/// Tudo o que só o dono e os líderes fazem, num lugar só.
///
/// Antes eram dois ícones na barra da tela de Equipe — um de corrente e um de
/// igreja. Ninguém adivinha que "corrente" é convite, e a barra ia crescer a
/// cada configuração nova. Aqui cada item tem nome e uma linha dizendo o que
/// faz, e acrescentar o próximo não custa mais espaço.
///
/// **O repertório saiu daqui.** Ele estava nesta lista, e esta lista só se
/// alcança pelo ícone de engrenagem, que só aparece para quem lidera — ou seja:
/// o integrante que precisa da cifra e do tom antes do ensaio **não tinha como
/// abrir o repertório**, embora o servidor sempre tenha deixado ele ler. Agora
/// o repertório é uma entrada da aba Equipe, para todo mundo, e aqui ficam só
/// as quatro coisas que de fato são configuração.
class ManageTeamScreen extends ConsumerWidget {
  const ManageTeamScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(teamProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar equipe')),
      body: SafeArea(
        top: false,
        child: AppContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            children: [
              // O nome da equipe como manchete da tela, não como título de
              // bloco: é o assunto de tudo que vem abaixo.
              Text(
                team.valueOrNull?.name ?? 'Equipe',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Configurações que valem para a equipe inteira.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Quatro linhas de um grupo, e não quatro cartões: é uma lista de
              // configurações, um assunto só.
              AppGroup(
                children: [
                  AppGroupRow(
                    icon: Icons.link_rounded,
                    title: 'Convites',
                    subtitle: 'Códigos para as pessoas entrarem na equipe',
                    onTap: () => context.push('/equipe/convites'),
                  ),
                  AppGroupRow(
                    icon: Icons.church_outlined,
                    title: 'Cultos da igreja',
                    subtitle: 'Os horários que se repetem toda semana',
                    onTap: () => context.push('/equipe/cultos'),
                  ),
                  AppGroupRow(
                    icon: Icons.music_note_outlined,
                    title: 'Funções',
                    subtitle: 'Vocal, instrumentos, multimídia e som',
                    onTap: () => context.push('/equipe/funcoes'),
                  ),
                  AppGroupRow(
                    icon: Icons.tune_rounded,
                    title: 'Dados da equipe',
                    subtitle: 'O nome que aparece para os integrantes',
                    onTap: () => context.push('/equipe/dados'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
