import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../data/invite_repository.dart';

/// Gera o convite individual de quem ainda não tem conta e deixa a mensagem
/// pronta na área de transferência.
///
/// O caminho antigo era: cadastrar a pessoa, sair da tela, abrir "Gerenciar
/// equipe", achar "Convites" e só ali tocar em "Convidar". Como o líder
/// cadastra a equipe inteira de uma vez, o convite ficava para depois — e
/// "depois", na prática, é quando a pessoa avisa que não está vendo a escala.
///
/// Reaproveita o convite que já existe para a pessoa: o individual vale por um
/// uso só, e dois códigos vivos para o mesmo cadastro deixariam o líder sem
/// saber qual dos dois ele mandou.
Future<void> copyIndividualInvite(
  BuildContext context,
  WidgetRef ref, {
  required String teamId,
  required String membershipId,
  required String displayName,
}) async {
  try {
    final repository = ref.read(inviteRepositoryProvider);
    final existing = (await repository.list(teamId))
        .where((invite) => invite.forMembershipId == membershipId)
        .firstOrNull;
    final invite =
        existing ?? await repository.create(teamId, membershipId: membershipId);

    await Clipboard.setData(ClipboardData(text: invite.shareMessage));
    ref.invalidate(invitesProvider(teamId));

    if (context.mounted) {
      showAppSnackBar(
        context,
        'Convite de $displayName copiado. É só colar no WhatsApp.',
        tone: AppTone.success,
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      showAppSnackBar(context, e.message, tone: AppTone.danger);
    }
  }
}
