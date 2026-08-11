import 'package:flutter/material.dart';

import '../../core/theme/app_status_colors.dart';
import 'app_badge.dart';

/// Etiqueta de "avisou que não pode neste dia".
///
/// Vive em `shared/` porque aparece nos dois lados da mesma informação: para
/// quem monta a escala (ao escolher) e para quem lê a escala pronta.
///
/// Desenha-se com o [AppBadge] no tom `danger`: era a mesma pílula montada à
/// mão, com padding e raio próprios, e por isso ficava um fio mais baixa que a
/// etiqueta de papel logo ao lado na mesma linha.
class UnavailableBadge extends StatelessWidget {
  const UnavailableBadge({super.key, this.reason, this.compact = true});

  final String? reason;

  /// Versão só com a palavra, para linhas apertadas.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final showReason = !compact && (reason?.isNotEmpty ?? false);
    final hasReason = reason?.isNotEmpty ?? false;

    return AppBadge(
      icon: Icons.event_busy_rounded,
      tone: AppTone.danger,
      label: showReason ? 'Indisponível · $reason' : 'Indisponível',
      // Na versão compacta o motivo some da tela por falta de espaço, mas não
      // precisa sumir para quem ouve: ali cabe a frase inteira.
      semanticsLabel: hasReason
          ? 'Avisou que não pode neste dia: $reason'
          : 'Avisou que não pode neste dia',
    );
  }
}

/// Junta nomes como se fala: "João", "João e Maria", "João, Maria e Pedro".
String joinNames(Iterable<String> names) {
  final list = names.toList();
  if (list.isEmpty) return '';
  if (list.length == 1) return list.first;
  return '${list.sublist(0, list.length - 1).join(', ')} e ${list.last}';
}
