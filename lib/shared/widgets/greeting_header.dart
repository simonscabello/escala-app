import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Saudação por horário. Detalhe pequeno, mas é o que separa uma tela de
/// listagem de um app que parece ter sido feito para aquela pessoa.
String greetingForHour(int hour) {
  if (hour < 12) return 'Bom dia';
  if (hour < 18) return 'Boa tarde';
  return 'Boa noite';
}

/// Quem está usando e de que equipe.
///
/// Duas linhas, e não três: "Bom dia," e "Samuel" ocupavam uma linha cada por
/// pura estética, empurrando para baixo a única coisa que a pessoa abriu o app
/// para ver. O cumprimento continua ali, no lugar que ele merece — o de uma
/// linha só.
///
/// **A saudação subiu de corpo e o cabeçalho ganhou folga.** Ele é a abertura
/// da tela principal do app, e estava com o mesmo tamanho de um título de
/// bloco; a diferença entre "esta é a sua agenda" e "esta é mais uma lista"
/// está quase toda aqui.
///
/// No monitor o cabeçalho recebe a ação principal à direita, e o seletor de
/// equipe sai daqui: ele passou para a barra lateral, onde vale para o app
/// inteiro em vez de só para esta tela.
///
/// **Compartilhado entre a Home e a Agenda.** As duas abrem do mesmo jeito, e
/// era um `_GreetingHeader` privado da agenda até a Home precisar do mesmo
/// cabeçalho. Duas cópias divergiriam no primeiro ajuste de folga — e o que
/// mais denuncia duas telas "de apps diferentes" é justamente a abertura.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    super.key,
    required this.name,
    required this.teamName,
    required this.activeTeamId,
    required this.teams,
    required this.onTeamChanged,
    required this.showTeamSwitcher,
    this.onCreate,
  });

  final String name;
  final String teamName;
  final String activeTeamId;
  final List<({String id, String name})> teams;
  final ValueChanged<String> onTeamChanged;
  final bool showTeamSwitcher;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final greeting = greetingForHour(DateTime.now().hour);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? greeting : '$greeting, $name',
                  style: theme.textTheme.headlineMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(Icons.groups_rounded, size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        teamName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (showTeamSwitcher && teams.length > 1)
                      PopupMenuButton<String>(
                        tooltip: 'Trocar equipe',
                        initialValue: activeTeamId,
                        onSelected: onTeamChanged,
                        icon: const Icon(Icons.unfold_more_rounded, size: 18),
                        itemBuilder: (context) => [
                          for (final team in teams)
                            PopupMenuItem(
                              value: team.id,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    child: team.id == activeTeamId
                                        ? Icon(
                                            Icons.check_rounded,
                                            size: 18,
                                            color: scheme.primary,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Flexible(child: Text(team.name)),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (onCreate != null) ...[
            const SizedBox(width: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nova escala'),
            ),
          ],
        ],
      ),
    );
  }
}
