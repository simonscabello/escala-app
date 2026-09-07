import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// A marca do app.
///
/// Existe como componente porque estava desenhada à mão em três lugares — na
/// abertura com 80px e raio de cartão, no cabeçalho dos formulários com 56px, e
/// cada uma com o seu tom. Marca desenhada de novo a cada tela é a definição de
/// não ter marca.
///
/// **É o único lugar do app com gradiente**, e por isso ele pode existir: um
/// degradê curto entre dois violetas vizinhos, que dá volume à peça sem virar
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
      label: 'Pauta',
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
          // Qual das duas artes cabe aqui é uma pergunta sobre o ladrilho, não
          // sobre o tema: no claro o quadrado é índigo e pede o símbolo branco;
          // no escuro o `primary` é um violeta claro, e ali a arte branca
          // sumiria. Medir a luminância do que está atrás resolve os dois casos
          // sem o widget precisar saber qual tema está ativo.
          onDark: ThemeData.estimateBrightnessForColor(scheme.primary) ==
              Brightness.dark,
        ),
      ),
    );
  }
}

/// O símbolo oficial da marca, isolado.
///
/// No ícone ele vive dentro do quadrado violeta; na abertura nativa e na splash
/// o fundo já é violeta, então repetir o quadrado criaria uma moldura sem
/// função.
///
/// **É um arquivo, não um desenho em código.** Até o rebranding esta classe
/// pintava o glifo num `CustomPainter`, com as coordenadas duplicadas no
/// gerador dos ícones — duas fontes para a mesma forma, que era o problema que
/// o `CustomPainter` tinha vindo resolver. Com a marca entregue pelo design, a
/// única cópia fiel é o próprio arquivo: qualquer redesenho em Dart seria uma
/// terceira versão do P, parecida e diferente.
///
/// A identidade entrega **duas artes** do mesmo símbolo, e nenhuma serve nos
/// dois fundos: a colorida vai de índigo a azul-marinho e sobre o violeta
/// profundo da marca entrega 1,19:1 — some. Por isso [onDark] escolhe o arquivo
/// em vez de tingir um só: um `ColorFilter` sobre a arte colorida jogaria fora
/// o degradê que ela tem.
class AppBrandGlyph extends StatelessWidget {
  const AppBrandGlyph({
    super.key,
    required this.size,
    required this.onDark,
  });

  final double size;

  /// `true` quando o símbolo fica sobre violeta ou sobre qualquer fundo escuro
  /// — é quando entra a arte branca.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      onDark
          ? 'assets/branding/pauta_symbol_on_dark.png'
          : 'assets/branding/pauta_symbol_on_light.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // A marca é decorativa em todo lugar onde aparece: quem a envolve
      // (`AppBrandMark`, a splash) já diz "Pauta" ao leitor de tela, e repetir
      // aqui faria o leitor anunciar a marca duas vezes seguidas.
      excludeFromSemantics: true,
    );
  }
}

/// Marca com o nome ao lado, para cabeçalhos de formulário e para a barra
/// lateral.
///
/// O nome é **texto**, e não o `pauta_logo.png`: o logotipo horizontal tem a
/// palavra em azul-marinho fixo, que no tema escuro ficaria quase invisível
/// sobre a página. Composto assim, o símbolo vem do arquivo oficial e a palavra
/// segue o tema.
class AppBrandLockup extends StatelessWidget {
  const AppBrandLockup({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppBrandMark(size: 40),
        const SizedBox(width: AppSpacing.md),
        Text('PAUTA', style: AppTypography.wordmark(context, size: 17)),
      ],
    );
  }
}
