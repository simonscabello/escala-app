import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// Superfície tocável que **responde ao dedo**.
///
/// É a única microinteração aplicada de forma ampla no app, e ganha esse lugar
/// por ser resposta, não enfeite: confirma que o toque pegou antes de a próxima
/// tela carregar — o que, na rede da igreja, pode demorar o bastante para a
/// pessoa tocar de novo. O respingo do Material sozinho não resolve isso,
/// porque acontece exatamente embaixo do dedo, onde ninguém o vê.
///
/// **2% e 120ms.** Abaixo disso não se percebe; acima vira brinquedo. Some
/// inteiramente quando o sistema pede menos movimento.
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final inkwell = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: _set,
        borderRadius: widget.borderRadius,
        // **O equivalente do afundar, para quem usa mouse.** O gesto de
        // pressionar não existe no ponteiro: no navegador o cartão ficava
        // indistinguível de um bloco de texto até o clique acontecer. O
        // `InkWell` já entrega o cursor de mão; isto acrescenta a única outra
        // coisa que o hover deve dizer — "isto aqui responde". 4% de tinta:
        // percebe-se ao passar por cima e não muda a cor da superfície.
        hoverColor: scheme.onSurface.withValues(alpha: 0.04),
        child: widget.child,
      ),
    );

    if (widget.onTap == null || MediaQuery.disableAnimationsOf(context)) {
      return inkwell;
    }

    return AnimatedScale(
      scale: _down ? 0.98 : 1,
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      child: inkwell,
    );
  }
}
