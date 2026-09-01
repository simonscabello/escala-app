import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_breakpoints.dart';

/// A mesma escolha, apresentada onde a mão (ou o mouse) a espera.
///
/// No celular a folha sobe de baixo: é onde o polegar está, e o gesto de
/// arrastar para fechar já é conhecido. No monitor a mesma folha subindo do
/// rodapé de uma janela de 1080px é um objeto perdido no canto inferior, longe
/// do cursor e longe do que a pessoa estava lendo — ali o lugar certo é o
/// centro, como diálogo.
///
/// **O conteúdo é o mesmo nos dois casos.** Este helper existe justamente para
/// que nenhuma tela precise escrever a escolha duas vezes: quem chama entrega
/// um `builder` e recebe o resultado, sem saber em que moldura ele apareceu.
///
/// O `maxHeight` de 85% vale para os dois formatos: é o que impede o diálogo
/// de ficar maior que a janela num monitor baixo (a armadilha clássica de
/// modal em Web) e o que já limitava a folha no celular.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 560,
  bool useRootNavigator = false,
}) {
  if (!AppBreakpoints.of(context).isWide) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: useRootNavigator,
      builder: builder,
    );
  }

  return showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (dialogContext) => Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      // Folga generosa nas bordas: sem ela o diálogo encosta na janela quando
      // alguém reduz o navegador enquanto ele está aberto.
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.85,
        ),
        child: Padding(
          // A folha ganha o espaço do puxador; o diálogo não tem puxador, e
          // sem isto o título nasce colado no topo.
          padding: const EdgeInsets.only(top: AppSpacing.xl),
          child: builder(dialogContext),
        ),
      ),
    ),
  );
}
