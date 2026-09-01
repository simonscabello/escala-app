import 'dart:math' as math;

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
      label: 'Louve!',
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
        child: AppBrandGlyph(
          size: size,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}

/// O glifo isolado da marca, para superfícies que já usam o azul do Louve!.
///
/// No ícone ele vive dentro do quadrado azul; na abertura nativa e na splash o
/// fundo já é azul, então repetir o quadrado criaria uma moldura sem função.
class AppBrandGlyph extends StatelessWidget {
  const AppBrandGlyph({
    super.key,
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _LouveGlyph(color)),
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
        Text('Louve!', style: theme.textTheme.titleMedium),
      ],
    );
  }
}

/// O "!" do nome, com o pingo virado cabeça de nota.
///
/// **É o mesmo desenho do ícone do launcher**, e é por isso que ele é código e
/// não um `Icons.` qualquer: antes a marca de dentro do app era um
/// `graphic_eq_rounded` e a do launcher era uma nota musical — duas marcas
/// diferentes para o mesmo produto, cada uma inventada onde foi precisa.
///
/// As coordenadas são as mesmas dos 108dp da tela do adaptive icon do Android
/// (`tools/generate_brand_assets.py`), reescaladas para o tamanho pedido. Mexer
/// aqui sem mexer lá faz as duas divergirem de novo.
class _LouveGlyph extends CustomPainter {
  const _LouveGlyph(this.color);

  final Color color;

  /// A grade em que o glifo foi desenhado.
  static const double _grade = 108;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _grade;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    // Haste cônica de pontas redondas: é o "!" de uma fonte de texto, e não um
    // retângulo -- é o que faz a peça ler como letra antes de ler como desenho.
    const cx = 54.0,
        topo = 22.0,
        base = 58.0,
        larguraTopo = 16.0,
        larguraBase = 9.5;
    final haste = Path()
      ..moveTo((cx - larguraTopo / 2) * k, topo * k)
      ..lineTo((cx + larguraTopo / 2) * k, topo * k)
      ..lineTo((cx + larguraBase / 2) * k, base * k)
      ..lineTo((cx - larguraBase / 2) * k, base * k)
      ..close()
      ..addOval(
        Rect.fromCircle(
          center: Offset(cx * k, topo * k),
          radius: larguraTopo / 2 * k,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(cx * k, base * k),
          radius: larguraBase / 2 * k,
        ),
      );
    canvas.drawPath(haste, paint);

    // O pingo: elipse inclinada, como a cabeça de nota da partitura. A
    // inclinação é o que separa "música" de "pingo gordo".
    canvas.save();
    canvas.translate(cx * k, 76 * k);
    canvas.rotate(-25 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 32 * k, height: 21 * k),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LouveGlyph oldDelegate) => oldDelegate.color != color;
}
