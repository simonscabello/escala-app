import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// A marca do app.
///
/// Existe como componente porque estava desenhada à mão em três lugares — na
/// abertura com 80px e raio de cartão, no cabeçalho dos formulários com 56px, e
/// cada uma com o seu tom de azul. Marca desenhada de novo a cada tela é a
/// definição de não ter marca.
///
/// **É o único lugar do app com gradiente**, e por isso ele pode existir: um
/// degradê curto entre dois azuis vizinhos, que dá volume à peça sem virar
/// efeito. Espalhado por botões e cabeçalhos, seria exatamente o excesso que o
/// resto da interface evita; concentrado num quadrado de 60px que aparece duas
/// vezes na vida do usuário, é o que faz a marca parecer feita e não escolhida
/// de um catálogo de ícones.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Escalas de Louvor',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary,
              // O segundo tom nasce do primeiro, não de outra cor: no claro
              // escurece, no escuro clareia — o degradê sempre corre para
              // dentro do tema, nunca contra ele.
              Color.lerp(
                scheme.primary,
                scheme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                0.22,
              )!,
            ],
          ),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(
          Icons.graphic_eq_rounded,
          size: size * 0.5,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}

/// Marca com o nome ao lado, para cabeçalhos de formulário.
class AppBrandLockup extends StatelessWidget {
  const AppBrandLockup({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppBrandMark(size: 40),
        const SizedBox(width: AppSpacing.md),
        Text(
          'Escalas de Louvor',
          style: theme.textTheme.titleMedium,
        ),
      ],
    );
  }
}
