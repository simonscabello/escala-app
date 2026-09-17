import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'team_picker.dart';

/// Saudação por horário. Detalhe pequeno, mas é o que separa uma tela de
/// listagem de um app que parece ter sido feito para aquela pessoa.
///
/// Da meia-noite às 5h é madrugada: "Bom dia" à 00h09 soava como relógio
/// quebrado.
String greetingForHour(int hour) {
  if (hour < 5) return 'Boa madrugada';
  if (hour < 12) return 'Bom dia';
  if (hour < 18) return 'Boa tarde';
  return 'Boa noite';
}

/// O cabeçalho das abas: título grande e, embaixo, a equipe ativa.
///
/// **A Home e a Agenda abrem do mesmo jeito.** A Home tinha a saudação em
/// corpo grande com a equipe em violeta e um seletor desenhado à mão; a Agenda
/// tinha "Agenda" um tamanho abaixo, a equipe em cinza, outro componente de
/// seletor e margem de 16 em vez de 24. Trocar de aba parecia trocar de app.
/// Agora muda só o [title] — a saudação numa, "Agenda" na outra.
///
/// O seletor de equipe ([showTeamPicker]) só aparece com mais de uma equipe, e
/// não aparece com a barra lateral aberta, que tem o dela.
///
/// [trailing] é a ação do cabeçalho no monitor ("Nova escala"); no celular ela
/// é o botão flutuante.
class TabHeader extends StatelessWidget {
  const TabHeader({
    super.key,
    required this.title,
    this.teamName,
    this.activeTeamId,
    this.teams = const [],
    this.onTeamChanged,
    this.showTeamSwitcher = false,
    this.trailing = const [],
  });

  final String title;

  /// A linha da equipe embaixo do título. Nula no Perfil, que é da pessoa e
  /// não da equipe — ali a equipe é uma linha própria, com o seletor.
  final String? teamName;
  final String? activeTeamId;
  final List<TeamChoice> teams;
  final ValueChanged<String>? onTeamChanged;
  final bool showTeamSwitcher;
  final List<Widget> trailing;

  Future<void> _switchTeam(BuildContext context) async {
    final id = await showTeamPicker(
      context,
      teams: teams,
      activeTeamId: activeTeamId ?? '',
    );
    if (id != null) onTeamChanged?.call(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canSwitch =
        showTeamSwitcher && onTeamChanged != null && teams.length > 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.xl,
        AppSpacing.screenPadding,
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
                  title,
                  style: theme.textTheme.headlineMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (teamName != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  InkWell(
                    onTap: canSwitch ? () => _switchTeam(context) : null,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: canSwitch ? AppSpacing.touchTarget : 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.groups_rounded,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              teamName!,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (canSwitch) ...[
                            const SizedBox(width: 2),
                            Icon(
                              Icons.unfold_more_rounded,
                              size: 18,
                              color: scheme.primary,
                              semanticLabel: 'Trocar equipe',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final action in trailing) ...[
            const SizedBox(width: AppSpacing.sm),
            action,
          ],
        ],
      ),
    );
  }
}
