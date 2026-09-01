import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_status_colors.dart';
import 'app_feedback.dart';

/// Compartilhar um texto, com a área de transferência como saída garantida.
///
/// **O compartilhamento nativo não existe em todo navegador.** No Android é a
/// folha do sistema, e é por ali que a escala chega ao grupo do WhatsApp — o
/// caminho que o produto assume. Na Web, `navigator.share` existe no Chrome e
/// no Edge, e **não** existe no Firefox nem em boa parte dos navegadores de
/// desktop; ali o `share_plus` lança. Sem tratamento, o botão "Compartilhar"
/// simplesmente não fazia nada e o erro morria no console.
///
/// Quando não há como compartilhar, o texto vai para a área de transferência e
/// a barra avisa: a pessoa cola no WhatsApp Web, que é o mesmo destino. Nenhuma
/// funcionalidade nova — a mesma, por outro caminho.
Future<void> shareText(
  BuildContext context,
  String text, {
  String copiedMessage = 'Escala copiada. É só colar onde quiser.',
}) async {
  try {
    await SharePlus.instance.share(ShareParams(text: text));
    return;
  } catch (_) {
    // Cai para a área de transferência abaixo.
  }

  if (!context.mounted) return;

  try {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      showAppSnackBar(context, copiedMessage, tone: AppTone.success);
    }
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        'Não foi possível compartilhar por aqui.',
        tone: AppTone.danger,
      );
    }
  }
}
