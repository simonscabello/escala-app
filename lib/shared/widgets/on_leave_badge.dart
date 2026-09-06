import 'package:flutter/material.dart';

import '../../core/theme/app_status_colors.dart';
import 'app_badge.dart';

/// Etiqueta de "a liderança marcou esta pessoa como afastada".
///
/// Vive em `shared/` pelo mesmo motivo do [UnavailableBadge]: aparece na lista
/// da equipe, na ficha e no seletor da escalação, e três montagens da mesma
/// informação já custaram caro neste app.
///
/// **Âmbar, e não vermelho.** Vermelho neste app é o que impede — a regra de
/// escalação que bloqueia, o erro que derruba o formulário. O afastamento não
/// impede nada: quem lidera continua podendo escalar a pessoa (às vezes ela
/// mesma se ofereceu para um domingo no meio da licença), e a etiqueta está
/// ali para que ninguém a escale sem perceber.
///
/// **"Em afastamento", e não "Afastado".** O app agora sabe o gênero de quem
/// preencheu — e continua não sabendo o de quem não preencheu. Um rótulo que
/// concorda no masculino erra o nome de metade da equipe toda vez que aparece;
/// a forma com substantivo não erra com ninguém.
class OnLeaveBadge extends StatelessWidget {
  const OnLeaveBadge({super.key, this.until, this.reason, this.compact = true});

  /// Previsão de retorno, já formatada ("12 de março"). Nulo = sem data.
  final String? until;
  final String? reason;

  /// Versão só com a palavra, para linhas apertadas.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final detalhe = [
      if (until != null) 'até $until',
      if (reason != null && reason!.isNotEmpty) reason,
    ].join(' · ');

    return AppBadge(
      icon: Icons.pause_circle_outline_rounded,
      tone: AppTone.warning,
      label: !compact && detalhe.isNotEmpty
          ? 'Em afastamento · $detalhe'
          : 'Em afastamento',
      // Na versão compacta o detalhe some da tela por falta de espaço, mas não
      // precisa sumir para quem ouve.
      semanticsLabel: detalhe.isEmpty
          ? 'Em afastamento da equipe'
          : 'Em afastamento da equipe, $detalhe',
    );
  }
}
