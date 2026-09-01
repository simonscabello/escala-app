import 'package:flutter/material.dart';

/// Código que o backend devolve quando a escala mudou desde que esta tela a
/// abriu (409).
const scheduleChangedCode = 'SCHEDULE_CHANGED';

/// Dois líderes montando a mesma escala ao mesmo tempo.
///
/// Antes, quem salvasse por último apagava o trabalho do outro **em silêncio**.
/// Agora o servidor recusa a gravação e a decisão volta para quem está na
/// tela, que é onde ela pertence: às vezes o outro só corrigiu o horário do
/// ensaio, às vezes ele refez a equipe inteira — e o app não tem como saber a
/// diferença.
///
/// Devolve `true` quando a pessoa escolhe sobrescrever assim mesmo.
Future<bool> showScheduleChangedDialog(
  BuildContext context,
  String message,
) async {
  final overwrite = await showDialog<bool>(
    context: context,
    // Sem toque fora para fechar: as duas saídas mudam o que acontece com o
    // que está na tela, e fechar por engano deixaria a pessoa sem saber se
    // salvou.
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('A escala mudou'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Salvar assim mesmo'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Ver como está agora'),
        ),
      ],
    ),
  );
  return overwrite ?? false;
}
