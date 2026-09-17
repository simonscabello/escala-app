import 'package:flutter/material.dart';

import 'app_options_sheet.dart';

/// Uma equipe como o seletor a mostra.
typedef TeamChoice = ({String id, String name});

/// Trocar a equipe ativa — **o** seletor, para o app inteiro.
///
/// Havia três: um menu com marca desenhada à mão no cabeçalho da Home, um
/// `CheckedPopupMenuItem` no da Agenda, e nenhum no Perfil, que ainda mostrava
/// a primeira equipe da lista em vez da ativa. Agora as três portas abrem a
/// mesma folha ([showAppOptionsSheet]). A barra lateral do monitor mantém o
/// dela, que vive dentro da própria barra.
///
/// Devolve o id escolhido, ou nulo quando a pessoa fecha sem trocar.
Future<String?> showTeamPicker(
  BuildContext context, {
  required List<TeamChoice> teams,
  required String activeTeamId,
}) async {
  final choice = await showAppOptionsSheet<String>(
    context: context,
    title: 'Trocar equipe',
    subtitle: 'O app passa a mostrar a agenda e o repertório da equipe '
        'escolhida.',
    selected: activeTeamId,
    options: [
      for (final team in teams)
        AppOption(
          value: team.id,
          label: team.name,
          icon: Icons.groups_outlined,
        ),
    ],
  );
  if (choice == null || choice.value == activeTeamId) return null;
  return choice.value;
}
